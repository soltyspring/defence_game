"""Static text-width review for 12-text-review (no Godot, no rendering).

Reads the shipped fonts with fontTools (advance widths + the GPOS 'kern' pair table that
HarfBuzz/Godot applies), ports the 04 layout maths from src/ui/*.gd, and checks every
player-visible key of data/text/{ko,en}.json against the slot it is drawn in.

Run from the repository root:
    python docs/review/text/measure_text.py            # writes docs/review/text/evidence/*.json
    python docs/review/text/measure_text.py --calib    # calibration table only

This is a calculation, not a rendered frame. Calibration against Godot-measured widths
(build/qa/typography_report.json, written by tests/ui/test_ui.gd) is printed first.
"""
import json
import math
import os
import re
import sys

from fontTools.ttLib import TTFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "docs", "review", "text", "evidence")


def P(*parts):
    return os.path.join(ROOT, *parts)


# ----------------------------------------------------------------------------- fonts

class Font:
    def __init__(self, path, fallback=None):
        f = TTFont(path)
        self.path = path
        self.upem = f["head"].unitsPerEm
        self.cmap = f.getBestCmap()
        hm = f["hmtx"]
        self.adv = {g: hm[g][0] for g in f.getGlyphOrder()}
        self.kern = {}
        self.fallback = fallback
        if "GPOS" in f:
            self._read_gpos(f["GPOS"].table)

    def _read_gpos(self, gpos):
        for lk in gpos.LookupList.Lookup:
            subs = []
            for st in lk.SubTable:
                if lk.LookupType == 9:          # extension
                    if st.ExtensionLookupType != 2:
                        continue
                    st = st.ExtSubTable
                elif lk.LookupType != 2:
                    continue
                subs.append(st)
            for st in subs:
                cov = st.Coverage.glyphs
                if st.Format == 1:
                    for i, g1 in enumerate(cov):
                        for rec in st.PairSet[i].PairValueRecord:
                            v = getattr(rec.Value1, "XAdvance", 0) if rec.Value1 else 0
                            if v:
                                self.kern.setdefault((g1, rec.SecondGlyph), v)
                elif st.Format == 2:
                    c1 = st.ClassDef1.classDefs
                    c2 = st.ClassDef2.classDefs
                    seconds = {}
                    for g, c in c2.items():
                        seconds.setdefault(c, []).append(g)
                    for g1 in cov:
                        r1 = st.Class1Record[c1.get(g1, 0)]
                        for ci, r2 in enumerate(r1.Class2Record):
                            v = getattr(r2.Value1, "XAdvance", 0) if r2.Value1 else 0
                            if v and ci in seconds:
                                for g2 in seconds[ci]:
                                    self.kern.setdefault((g1, g2), v)

    def has(self, ch):
        return ord(ch) in self.cmap

    def glyph_runs(self, text):
        """[(font, glyph)] with per-character fallback (Godot FontFile.fallbacks)."""
        out = []
        for ch in text:
            f = self
            while f is not None and not f.has(ch):
                f = f.fallback
            if f is None:
                out.append((self, ".notdef"))
            else:
                out.append((f, f.cmap[ord(ch)]))
        return out

    def width(self, text, size, kerning=True):
        runs = self.glyph_runs(text)
        w = 0.0
        for i, (f, g) in enumerate(runs):
            w += round_half_away(f.adv.get(g, 0) * size / f.upem)   # subpixel positioning disabled
            if kerning and i + 1 < len(runs) and runs[i + 1][0] is f:
                k = f.kern.get((g, runs[i + 1][1]), 0)
                if k:
                    w += round_half_away(k * size / f.upem)
        return w

    def missing(self, text):
        return sorted({ch for ch in text if ord(ch) > 32 and not self.has(ch)})


def round_half_away(x):
    return math.floor(x + 0.5) if x >= 0 else -math.floor(-x + 0.5)


G11 = Font(P("assets", "fonts", "Galmuri11.ttf"))
G11B = Font(P("assets", "fonts", "Galmuri11-Bold.ttf"))
G9 = Font(P("assets", "fonts", "Galmuri9.ttf"), fallback=G11)   # ui_style.gd: num.fallbacks = [ui]
KIND = {"ui": G11, "bold": G11B, "num": G9}


def tw(text, size, kind="ui"):
    return KIND[kind].width(text, size)


# ----------------------------------------------------------------------------- UiStyle ports (src/ui/ui_style.gd)

def is_ascii(text):
    return all(ord(c) < 128 for c in text)


def fit_text(text, max_w, size, kind="ui"):
    if tw(text, size, kind) <= max_w:
        return text
    lo, hi, best = 1, len(text) - 1, 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if tw(text[:mid] + "…", size, kind) <= max_w:
            best, lo = mid, mid + 1
        else:
            hi = mid - 1
    return text[:best] + "…"


def fit_label(text, max_w, size, kind="ui"):
    """-> (drawn, size, kind). ASCII-only text at 12 px may step down to Galmuri9 10 px."""
    if tw(text, size, kind) <= max_w:
        return text, size, kind
    if size == 12 and is_ascii(text) and tw(text, 10, "num") <= max_w:
        return text, 10, "num"
    return fit_text(text, max_w, size, kind), size, kind


def wrap_text(text, max_w, size, kind="ui"):
    out, line = [], ""
    for word in text.split(" "):
        cand = word if line == "" else line + " " + word
        if tw(cand, size, kind) <= max_w:
            line = cand
            continue
        if line != "":
            out.append(line)
        line = ""
        w = word
        while tw(w, size, kind) > max_w and len(w) > 1:
            n = len(w)
            while n > 1 and tw(w[:n], size, kind) > max_w:
                n -= 1
            out.append(w[:n])
            w = w[n:]
        line = w
    if line != "":
        out.append(line)
    return out


def fit_lines(text, max_w, size, max_lines=1, kind="ui"):
    """-> dict(lines, size, kind, truncated) exactly like UiStyle.fit_lines."""
    if tw(text, size, kind) <= max_w or max_lines <= 1:
        d, s, k = fit_label(text, max_w, size, kind)
        return {"lines": [d], "size": s, "kind": k, "truncated": d != text}
    w = wrap_text(text, max_w, size, kind)
    if len(w) <= max_lines:
        return {"lines": w, "size": size, "kind": kind, "truncated": False}
    d, s, k = fit_label(text, max_w, size, kind)
    if d == text:
        return {"lines": [text], "size": s, "kind": k, "truncated": False}
    out = w[:max_lines - 1]
    out.append(fit_text(" ".join(w[max_lines - 1:]), max_w, size, kind))
    return {"lines": out, "size": size, "kind": kind, "truncated": True}


