"""04-client: HUD layout options A/B/C as block mockups + numbers (docs/qa/UI_LAYOUT_REFERENCE.md).

A = current src/ui/hud_layout.gd (before), B = chosen (worker apart, threat markers in the top half, strips between
markers, fit order that keeps the skills in the bottom row longer), C = skills moved to the top left under the
resources (frees the bottom row). Pure Python, no Godot.
Usage: python tools/build/layout_options.py [--out docs/qa/layout_ref]
Lengths: 393 dp phone in landscape, view 800x360 (07 ART_BASELINE fixed set), 1 view px = 62.4 mm / 360 = 0.1734 mm.
"""
import json, os, sys
from PIL import Image, ImageDraw

MM_PER_PX = 62.4 / 360.0          # 393 dp = 62.4 mm screen height on the 07 phone
GAP, GROUP_GAP = 4.0, 12.0
TOUCH_GAP = 8.0                    # B/C: 8 dp between touch targets (07 LAYOUT L4, QA-B027); A keeps 4
GROUND_FROM_BOTTOM = 70.0
LANE_ABOVE_GROUND = 56.0           # boss 45 px + HP bar + margin (07: soldiers 20-29 px, boss 45 px)


class R:
    def __init__(s, x, y, w, h): s.x, s.y, s.w, s.h = float(x), float(y), float(w), float(h)
    ex = property(lambda s: s.x + s.w)
    ey = property(lambda s: s.y + s.h)
    cx = property(lambda s: s.x + s.w / 2)
    cy = property(lambda s: s.y + s.h / 2)
    def hit(s, o): return s.x < o.ex and o.x < s.ex and s.y < o.ey and o.y < s.ey
    def inter(s, o):
        w = min(s.ex, o.ex) - max(s.x, o.x); h = min(s.ey, o.ey) - max(s.y, o.y)
        return max(0.0, w) * max(0.0, h)
    def d(s): return [round(s.x, 1), round(s.y, 1), round(s.w, 1), round(s.h, 1)]


def top_row(view, s, t):
    out = {}
    out["pause"] = R(s.ex - t, s.y, t, t)
    res_w = min(max(s.w * 0.26, 132.0), 180.0)
    out["resources"] = R(s.x, s.y, res_w, t)
    bx = s.x + res_w + GAP * 2
    be = out["pause"].x - GAP * 2
    out["bases"] = R(bx, s.y, max(be - bx, 60.0), 22.0)
    out["wave"] = R(bx, s.y + 24.0, out["bases"].w, 14.0)
    out["boss"] = R(bx, s.y + t + 4, out["bases"].w, 14.0)
    return out


def option_a(view, safe, nc, ns, t):
    """Current hud_layout.gd (A)."""
    t = max(t, 40.0); s = R(safe.x + 4, safe.y + 4, safe.w - 8, safe.h - 8)
    o = top_row(view, s, t)
    move = max(t, 52.0); card_h = max(t + 8.0, 56.0); rb = s.ey
    o["move_left"] = R(s.x, rb - move, move, move)
    o["move_right"] = R(s.x + move + GAP * 2, rb - move, move, move)
    left_end = o["move_right"].ex + GAP * 3
    skill = max(t, 48.0); n = nc + 1; cw = max(t, 50.0); in_row = True
    rs = s.ex - (ns * skill + max(ns - 1, 0) * GAP) - (GAP * 3 if ns else 0)
    avail = rs - left_end; need = n * cw + (n - 1) * GAP
    if need > avail:
        cw = max(t, (avail - (n - 1) * GAP) / n); need = n * cw + (n - 1) * GAP
    if need > avail and ns:
        in_row = False; rs = s.ex; avail = rs - left_end
        cw = min(max((avail - (n - 1) * GAP) / n, t), max(t, 50.0)); need = n * cw + (n - 1) * GAP
    x0 = left_end + max(0.0, (avail - need) / 2)
    cards = [R(x0 + i * (cw + GAP), rb - card_h, cw, card_h) for i in range(n)]
    o["worker"], o["cards"] = cards[0], cards[1:]
    o["skills"] = _skills(s, ns, skill, rb, card_h, in_row)
    se = s.ex if in_row or not ns else o["skills"][0].x - GAP * 2
    o["tutorial"] = R(s.x, s.y + t + 24, se - s.x, 20); o["toast"] = R(s.x, s.y + t + 46, se - s.x, 20)
    o["banner"] = R(s.x, max(view[1] * 0.36, s.y + t + 70), se - s.x, 32)
    ty = round(view[1] - GROUND_FROM_BOTTOM - 34 - 34)
    o["threat_right"] = R(se - 44, ty, 44, 34); o["threat_left"] = R(s.x, ty, 44, 34)
    o["skills_in_row"] = in_row
    return o


def _skills(s, ns, skill, rb, card_h, in_row, gap=GAP):
    out = []
    for i in range(ns):
        if in_row:
            out.append(R(s.ex - (ns - i) * skill - (ns - 1 - i) * gap, rb - skill, skill, skill))
        else:
            out.append(R(s.ex - skill, rb - card_h - GAP * 2 - (i + 1) * skill - i * gap, skill, skill))
    return out


def option_bc(view, safe, nc, ns, t, pack_right=False):
    """B (pack_right False) and C (True): worker is its own group; threat markers t x t in the top half."""
    t = max(t, 40.0); s = R(safe.x + 4, safe.y + 4, safe.w - 8, safe.h - 8)
    o = top_row(view, s, t)
    move = max(t, 52.0); card_h = max(t + 8.0, 56.0); rb = s.ey
    skill = max(t, 48.0); in_row = True
    CARD_NAME_W = 42.0                 # 36 px ko card name + 6 px padding

    def skills_w(skill, n, gg):
        return (n * skill + (n - 1) * TOUCH_GAP + gg) if n > 0 else 0.0

    def card_fit(move, skill, n, gg):
        fixed = (2 * move + GAP * 2) + gg * 2 + skills_w(skill, n, gg) + max(nc - 1, 0) * TOUCH_GAP
        return (s.w - fixed) / (nc + 1)
    # fit order (= hud_layout.gd): skill buttons, then the held move buttons shrink before a card gets narrower
    # than its name, then cards shrink to t, then group gaps 12 -> 8, then the skills stack
    gg = GROUP_GAP
    cw = card_fit(move, skill, ns, gg)
    if cw < max(t, CARD_NAME_W):
        skill = t; cw = card_fit(move, skill, ns, gg)
    if cw < max(t, CARD_NAME_W):
        move = t; cw = card_fit(move, skill, ns, gg)
    if cw < t:
        gg = TOUCH_GAP; cw = card_fit(move, skill, ns, gg)
    if cw < t and ns:
        in_row = False; gg = GROUP_GAP; cw = card_fit(move, skill, 0, gg)
    cw = min(max(cw, t), max(t, 50.0))
    sk = skills_w(skill, ns, gg) if in_row else 0.0
    o["move_left"] = R(s.x, rb - move, move, move)
    o["move_right"] = R(s.x + move + GAP * 2, rb - move, move, move)
    o["worker"] = R(o["move_right"].ex + gg, rb - card_h, cw, card_h)
    lo = o["worker"].ex + gg; hi = s.ex - sk
    need = nc * cw + (nc - 1) * TOUCH_GAP
    x0 = (hi - need) if pack_right else lo + max(0.0, (hi - lo - need) / 2)
    o["cards"] = [R(x0 + i * (cw + TOUCH_GAP), rb - card_h, cw, card_h) for i in range(nc)]
    o["skills"] = _skills(s, ns, skill, rb, card_h, in_row, TOUCH_GAP)
    o["skills_in_row"] = in_row
    # threat markers (01 R10): >= 44 px (48 dp on the 393 dp phone), right/left edge, below the toast strip, top half
    mk = max(t, 44.0)
    toast_end = s.y + t + 46 + 20
    my = min(toast_end + GAP, view[1] / 2 - mk)
    rx = s.ex - mk
    if not in_row and ns:
        rx = min(rx, o["skills"][0].x - GAP * 2 - mk)
    o["threat_right"] = R(rx, my, mk, mk); o["threat_left"] = R(s.x, my, mk, mk)
    se = s.ex if in_row or not ns else o["skills"][0].x - GAP * 2
    o["tutorial"] = R(s.x, s.y + t + 24, se - s.x, 20); o["toast"] = R(s.x, s.y + t + 46, se - s.x, 20)
    # banner: same height rule as A, but between the two markers so it never covers them
    bx = o["threat_left"].ex + GAP * 2; be = o["threat_right"].x - GAP * 2
    o["banner"] = R(bx, max(view[1] * 0.36, s.y + t + 70), be - bx, 32)
    return o


def option_c(view, safe, nc, ns, t):
    """C: skills in a row under the resources at the top left (Cat War2, Stick War: Legacy, Age of War 2 put their
    specials there); the bottom row keeps move | worker | cards. Threat markers as in B."""
    o = option_bc(view, safe, nc, 0, t)
    t = max(t, 40.0); s = R(safe.x + 4, safe.y + 4, safe.w - 8, safe.h - 8)
    skill = max(t, 48.0); y = s.y + t + GAP * 2
    o["skills"] = [R(s.x + i * (skill + TOUCH_GAP), y, skill, skill) for i in range(ns)]
    sx = (o["skills"][-1].ex if ns else s.x) + GAP * 2
    o["tutorial"] = R(sx, s.y + t + 24, s.ex - sx, 20); o["toast"] = R(sx, s.y + t + 46, s.ex - sx, 20)
    return o