# ----------------------------------------------------------------------------- layout ports (src/ui/hud_layout.gd)

GAP, GROUP_GAP, TOUCH_GAP, THREAT_MIN, CARD_NAME_W = 4.0, 12.0, 8.0, 44.0, 42.0


class R:
    def __init__(self, x, y, w, h):
        self.x, self.y, self.w, self.h = x, y, w, h

    @property
    def end_x(self):
        return self.x + self.w

    @property
    def end_y(self):
        return self.y + self.h

    def grow(self, m):
        return R(self.x - m, self.y - m, self.w + 2 * m, self.h + 2 * m)

    def __repr__(self):
        return "R(%.2f,%.2f,%.2f,%.2f)" % (self.x, self.y, self.w, self.h)


def _top(s, t):
    pause = R(s.end_x - t, s.y, t, t)
    res_w = min(max(s.w * 0.26, 132.0), 180.0)
    resources = R(s.x, s.y, res_w, t)
    bars_x = s.x + res_w + GAP * 2
    bars_end = pause.x - GAP * 2
    bases = R(bars_x, s.y, max(bars_end - bars_x, 60.0), 22.0)
    wave = R(bars_x, s.y + 24.0, bases.w, 14.0)
    return pause, resources, bases, wave


def layout_head(view, safe, n_cards, n_skills, min_target):
    """git HEAD version of HudLayout.compute (before 04's option-B WIP)."""
    t = max(min_target, 40.0)
    s = safe.grow(-4.0)
    pause, resources, bases, wave = _top(s, t)
    move = max(t, 52.0)
    card_h = max(t + 8.0, 56.0)
    left_end = s.x + move + GAP * 2 + move + GAP * 3
    skill = max(t, 48.0)
    n_items = n_cards + 1
    card_w = max(t, 50.0)
    skills_in_row = True
    right_start = s.end_x - (n_skills * skill + max(n_skills - 1, 0) * GAP) - (GAP * 3 if n_skills > 0 else 0.0)
    avail = right_start - left_end
    need = n_items * card_w + (n_items - 1) * GAP
    if need > avail:
        card_w = max(t, (avail - (n_items - 1) * GAP) / max(n_items, 1))
        need = n_items * card_w + (n_items - 1) * GAP
    if need > avail and n_skills > 0:
        skills_in_row = False
        avail = s.end_x - left_end
        card_w = min(max((avail - (n_items - 1) * GAP) / max(n_items, 1), t), max(t, 50.0))
    strip_end = s.end_x
    if not skills_in_row and n_skills > 0:
        strip_end = s.end_x - skill - GAP * 2
    strip_w = strip_end - s.x
    tut = R(s.x, s.y + t + 24, strip_w, 20.0)
    toast = R(s.x, s.y + t + 46, strip_w, 20.0)
    banner = R(s.x, max(view[1] * 0.36, s.y + t + 70), strip_w, 32.0)
    boss = R(bases.x, s.y + t + 4, bases.w, 14.0)
    return dict(t=t, s=s, card_w=card_w, skills_in_row=skills_in_row, pause=pause, resources=resources,
                bases=bases, wave=wave, tutorial=tut, toast=toast, banner=banner, boss=boss, move=move, skill=skill)


def _skills_w(skill, n_skills, gg):
    return 0.0 if n_skills <= 0 else n_skills * skill + (n_skills - 1) * TOUCH_GAP + gg


def _card_fit(width, n_cards, move, skill, n_skills, gg):
    fixed = (2.0 * move + GAP * 2) + gg * 2 + _skills_w(skill, n_skills, gg) + max(n_cards - 1, 0) * TOUCH_GAP
    return (width - fixed) / float(n_cards + 1)


def layout_wip(view, safe, n_cards, n_skills, min_target, shrink_move=True):
    """Workspace (uncommitted 04 option B) HudLayout.compute. shrink_move=False models the first B
    implementation described in docs/qa/UI_LAYOUT_REFERENCE.md §5 ('cards shrank to 41 px first')."""
    t = max(min_target, 40.0)
    s = safe.grow(-4.0)
    pause, resources, bases, wave = _top(s, t)
    move = max(t, 52.0)
    skill = max(t, 48.0)
    skills_in_row = True
    gg = GROUP_GAP
    cw = _card_fit(s.w, n_cards, move, skill, n_skills, gg)
    if cw < max(t, CARD_NAME_W):
        skill = t
        cw = _card_fit(s.w, n_cards, move, skill, n_skills, gg)
    if shrink_move and cw < max(t, CARD_NAME_W):
        move = t
        cw = _card_fit(s.w, n_cards, move, skill, n_skills, gg)
    if cw < t:
        gg = TOUCH_GAP
        cw = _card_fit(s.w, n_cards, move, skill, n_skills, gg)
    if cw < t and n_skills > 0:
        skills_in_row = False
        gg = GROUP_GAP
        cw = _card_fit(s.w, n_cards, move, skill, 0, gg)
    card_w = min(max(cw, t), max(t, 50.0))
    strip_end = s.end_x
    if not skills_in_row and n_skills > 0:
        strip_end = s.end_x - skill - GAP * 2
    strip_w = strip_end - s.x
    tut = R(s.x, s.y + t + 24, strip_w, 20.0)
    toast = R(s.x, s.y + t + 46, strip_w, 20.0)
    mk = max(t, THREAT_MIN)
    ty = min(toast.end_y + GAP, math.floor(view[1] / 2.0) - mk)
    thr_r = R(strip_end - mk, ty, mk, mk)
    thr_l = R(s.x, ty, mk, mk)
    bx = thr_l.end_x + GAP * 2
    bend = thr_r.x - GAP * 2
    banner = R(bx, max(view[1] * 0.36, s.y + t + 70), bend - bx, 32.0)
    boss = R(bases.x, s.y + t + 4, bases.w, 14.0)
    return dict(t=t, s=s, card_w=card_w, skills_in_row=skills_in_row, pause=pause, resources=resources,
                bases=bases, wave=wave, tutorial=tut, toast=toast, banner=banner, boss=boss, move=move, skill=skill,
                threat=thr_r)