def metrics(o, view, safe, t):
    W, H = view
    targets = [o["pause"], o["move_left"], o["move_right"], o["worker"]] + o["cards"] + o["skills"]
    frequent = [o["move_left"], o["move_right"], o["worker"]] + o["cards"] + o["skills"]
    hud_static = [o["resources"], o["bases"], o["wave"]] + targets
    ground = H - GROUND_FROM_BOTTOM
    lane = R(0, ground - LANE_ABOVE_GROUND, W, LANE_ABOVE_GROUND + 2)
    top_bottom = max(r.ey for r in [o["resources"], o["bases"], o["wave"], o["pause"]])
    row_top = min(r.y for r in frequent if r.cy > H / 2)
    gaps = []
    for i, a in enumerate(targets):
        for b in targets[i + 1:]:
            if abs(a.cy - b.cy) < (a.h + b.h) / 2:      # same row: horizontal gap
                gaps.append(max(b.x - a.ex, a.x - b.ex))
    worker_gap = min(o["worker"].x - o["move_right"].ex, (o["cards"][0].x - o["worker"].ex) if o["cards"] else 99)
    card_reach = max(min(c.cx, W - c.cx) for c in o["cards"]) * MM_PER_PX if o["cards"] else 0
    tr = o["threat_right"]
    covers_marker = [k for k in ["bases", "wave", "boss", "pause", "tutorial", "toast", "banner"] if o[k].hit(tr)] + \
                    ["target" for r in targets if r.hit(tr)]
    return {
        "battlefield_band_pct": round(100 * (row_top - top_bottom) / H, 1),
        "hud_static_px_pct_upper_bound": round(100 * sum(r.w * r.h for r in hud_static) / (W * H), 1),
        "lane_px_covered_by_targets": round(sum(r.inter(lane) for r in targets)),
        "lane_px_covered_by_marker": round(o["threat_right"].inter(lane) + o["threat_left"].inter(lane)),
        "min_target_px": round(min(min(r.w, r.h) for r in targets), 1),
        "min_target_mm": round(min(min(r.w, r.h) for r in targets) * MM_PER_PX, 2),
        "card_w_px": round(o["cards"][0].w, 1) if o["cards"] else None,
        "min_gap_px": round(min(gaps), 1) if gaps else None,
        "worker_gap_px": round(worker_gap, 1),
        "frequent_in_bottom_quarter": all(r.cy >= 0.75 * H for r in frequent),
        "pause_in_corner": o["pause"].ex >= W - 60 and o["pause"].y <= 10,
        "card_max_reach_mm": round(card_reach, 1),
        "threat_marker_px": [tr.w, tr.h],
        "threat_in_top_half": tr.ey <= H / 2,
        "threat_covered_by": covers_marker,
        "skills_in_row": o["skills_in_row"],
    }


COL = {"resources": (232, 196, 90), "bases": (200, 80, 70), "wave": (150, 110, 90), "boss": (120, 60, 120),
       "pause": (90, 90, 110), "move": (80, 140, 200), "worker": (230, 170, 40), "card": (160, 110, 70),
       "skill": (70, 90, 170), "threat": (230, 60, 60), "strip": (60, 60, 60), "banner": (90, 70, 40)}