def placed(v):
    """ui_screen.gd place(): size.round() (Godot rounds half away from zero)."""
    return round_half_away(v)


# ----------------------------------------------------------------------------- data

def load_json(*parts):
    with open(P(*parts), encoding="utf-8") as fh:
        return json.load(fh)


TEXT = {loc: load_json("data", "text", "%s.json" % loc)["strings"] for loc in ("ko", "en")}
ROUNDS = []
for i in range(1, 11):
    ROUNDS.append(load_json("data", "rounds", "r%02d.json" % i))
META = load_json("data", "meta.json")


def read_fallbacks():
    src = open(P("src", "ui", "ui_text.gd"), encoding="utf-8").read()
    out = {}
    for name in ("FALLBACK_KO", "FALLBACK_EN"):
        m = re.search(name + r" := \{(.*?)\n\}", src, re.S)
        out[name] = dict(re.findall(r'"([^"]+)":\s*"((?:[^"\\]|\\.)*)"', m.group(1)))
    return out


FB = read_fallbacks()


def t(loc, key):
    """UiText.t(): data -> FALLBACK_EN (en only) -> FALLBACK_KO -> key."""
    if key in TEXT[loc]:
        return TEXT[loc][key], "data"
    if loc == "en" and key in FB["FALLBACK_EN"]:
        return FB["FALLBACK_EN"][key], "fallback_en"
    if key in FB["FALLBACK_KO"]:
        return FB["FALLBACK_KO"][key], "fallback_ko"
    return key, "raw_key"


# ----------------------------------------------------------------------------- calibration

def calibration():
    rep_path = P("build", "qa", "typography_report.json")
    rows_out = []
    if os.path.exists(rep_path):
        rep = json.load(open(rep_path, encoding="utf-8"))
        seen = set()
        for loc, d in rep["locales"].items():
            for r in d["rows"]:
                key = (r["text"], r["size"], r["font"])
                if key in seen:
                    continue
                seen.add(key)
                mine = tw(r["text"], r["size"], r["font"])
                nok = KIND[r["font"]].width(r["text"], r["size"], kerning=False)
                rows_out.append({"loc": loc, "key": r["key"], "text": r["text"], "size": r["size"], "font": r["font"],
                                 "godot": r["width"], "ours": mine, "ours_no_kern": nok})
    # In-engine widths reported by 04 (coordination/requests/04-client-to-01-director.md R4 08:40, name probe)
    # and 07 (07-qa-to-04-client.md QA-B009). Galmuri11 12 px = "ui", Galmuri9 10 px = "num".
    extra = [("Footman", 12, "ui", 53, "04 R4"), ("Catapult", 12, "ui", 55, "04 R4"), ("Spear", 12, "ui", 37, "04 R4"),
             ("Siege", 12, "ui", 36, "04 R4"), ("Footman", 10, "num", 42, "04 R4"), ("Catapult", 10, "num", 43, "04 R4"),
             ("Spear", 10, "num", 28, "04 R4"), ("Siege", 10, "num", 25, "04 R4"), ("Soldier", 10, "num", 33, "04 R4"),
             ("Worker", 10, "num", 33, "04 R4"), ("Archer", 10, "num", 34, "04 R4"), ("Shield", 10, "num", 28, "04 R4"),
             ("Raider", 10, "num", 31, "04 R4"), ("Guard", 10, "num", 29, "04 R4"), ("Troop", 12, "ui", 37, "07 QA-B009"),
             ("Archer", 12, "ui", 42, "07 QA-B009"), ("Shield", 12, "ui", 39, "07 QA-B009"), ("Raider", 12, "ui", 41, "07 QA-B009")]
    for txt, sz, kind, godot, src in extra:
        rows_out.append({"loc": "en", "key": "(%s)" % src, "text": txt, "size": sz, "font": kind, "godot": godot,
                         "ours": tw(txt, sz, kind), "ours_no_kern": KIND[kind].width(txt, sz, kerning=False)})
    match = sum(1 for r in rows_out if abs(r["godot"] - r["ours"]) < 0.01)
    match_nk = sum(1 for r in rows_out if abs(r["godot"] - r["ours_no_kern"]) < 0.01)
    # Conflicting datum, not counted: 04 R3 (08:10) wrote "Footman ... 37 px at 10" and 01 R4 repeated it; 04's own
    # R4 table 30 min later gives 42 at 10 px, which is what the font advances give (5+6+6+5+8+6+6).
    conflict = {"text": "Footman", "size": 10, "font": "num", "claimed": 37, "claimed_by": "04 R3 08:10, repeated in 01 R4",
                "ours": tw("Footman", 10, "num"), "other_godot_value": 42}
    return {"source": "build/qa/typography_report.json (Godot 4.7.2, test_ui.gd, 2026-10-31 17:28) + 04 R4 / 07 QA-B009 in-engine values",
            "rows": rows_out, "n": len(rows_out), "match_with_kern": match, "match_without_kern": match_nk, "conflict": conflict}


# ----------------------------------------------------------------------------- 08:01 reproduction

def reproduce_0801():
    view, safe = (640, 360), R(34, 0, 572, 360)
    out = {}
    for name, fn in (("head", lambda: layout_head(view, safe, 5, 3, 40.0)),
                     ("b_first_0801_model", lambda: layout_wip(view, safe, 5, 3, 40.0, shrink_move=False)),
                     ("wip_now", lambda: layout_wip(view, safe, 5, 3, 40.0))):
        l = fn()
        cw = l["card_w"]
        test_max = cw - 6                      # tests/ui/test_ui.gd uses the unrounded rect
        run_max = placed(cw) - 6               # TouchButton: fit_lines(text, size.x - 6) after place() rounding
        names = {}
        for loc in ("ko", "en"):
            for uid in ("worker", "melee_basic", "ranged_basic", "tank", "fast", "siege"):
                txt = t(loc, "unit.%s.name" % uid)[0]
                w = tw(txt, 12)
                names["%s:%s" % (loc, uid)] = {"text": txt, "w": w, "over_test": round(w - test_max, 2),
                                               "over_runtime": w - run_max}
        out[name] = {"card_w": round(cw, 3), "button_w_runtime": placed(cw), "test_max_w": round(test_max, 3),
                     "runtime_max_w": run_max, "move": l["move"], "skill": l["skill"], "names": names}
    return out


# ----------------------------------------------------------------------------- slot checks

VIEWS = [(640, 360), (720, 360), (780, 360), (800, 360), (840, 360), (640, 400), (640, 480), (800, 450), (666, 400), (683, 384)]
INSETS = [(0, 0, 0, 0), (34, 0, 0, 0), (34, 0, 34, 0), (0, 0, 0, 12), (34, 0, 34, 12)]
TARGETS = [40.0, 44.0, 48.0]


def safe_of(view, ins):
    return R(ins[0], ins[1], view[0] - ins[0] - ins[2], view[1] - ins[1] - ins[3])


def wave_line(loc, rd):
    """Longest hud_top wave line for a round: '<n>. <name>   <wave x/y>  <next in N>'."""
    title = "%d. %s" % (rd["index"], t(loc, rd.get("name_key", "round.%s.name" % rd["id"]))[0])
    scripted = [w for w in rd["waves"] if not w.get("pressure")]
    total = len(scripted)
    times = [0.0] + [float(w["at"]) for w in scripted]
    best = ""
    for i in range(total):
        nxt = math.ceil(times[i + 1] - times[i])
        wt = t(loc, "ui.wave")[0].replace("%d", str(i), 1).replace("%d", str(total), 1)
        if nxt > 0:
            wt += "  " + t(loc, "ui.wave_next")[0].replace("%d", str(nxt)).replace("%ds", "%ds")
        line = title + "   " + wt
        if tw(line, 12) > tw(best, 12):
            best = line
    return best


def fmt(s, *vals):
    out = s
    for v in vals:
        out = re.sub(r"%(\d*)[ds]", lambda m: str(v), out, count=1)
    return out.replace("%%", "%")


def upgrade_display(loc, u):
    base = t(loc, u["name_key"])[0]
    tgt = u.get("target", "")
    if tgt.startswith("unit:"):
        return "%s · %s" % (t(loc, "unit.%s.name" % tgt[5:])[0], base)
    if tgt.startswith("hero:"):
        return "%s · %s" % (t(loc, "hero.%s.name" % tgt[5:])[0], base)
    return base


def check_hud(layout_fn, tag):
    """Every round × view × inset × target: card names, worker, dim reason, hints, toasts, banner, wave line, boss."""
    worst = {}
    events = []
    toast_keys = ["toast.not_enough_gold", "toast.army_full", "toast.on_cooldown", "toast.not_enough_mana", "toast.hero_dead",
                  "toast.wave_incoming", "toast.boss_incoming", "toast.worker_max", "toast.counterattack", "toast.round_locked",
                  "toast.save_failed", "toast.save_read_only", "toast.save_recovered"]
    res_hidden = []
    for rd in ROUNDS:
        nc, ns = len(rd["cards"]), len(rd["skills"])
        for view in VIEWS:
            for ins in INSETS:
                for tg in TARGETS:
                    l = layout_fn(view, safe_of(view, ins), nc, ns, tg)
                    cfg = "%s %dx%d ins%s t%d" % (rd["id"], view[0], view[1], "/".join(str(i) for i in ins), tg)
                    card_max = placed(l["card_w"]) - 6
                    for loc in ("ko", "en"):
                        items = [("unit.%s.name" % c, card_max, 12, "ui", "card", 1) for c in rd["cards"]]
                        items.append(("ui.worker", card_max, 12, "ui", "worker_card", 1))
                        items.append(("ui.full", card_max, 12, "ui", "card_dim_reason", 0))
                        for k in rd.get("tutorial", []):
                            items.append((k, l["tutorial"].w - 16, 12, "ui", "tutorial_strip", 0))
                        for k in toast_keys:
                            items.append((k, l["toast"].w - 16, 12, "ui", "toast_strip", 0))
                        items.append(("ui.boss", l["banner"].w - 16, 24, "bold", "banner", 0))
                        items.append(("banner.first_wave_cleared", l["banner"].w - 16, 24, "bold", "banner", 0))
                        for key, mx, sz, kind, where, lines in items:
                            txt, src = t(loc, key)
                            if where == "banner" and key == "ui.boss":
                                pass
                            w = tw(txt, sz, kind)
                            if lines >= 1:
                                fl = fit_lines(txt, mx, sz, lines, kind)
                                state = "truncated" if fl["truncated"] else ("stepped_10px" if fl["size"] != sz else "ok")
                            else:
                                state = "truncated" if w > mx else "ok"
                            wk = (loc, key, where)
                            slack = mx - w
                            if wk not in worst or slack < worst[wk]["slack"]:
                                worst[wk] = {"loc": loc, "key": key, "where": where, "text": txt, "w": w, "max_w": mx,
                                             "slack": slack, "state": state, "cfg": cfg, "size": sz, "font": kind}
                            if state != "ok":
                                events.append((loc, key, where, state, cfg, w, mx))
                        # wave banner "웨이브 x/y" and the wave line in hud_top
                        total = len([w for w in rd["waves"] if not w.get("pressure")])
                        wb = fmt(t(loc, "ui.wave")[0], total, total)
                        wbw = tw(wb, 24, "bold")
                        wk = (loc, "ui.wave", "banner")
                        if wk not in worst or l["banner"].w - 16 - wbw < worst[wk]["slack"]:
                            worst[wk] = {"loc": loc, "key": "ui.wave", "where": "banner", "text": wb, "w": wbw,
                                         "max_w": l["banner"].w - 16, "slack": l["banner"].w - 16 - wbw,
                                         "state": "ok" if wbw <= l["banner"].w - 16 else "truncated", "cfg": cfg, "size": 24, "font": "bold"}
                        line = wave_line(loc, rd)
                        mx = l["wave"].w - 70
                        w = tw(line, 12)
                        wk = (loc, "hud.wave_line:" + rd["id"], "wave_line")
                        st = "ok" if w <= mx else "truncated"
                        if wk not in worst or mx - w < worst[wk]["slack"]:
                            worst[wk] = {"loc": loc, "key": "round title + ui.wave + ui.wave_next (%s)" % rd["id"], "where": "wave_line",
                                         "text": line, "w": w, "max_w": mx, "slack": mx - w, "state": st, "cfg": cfg, "size": 12, "font": "ui",
                                         "drawn": fit_text(line, mx, 12)}
                        if st != "ok":
                            events.append((loc, "wave_line", rd["id"], st, cfg, w, mx))
                        # boss strip name (hud_top._draw_boss): min(text+6, 35 % of the strip)
                        for b in ("boss_warlord", "boss_overlord"):
                            nm = t(loc, "enemy.%s.name" % b)[0]
                            nw = tw(nm, 12)
                            mxb = min(nw + 6, l["boss"].w * 0.35) - 6
                            wk = (loc, "enemy.%s.name" % b, "boss_strip")
                            if wk not in worst or mxb - nw < worst[wk]["slack"]:
                                worst[wk] = {"loc": loc, "key": "enemy.%s.name" % b, "where": "boss_strip", "text": nm, "w": nw,
                                             "max_w": mxb, "slack": mxb - nw, "state": "ok" if nw <= mxb else "truncated",
                                             "cfg": cfg, "size": 12, "font": "ui"}
                        # resources panel (hud_top._draw_resources): name and income visibility
                        r = l["resources"]
                        name_w = max(tw(t(loc, "res.supply")[0], 12), tw(t(loc, "res.energy")[0], 12))
                        gmax = int(rd.get("gold_max", 200))
                        digits = max(3, len(str(gmax)))
                        cell_b = max(G11B.width(str(d), 12) for d in range(10))
                        slot = cell_b * digits
                        cell_u = max(G11.width(str(d), 12) for d in range(10))
                        def numw(s):
                            return sum(cell_u if c.isdigit() else G11.width(c, 12) for c in s)
                        cap_w = numw("/%d" % gmax)
                        income_w = numw("+%.1f/s" % 9.5)
                        avail = r.w - 20 - 6
                        show_name = name_w + 4 + slot + cap_w <= avail
                        show_income = slot + cap_w + 4 + income_w + (name_w + 4 if show_name else 0) <= avail
                        if not (show_name and show_income):
                            res_hidden.append({"loc": loc, "cfg": cfg, "res_w": round(r.w, 2), "show_name": show_name,
                                               "show_income": show_income, "need_all": name_w + 4 + slot + cap_w + 4 + income_w,
                                               "avail": avail})
    return worst, events, res_hidden