def draw(o, view, safe, path, title):
    W, H = int(view[0]), int(view[1]); k = 2
    im = Image.new("RGB", (W * k, H * k + 24), (24, 24, 30)); d = ImageDraw.Draw(im)
    sky = (110, 150, 200); dirt = (159, 109, 66)
    ground = H - GROUND_FROM_BOTTOM
    d.rectangle([0, 24, W * k, 24 + ground * k], fill=sky)
    d.rectangle([0, 24 + ground * k, W * k, 24 + H * k], fill=dirt)
    d.rectangle([0, 24 + (ground - LANE_ABOVE_GROUND) * k, W * k, 24 + (ground + 2) * k], outline=(255, 255, 255))
    for x in range(int(safe.x), int(safe.ex)):
        pass
    if safe.x > 0: d.rectangle([0, 24, safe.x * k, 24 + H * k], fill=(0, 0, 0))
    if safe.ex < W: d.rectangle([safe.ex * k, 24, W * k, 24 + H * k], fill=(0, 0, 0))

    def box(r, c, label=""):
        d.rectangle([r.x * k, 24 + r.y * k, r.ex * k - 1, 24 + r.ey * k - 1], fill=c, outline=(7, 7, 12))
        if label: d.text((r.x * k + 3, 24 + r.y * k + 2), label, fill=(0, 0, 0))
    for key in ["tutorial", "toast"]:
        r = o[key]; d.rectangle([r.x * k, 24 + r.y * k, r.ex * k - 1, 24 + r.ey * k - 1], outline=COL["strip"])
        d.text((r.x * k + 3, 24 + r.y * k + 2), key, fill=(40, 40, 40))
    r = o["banner"]; d.rectangle([r.x * k, 24 + r.y * k, r.ex * k - 1, 24 + r.ey * k - 1], outline=COL["banner"])
    d.text((r.x * k + 3, 24 + r.y * k + 2), "banner", fill=(60, 40, 20))
    box(o["resources"], COL["resources"], "flour/energy"); box(o["bases"], COL["bases"], "base HP  VS  base HP")
    box(o["wave"], COL["wave"], "wave"); box(o["pause"], COL["pause"], "II")
    d.rectangle([o["boss"].x * k, 24 + o["boss"].y * k, o["boss"].ex * k, 24 + o["boss"].ey * k], outline=COL["boss"])
    box(o["move_left"], COL["move"], "<"); box(o["move_right"], COL["move"], ">")
    box(o["worker"], COL["worker"], "worker")
    for i, c in enumerate(o["cards"]): box(c, COL["card"], "card%d" % (i + 1))
    for i, c in enumerate(o["skills"]): box(c, COL["skill"], "sk%d" % (i + 1))
    box(o["threat_right"], COL["threat"], "threat"); box(o["threat_left"], COL["threat"], "threat")
    d.text((4, 4), title, fill=(255, 255, 255))
    im.save(path)


def main():
    out = "docs/qa/layout_ref"
    if "--out" in sys.argv: out = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    cases = {"800x360_notch34_t44": ((800, 360), R(34, 0, 732, 360), 44.0),
             "640x360_notch34_t48": ((640, 360), R(34, 0, 572, 360), 48.0)}
    opts = {"A": lambda v, s, t: option_a(v, s, 5, 3, t), "B": lambda v, s, t: option_bc(v, s, 5, 3, t),
            "C": lambda v, s, t: option_c(v, s, 5, 3, t)}
    res = {}
    for cname, (v, safe, t) in cases.items():
        for oname, f in opts.items():
            o = f(v, safe, t)
            res["%s_%s" % (oname, cname)] = {"metrics": metrics(o, v, safe, t),
                "rects": {k: ([r.d() for r in val] if isinstance(val, list) else val.d()) for k, val in o.items() if k != "skills_in_row"}}
            draw(o, v, safe, os.path.join(out, "option_%s_%s.png" % (oname, cname)), "%s  %s  (5 cards, 3 skills)" % (oname, cname))
    # same view / inset / target matrix as tests/ui/test_ui.gd test_layout_matrix, 5 cards + 3 skills
    views = [(640, 360), (720, 360), (780, 360), (800, 360), (840, 360), (640, 400), (640, 480), (800, 450), (666, 400), (683, 384)]
    insets = [(0, 0, 0, 0), (34, 0, 0, 0), (34, 0, 34, 0), (0, 0, 0, 12), (34, 0, 34, 12)]
    summary = {}
    for oname, f in opts.items():
        n = stacked = lane = marker_low = small = narrow_card = 0; stacked_cases = []
        for v in views:
            for ins in insets:
                for t in [40.0, 44.0, 48.0]:
                    safe = R(ins[0], ins[1], v[0] - ins[0] - ins[2], v[1] - ins[1] - ins[3])
                    o = f(v, safe, t); m = metrics(o, v, safe, t); n += 1
                    if not m["skills_in_row"] and oname != "C":
                        stacked += 1; stacked_cases.append("%dx%d %s t%d" % (v[0], v[1], ins, t))
                    lane += 1 if m["lane_px_covered_by_targets"] + m["lane_px_covered_by_marker"] > 0 else 0
                    marker_low += 0 if m["threat_in_top_half"] else 1
                    small += 1 if m["min_target_px"] + 0.01 < t else 0
                    narrow_card += 1 if m["card_w_px"] is not None and m["card_w_px"] + 0.01 < 42.0 else 0
        summary[oname] = {"configs": n, "skills_stacked": stacked, "lane_covered": lane, "marker_not_top_half": marker_low,
                          "targets_below_t": small, "cards_below_name_width_42": narrow_card, "stacked_cases": stacked_cases}
    res["matrix_summary"] = summary
    json.dump(res, open(os.path.join(out, "options.json"), "w"), indent=1)
    for k, r in res.items():
        if k == "matrix_summary":
            for on, sm in r.items():
                print("MATRIX", on, {a: b for a, b in sm.items() if a != "stacked_cases"}, sm["stacked_cases"][:6])
        else:
            print(k, json.dumps(r["metrics"], ensure_ascii=False))


if __name__ == "__main__":
    main()