def check_screens():
    """Menu, round select, result, pause, settings, upgrades, notice: narrowest realistic safe widths."""
    rows = []
    cases = [((640, 360), (34, 0, 34, 0), 40.0), ((640, 360), (34, 0, 34, 0), 44.0), ((640, 360), (34, 0, 34, 0), 48.0),
             ((640, 360), (0, 0, 0, 0), 40.0), ((800, 360), (34, 0, 0, 0), 48.0)]

    def add(loc, key, where, txt, mx, size=12, kind="ui", lines=1, cfg="", how="fit_lines"):
        w = tw(txt, size, kind)
        if how == "fit_lines":
            fl = fit_lines(txt, mx, size, lines, kind)
            state = "truncated" if fl["truncated"] else ("stepped_10px" if fl["size"] != size else
                                                         ("wrapped_%d" % len(fl["lines"]) if len(fl["lines"]) > 1 else "ok"))
            drawn = " / ".join(fl["lines"])
        elif how == "fit_text":
            d = fit_text(txt, mx, size, kind)
            state = "truncated" if d != txt else "ok"
            drawn = d
        elif how == "wrap":
            wl = wrap_text(txt, mx, size, kind)
            state = "wrapped_%d" % len(wl) if len(wl) > 1 else "ok"
            drawn = " / ".join(wl)
        else:   # drawn without any fitting
            state = "overflow" if w > mx else "ok"
            drawn = txt
        rows.append({"loc": loc, "key": key, "where": where, "text": txt, "w": w, "max_w": mx, "slack": mx - w,
                     "state": state, "drawn": drawn, "size": size, "font": kind, "cfg": cfg})

    for view, ins, tg in cases:
        safe = safe_of(view, ins)
        cfg = "%dx%d ins%s t%d" % (view[0], view[1], "/".join(str(i) for i in ins), tg)
        target = max(tg, 40.0)
        for loc in ("ko", "en"):
            T = lambda k: t(loc, k)[0]
            # --- main menu (main_menu.gd)
            bw = min(max(safe.w * 0.44, 252.0), 300.0)
            add(loc, "ui.play", "menu_play", T("ui.play"), placed(bw) - 6, 24, cfg=cfg)
            add(loc, "ui.continue", "menu_play", T("ui.continue"), placed(bw) - 6, 24, cfg=cfg)
            for ver, w3 in (("wip", math.floor((bw - 16) / 3.0)), ("head", math.floor((bw - 12) / 3.0))):
                for k in ("ui.select_round", "ui.upgrades", "ui.settings"):
                    add(loc, k, "menu_row3_" + ver, T(k), placed(w3) - 6, cfg=cfg)
            add(loc, "ui.subtitle", "menu_subtitle", T("ui.subtitle"), safe.w - 16, how="fit_text", cfg=cfg)
            add(loc, "ui.save_recovered", "menu_notice_line", T("ui.save_recovered"), safe.w, how="none", cfg=cfg)
            add(loc, "ui.quit_confirm", "quit_title", T("ui.quit_confirm"), view[0], 24, how="none", cfg=cfg)
            for k in ("ui.quit", "ui.cancel"):
                add(loc, k, "quit_button", T(k), 120 - 6, cfg=cfg)
            # --- round select (round_select.gd)
            add(loc, "ui.back", "round_back", T("ui.back"), 72 - 6, cfg=cfg)
            add(loc, "ui.upgrades", "round_upgrades_btn", T("ui.upgrades"), 80 - 6, cfg=cfg)
            # title (24 px, centred, not fitted) must stay between the back button and the coin readout
            coins_w = 7 * 7 + 10 + 8     # up to 7 coin digits (cap 9,999,999) + icon + gap
            free_half = min(safe.w / 2 - (4 + 72 + 4), safe.w / 2 - (4 + 80 + 8 + coins_w))
            add(loc, "ui.select_round", "round_title_24", T("ui.select_round"), 2 * free_half, 24, how="none", cfg=cfg)
            side = target + 10
            area_w = safe.w - side * 2
            for ver, gap in (("wip", 8.0), ("head", 6.0)):
                tile = math.floor((area_w - gap * 4) / 5)
                for rd in ROUNDS:
                    add(loc, rd["name_key"], "round_tile_" + ver, T(rd["name_key"]), placed(tile) - 6, lines=2, cfg=cfg)
            # --- result (result.gd)
            w = min(safe.w - 24, 380.0)
            col_w = math.floor((w - 36) / 2.0) - 6
            add(loc, "ui.victory", "result_title_36", T("ui.victory"), w - 16, 36, "bold", how="none", cfg=cfg)
            add(loc, "ui.defeat", "result_title_36", T("ui.defeat"), w - 16, 36, "bold", how="none", cfg=cfg)
            stars = set()
            for rd in ROUNDS:
                stars.add(fmt(T("ui.star_base_hp"), int(round(rd["stars"]["base_hp_2"] * 100))))
                stars.add(fmt(T("ui.star_time"), int(rd["stars"]["time_3"])))
            for s_txt in sorted(stars) + [T("ui.star_win"), T("ui.star_base_hp_any"), T("ui.star_time_any")]:
                add(loc, "ui.star_*", "result_star_row", s_txt, col_w - 22, how="fit_text", cfg=cfg)
            add(loc, "ui.first_clear", "result_first_clear", T("ui.first_clear"), w - 16, how="none", cfg=cfg)
            for n_btn in (4, 3):
                bwr = math.floor((w - 24 - (n_btn - 1) * 8) / n_btn)
                for k in ("ui.menu", "ui.upgrades", "ui.retry", "ui.next"):
                    if n_btn == 3 and k == "ui.next":
                        continue
                    add(loc, k, "result_button_%d" % n_btn, T(k), placed(bwr) - 6, cfg=cfg)
            # D31 loss hint (not drawn yet by 04): candidate slots = inner panel width, 12 px
            for k in ("hint.loss.r05.tactic", "hint.loss.upgrade"):
                add(loc, k, "result_inner_w_wrap", T(k), w - 36, how="wrap", cfg=cfg)
            # --- pause (hud.gd)
            add(loc, "ui.paused", "pause_title_24", T("ui.paused"), view[0], 24, how="none", cfg=cfg)
            for k in ("ui.resume", "ui.retry", "ui.settings", "ui.menu"):
                add(loc, k, "pause_button", T(k), 150 - 6, cfg=cfg)
            # --- settings (settings_panel.gd)
            sw = min(safe.w - 16, 360.0)
            obw = max(target, 64.0)
            label_free = sw - 8 - 2 * (obw + 4) + 4 - 12 - 4
            for k in ("ui.fps_cap", "ui.sfx", "ui.music", "ui.show_damage", "ui.screen_shake"):
                add(loc, k, "settings_label", T(k), label_free, how="none", cfg=cfg)
            for k in ("ui.on", "ui.off"):
                add(loc, k, "settings_option", T(k), placed(obw) - 6, cfg=cfg)
            for k in ("ui.close", "ui.credits", "ui.back"):
                add(loc, k, "settings_button", T(k), 100 - 6, cfg=cfg)
            add(loc, "ui.font_credit", "credits_wrap", T("ui.font_credit"), sw - 24, how="wrap", cfg=cfg)
            # --- upgrade panel (upgrade_panel.gd)
            uw = min(safe.w - 16, 460.0)
            name_w = (uw - 16) - 76 - 8 - 130
            for u in META["upgrades"]:
                add(loc, u["name_key"] + " (" + u["id"] + ")", "upgrade_row_name", upgrade_display(loc, u), name_w, how="fit_text", cfg=cfg)
            for k in ("ui.upgrade_buy", "ui.max"):
                add(loc, k, "upgrade_buy_button", T(k), 76 - 6, cfg=cfg)
            longest = max((upgrade_display(loc, u) for u in META["upgrades"]), key=lambda s: tw(s, 12))
            status = {
                "ui.upgrade_ok": fmt(T("ui.upgrade_ok"), longest, 5),
                "ui.upgrade_not_enough": fmt(T("ui.upgrade_not_enough"), 260),
                "ui.upgrade_max": T("ui.upgrade_max"),
                "ui.upgrade_save_failed": T("ui.upgrade_save_failed"),
                "ui.upgrade_save_uncertain": T("ui.upgrade_save_uncertain"),
                "ui.upgrade_unavailable": T("ui.upgrade_unavailable"),
                "ui.upgrade_locked": T("ui.upgrade_locked"),
                "ui.upgrade_error": fmt(T("ui.upgrade_error"), "invalid_level"),
            }
            for k, s_txt in status.items():
                add(loc, k, "upgrade_status_line", "● " + s_txt, uw - 24, how="fit_text", cfg=cfg)
            # --- notice dialog (notice_dialog.gd)
            nw = min(safe.w - 32.0, 420.0)
            add(loc, "notice.content_migrated", "notice_3_lines", T("notice.content_migrated").replace("{levels}", "12").replace("{coins}", "1234"),
                nw - 24, lines=3, cfg=cfg)
    return rows


# ----------------------------------------------------------------------------- proposals (12 → 01 request)

def min_strip(round_ids, which="tutorial"):
    m = 1e9
    for rd in ROUNDS:
        if rd["id"] not in round_ids:
            continue
        for view in VIEWS:
            for ins in INSETS:
                for tg in TARGETS:
                    l = layout_wip(view, safe_of(view, ins), len(rd["cards"]), len(rd["skills"]), tg)
                    m = min(m, l[which].w - 16)
    return m


def min_card_slot():
    m = 1e9
    for fn in (layout_wip, layout_head):
        for rd in ROUNDS:
            for view in VIEWS:
                for ins in INSETS:
                    for tg in TARGETS:
                        l = fn(view, safe_of(view, ins), len(rd["cards"]), len(rd["skills"]), tg)
                        m = min(m, placed(l["card_w"]) - 6)
    return m


def proposals():
    narrow = safe_of((640, 360), (34, 0, 34, 0))
    uw = min(narrow.w - 16, 460.0)
    up_name = (uw - 16) - 76 - 8 - 130
    res_w = min(narrow.w - 24, 380.0)
    res_btn4 = placed(math.floor((res_w - 24 - 3 * 8) / 4)) - 6
    bw = min(max(narrow.w * 0.44, 252.0), 300.0)
    menu_row = placed(math.floor((bw - 16) / 3.0)) - 6
    slots = {
        "tut_r01": (min_strip(["r01"]), 12, "ui", "tutorial strip r01 (narrowest of 150 layouts)"),
        "tut_r03": (min_strip(["r03"]), 12, "ui", "tutorial strip r03"),
        "tut_r04": (min_strip(["r04"]), 12, "ui", "tutorial strip r04"),
        "tut_r06": (min_strip(["r06"]), 12, "ui", "tutorial strip r06"),
        "upgrade_name": (up_name, 12, "ui", "upgrade row name (640 + notch 34/34)"),
        "card": (min_card_slot(), 12, "ui", "card name (narrowest card, HEAD and WIP)"),
        "result_btn4": (res_btn4, 12, "ui", "result button, 4 buttons (640 + notch)"),
        "pause_btn": (150 - 6, 12, "ui", "pause menu button"),
        "menu_row": (menu_row, 12, "ui", "main menu small button (WIP, 640 + notch)"),
        "round_title24": (None, 24, "ui", "round select title 24 px"),
        "result_star": (math.floor((res_w - 36) / 2.0) - 6 - 22, 12, "ui", "result star row (640 + notch)"),
        "wave_next": (None, 12, "ui", "part of the HUD wave line"),
        "upgrade_status": (uw - 24, 12, "ui", "upgrade status line incl. '● '"),
        "result_inner": (res_w - 36, 12, "ui", "result panel inner width (D31 hint, 1 line wanted)"),
    }
    rows = [
        # key, slot, ko_new (None = keep), en_new (None = keep), fmt args
        ("upgrade.supply_regen", "upgrade_name", "밀가루 증가", "Flour Boost", None),
        ("upgrade.worker", "upgrade_name", "제빵사 효율", "Baker Efficiency", None),
        ("upgrade.base_hp", "upgrade_name", None, "Base Upgrade", None),
        ("tut_deploy_unit", "tut_r01", "식빵병 카드를 눌러 병사를 보내세요.", "Tap the Toast card to send a soldier.", None),
        ("tut_buy_worker", "tut_r01", "제빵사를 눌러 고용하면 밀가루가 더 빨리 모입니다.", "Tap Baker to hire one. Bakers gather flour faster.", None),
        ("tut_destroy_base", "tut_r01", "오른쪽 끝의 곰팡이 둥지를 부수면 승리!", "Destroy the Mold Nest on the far right to win!", None),
        ("tut_tank_unit", "tut_r03", "통식빵을 앞세워 멀리서 포자를 뱉는 적을 막으세요.", "Put Loaf Shields in front to block the spore-spitting enemies.", None),
        ("tut_fast_unit", "tut_r04", None, "Twists rush ahead to reach enemy ranged units.", None),
        ("tut_siege_unit", "tut_r06", "화덕포는 곰팡이 둥지에 3배 피해를 줍니다.", "Ovens deal 3× damage to the Mold Nest.", None),
        ("ui.menu", "result_btn4", "라운드 선택", "Rounds", None),
        ("ui.select_round", "menu_row", None, "Rounds", None),
        ("ui.star_base_hp_any", "result_star", None, "Protect your base", None),
        ("ui.wave_next", "wave_next", None, "Next %ds", (25,)),
        ("ui.upgrade_error", "upgrade_status", "강화하지 못했습니다. 다시 시도해 주세요.", "Upgrade failed. Please try again.", ()),
        ("hint.loss.r05.tactic", "result_inner", "통식빵을 앞에, 롤빵병을 뒤에 두고 곰팡이 장군을 치세요.", "Loaves in front, Rolls behind: beat the Mold General.", None),
        ("hint.loss.upgrade", "result_inner", None, "Replay a round for gold, upgrade, then retry.", None),
    ]
    out = []
    for key, slot, ko_new, en_new, args in rows:
        mx, size, kind, slot_desc = slots[slot]
        rec = {"key": key, "slot": slot_desc, "max_w": mx, "size": size}
        for loc, new in (("ko", ko_new), ("en", en_new)):
            now = TEXT[loc][key]
            shown_now = fmt(now, *args) if args else now
            prop = new if new is not None else now
            shown_prop = fmt(prop, *args) if args else prop
            if key.startswith("upgrade."):
                # shown as '<target name> · <upgrade name>' for unit/hero targets; these three have no prefix
                pass
            if slot == "upgrade_status":
                shown_now, shown_prop = "● " + fmt(now, "invalid_level"), "● " + prop
            rec[loc] = {"now": now, "now_w": tw(shown_now, size, kind), "new": prop, "changed": new is not None,
                        "new_w": tw(shown_prop, size, kind),
                        "fits": (mx is None) or tw(shown_prop, size, kind) <= mx}
        out.append(rec)
    return out


# ----------------------------------------------------------------------------- key resolution / coverage

def key_audit():
    src_keys = set()
    for dp, _dn, fns in os.walk(P("src")):
        if os.path.basename(dp) == "mock":
            continue                       # preview-only mock engine
        for fn in fns:
            if fn.endswith(".gd") and fn != "ui_text.gd":   # ui_text.gd holds the fallback tables, not call sites
                s = open(os.path.join(dp, fn), encoding="utf-8").read()
                src_keys.update(re.findall(r'UiText\.t\("([^"]+)"', s))
                src_keys.update(re.findall(r'"((?:ui|toast|banner|hint|notice|res|upgrade|currency)\.[a-z0-9_.]+)"', s))
    dyn = set()
    for rd in ROUNDS:
        dyn.update("unit.%s.name" % c for c in rd["cards"])
        dyn.update("skill.%s.name" % k for k in rd["skills"])
        dyn.update(rd.get("tutorial", []))
        dyn.add(rd["name_key"])
    dyn.update("toast." + k for k in ("not_enough_gold", "army_full", "on_cooldown", "not_enough_mana", "hero_dead", "wave_incoming",
                                       "boss_incoming", "worker_max", "counterattack", "save_recovered", "save_read_only",
                                       "round_locked", "save_failed"))
    dyn.update(u["name_key"] for u in META["upgrades"])
    dyn.update(["hero.hero_captain.name", "enemy.boss_warlord.name", "enemy.boss_overlord.name", "notice.content_migrated"])
    used = src_keys | dyn
    res = {}
    for loc in ("ko", "en"):
        res[loc] = {k: t(loc, k)[1] for k in sorted(used)}
    unused = sorted(k for k in TEXT["ko"] if k not in used)
    # placeholder parity
    ph = re.compile(r"%\d*[ds%]|\{[a-z_]+\}")
    parity = [k for k in TEXT["ko"] if ph.findall(TEXT["ko"][k]) != ph.findall(TEXT["en"].get(k, ""))]
    keys_only = sorted(set(TEXT["ko"]) ^ set(TEXT["en"]))
    # fallback vs data drift (what a player sees if data/text fails to load)
    drift = []
    for loc, fbn in (("ko", "FALLBACK_KO"), ("en", "FALLBACK_EN")):
        for k, v in FB[fbn].items():
            if k in TEXT[loc] and TEXT[loc][k] != v:
                drift.append({"loc": loc, "key": k, "data": TEXT[loc][k], "fallback": v})
    chars = {loc: "".join(sorted({c for v in TEXT[loc].values() for c in v} |
                                 {c for v in FB["FALLBACK_KO"].values() for c in v} |
                                 {c for v in FB["FALLBACK_EN"].values() for c in v})) for loc in ("ko", "en")}
    cov = {loc: {"chars": len(chars[loc]), "missing_regular": G11.missing(chars[loc]), "missing_bold": G11B.missing(chars[loc])}
           for loc in chars}
    return {"used_keys": len(used), "resolution": res, "unused_in_src": unused, "placeholder_mismatch": parity,
            "keys_only_in_one_locale": keys_only, "fallback_drift": drift, "coverage": cov}


# ----------------------------------------------------------------------------- main

def main():
    os.makedirs(OUT, exist_ok=True)
    cal = calibration()
    print("CALIBRATION %s: %d strings, match with GPOS kern %d, without kern %d" % (cal["source"], cal["n"], cal["match_with_kern"], cal["match_without_kern"]))
    for r in cal["rows"]:
        if abs(r["godot"] - r["ours"]) >= 0.01:
            print("  MISMATCH", r)
    if "--calib" in sys.argv:
        return
    rep = reproduce_0801()
    print("REPRO 08:01 (640x360, notch 34/34, 5 cards, 3 skills, t=40):")
    for k, v in rep.items():
        over = {n: d["over_runtime"] for n, d in v["names"].items() if d["over_runtime"] > 0}
        print("  %-20s card_w=%-8s button=%s runtime_max=%s test_max=%s move=%s skill=%s overflow=%s" % (
            k, v["card_w"], v["button_w_runtime"], v["runtime_max_w"], v["test_max_w"], v["move"], v["skill"], over))
    out = {"calibration": cal, "repro_0801": rep}
    for tag, fn in (("hud_wip", layout_wip), ("hud_head", layout_head)):
        worst, events, res_hidden = check_hud(fn, tag)
        out[tag] = {"worst": sorted(worst.values(), key=lambda r: r["slack"]),
                    "non_ok_events": len(events), "non_ok_sample": events[:50],
                    "resource_panel_hidden": res_hidden}
        groups = {}
        for h in res_hidden:
            cfg_no_round = h["cfg"].split(" ", 1)[1]
            g = groups.setdefault((h["loc"], cfg_no_round, h["show_name"], h["show_income"]), {"rounds": 0, "res_w": h["res_w"],
                                                                                              "need_all": h["need_all"], "avail": h["avail"]})
            g["rounds"] += 1
        out[tag]["resource_panel_hidden_groups"] = [
            {"loc": k[0], "cfg": k[1], "show_name": k[2], "show_income": k[3], **v} for k, v in sorted(groups.items())]
        print("%s: %d slot/key pairs, %d non-ok (key, layout) events, resource-panel parts hidden in %d layouts (%d view/inset/target groups)" % (
            tag, len(worst), len(events), len(res_hidden), len(groups)))
        for r in out[tag]["worst"][:12]:
            print("   slack %6.2f  %-3s %-40s %-16s w=%-6s max=%-7.2f %s  [%s]" % (r["slack"], r["loc"], r["key"][:40], r["where"], r["w"], r["max_w"], r["state"], r["cfg"]))
    scr = check_screens()
    worst_scr = {}
    for r in scr:
        k = (r["loc"], r["key"], r["where"], r["text"])
        if k not in worst_scr or r["slack"] < worst_scr[k]["slack"]:
            worst_scr[k] = r
    out["screens"] = sorted(worst_scr.values(), key=lambda r: (r["where"], r["loc"], r["key"]))
    for tag in ("hud_wip", "hud_head"):
        out[tag].pop("resource_panel_hidden", None)   # the groups keep the same information
    bad = [r for r in scr if r["state"] not in ("ok",) and not r["state"].startswith("wrapped")]
    print("screens: %d rows, %d not ok (truncated / stepped / overflow)" % (len(scr), len(bad)))
    seen = set()
    for r in sorted(bad, key=lambda r: r["slack"]):
        k = (r["loc"], r["key"], r["where"], r["text"])
        if k in seen:
            continue
        seen.add(k)
        print("   %-3s %-28s %-22s %-10s w=%-5s max=%-7.2f '%s' -> '%s' [%s]" % (r["loc"], r["key"][:28], r["where"], r["state"], r["w"], r["max_w"], r["text"], r["drawn"], r["cfg"]))
    ka = key_audit()
    out["keys"] = ka
    pr = proposals()
    out["proposals"] = pr
    print("PROPOSALS (key | slot max | ko now->new w | en now->new w | fits)")
    for r in pr:
        print("  %-22s %-7s ko %s->%s %s | en %s->%s %s" % (r["key"], r["max_w"], r["ko"]["now_w"], r["ko"]["new_w"],
              "ok" if r["ko"]["fits"] else "NO", r["en"]["now_w"], r["en"]["new_w"], "ok" if r["en"]["fits"] else "NO"))
    for loc in ("ko", "en"):
        nd = {k: v for k, v in ka["resolution"][loc].items() if v != "data"}
        print("keys used by src/data and NOT served from data/text/%s.json: %s" % (loc, nd))
    print("unused data keys:", ka["unused_in_src"])
    print("placeholder mismatch:", ka["placeholder_mismatch"], "keys only in one locale:", ka["keys_only_in_one_locale"])
    print("fallback drift:", json.dumps(ka["fallback_drift"], ensure_ascii=False))
    print("coverage:", ka["coverage"])
    with open(os.path.join(OUT, "text_width_report.json"), "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=0)
    print("wrote", os.path.relpath(os.path.join(OUT, "text_width_report.json"), ROOT))


if __name__ == "__main__":
    main()
