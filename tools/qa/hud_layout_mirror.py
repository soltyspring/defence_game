"""Python mirror of src/ui/hud_layout.gd compute() (2026-11-10) for a no-Godot reachability sweep.

    python tools/qa/hud_layout_mirror.py

Checks, for a grid of logical view sizes: every touch rect is inside the safe rect and no two overlap.
`fit=False` reproduces the layout before the fit row (v0.1.5). This mirrors the maths only; the Godot test
tests/ui/test_fable52_core.gd must still be run for the real thing.
"""
GAP, GROUP_GAP, TOUCH_GAP, THREAT_MIN, CARD_NAME_W = 4.0, 12.0, 8.0, 44.0, 42.0
FIT_GAP, FIT_MIN = 2.0, 16.0


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def skills_w_old(skill, n, gg):
    return 0.0 if n <= 0 else n * skill + (n - 1) * TOUCH_GAP + gg


def card_fit(width, n_cards, move, skill, n_skills, gg):
    fixed = (2.0 * move + GAP * 2) + gg * 2 + skills_w_old(skill, n_skills, gg) + max(n_cards - 1, 0) * TOUCH_GAP
    return (width - fixed) / float(n_cards + 1)


def compute(vw, vh, n_cards, n_skills, t=40.0, fit_enabled=True, old_map=False, boss_bar=True):
    t = max(t, 40.0)
    sx, sy, sw, sh = 4.0, 4.0, vw - 8.0, vh - 8.0
    ex, ey = sx + sw, sy + sh
    out = {"min_target": t, "safe": (0, 0, vw, vh)}
    top_h = t
    pause = (ex - t, sy, t, t)
    res_w = clamp(sw * 0.26, 132.0, 180.0)
    bars_x = sx + res_w + GAP * 2
    follow = (pause[0] - TOUCH_GAP - t, sy, t, t)
    map_w = round(clamp(sw * 0.22, 126.0, 150.0)) if old_map else round(clamp(sw * 0.15, 84.0, 104.0))
    mapr = (follow[0] - TOUCH_GAP - map_w, sy, map_w, t)
    bars_end = mapr[0] - GAP * 2
    if not old_map and bars_end - bars_x < 60.0:
        mapr = (follow[0], sy, 0.0, t)
        bars_end = follow[0] - GAP * 2
    out.update(pause=pause, follow=follow, minimap=mapr, bases=(bars_x, sy, max(bars_end - bars_x, 60.0), 22.0))
    move, card_h, row_bottom, skill = max(t, 52.0), max(t + 8.0, 56.0), ey, max(t, 48.0)
    skills_in_row = True
    gg = GROUP_GAP
    cw = card_fit(sw, n_cards, move, skill, n_skills, gg)
    if cw < max(t, CARD_NAME_W):
        skill = t; cw = card_fit(sw, n_cards, move, skill, n_skills, gg)
    if cw < max(t, CARD_NAME_W):
        move = t; cw = card_fit(sw, n_cards, move, skill, n_skills, gg)
    if cw < t:
        gg = TOUCH_GAP; cw = card_fit(sw, n_cards, move, skill, n_skills, gg)
    if cw < t and n_skills > 0:
        skills_in_row = False; gg = GROUP_GAP; cw = card_fit(sw, n_cards, move, skill, 0, gg)
    card_w = clamp(cw, t, max(t, 50.0))
    tg, mg = TOUCH_GAP, GAP * 2
    col_top = row_bottom - card_h - GAP * 2 - n_skills * skill - max(n_skills - 1, 0) * TOUCH_GAP
    fit = fit_enabled and (cw < t or (not skills_in_row and col_top < sy + top_h + TOUCH_GAP))
    if fit:
        skills_in_row = True; gg = tg = mg = FIT_GAP
        n = 3 + n_cards + n_skills
        u = clamp(float(int((sw - (n - 1) * FIT_GAP) / float(n))), FIT_MIN, t)
        move = skill = card_w = u
        card_h = clamp(sh - top_h - TOUCH_GAP, u, card_h)
        out["min_target"] = u
    out["fit"] = fit
    skills_w = (n_skills * skill + max(n_skills - 1, 0) * tg + gg) if (skills_in_row and n_skills > 0) else 0.0
    need = n_cards * card_w + max(n_cards - 1, 0) * tg
    ml = (sx, row_bottom - move, move, move)
    mr = (sx + move + mg, row_bottom - move, move, move)
    worker = (mr[0] + mr[2] + gg, row_bottom - card_h, card_w, card_h)
    lo = worker[0] + worker[2] + gg
    hi = ex - skills_w
    x0 = lo + max(0.0, (hi - lo - need) / 2.0)
    cards = [(x0 + i * (card_w + tg), row_bottom - card_h, card_w, card_h) for i in range(n_cards)]
    skills = []
    for i in range(n_skills):
        if skills_in_row:
            skills.append((ex - (n_skills - i) * skill - (n_skills - 1 - i) * tg, row_bottom - skill, skill, skill))
        else:
            skills.append((ex - skill, row_bottom - card_h - GAP * 2 - (i + 1) * skill - i * TOUCH_GAP, skill, skill))
    boss_y = sy + top_h + TOUCH_GAP
    out["banner_bottom"] = boss_y + (16.0 if boss_bar else 0.0) + 50.0 + 24.0
    out["touch"] = [pause, ml, mr, worker] + ([mapr] if mapr[2] > 0 else []) + [follow] + cards + skills
    return out


def problems(l):
    r = l["touch"]; vw, vh = l["safe"][2], l["safe"][3]
    bad = []
    for i, a in enumerate(r):
        if a[0] < -0.01 or a[1] < -0.01 or a[0] + a[2] > vw + 0.01 or a[1] + a[3] > vh + 0.01:
            bad.append(("outside", i))
        for j in range(i + 1, len(r)):
            b = r[j]
            if a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]:
                bad.append(("overlap", i, j))
    return bad


def sweep(**kw):
    fails = []
    n = 0
    for vw in list(range(240, 641, 8)) + [800, 960, 1280]:
        for vh in (120, 160, 200, 270, 360, 450):
            for nc in (1, 3, 5):
                for ns in (0, 3):
                    n += 1
                    if problems(compute(float(vw), float(vh), nc, ns, **kw)):
                        fails.append((vw, vh, nc, ns))
    return n, fails


if __name__ == "__main__":
    n, old = sweep(fit_enabled=False, old_map=True)
    _, new = sweep()
    print(f"layouts checked: {n}")
    print(f"before (v0.1.5 maths): {len(old)} with an unreachable/overlapping control; e.g. {old[:4]}")
    print(f"after: {len(new)}; {new[:6]}")
    for vw in (640, 800):
        a, b = compute(vw, 360.0, 5, 3, old_map=True, fit_enabled=False), compute(vw, 360.0, 5, 3)
        print(f"view {vw}x360: minimap {a['minimap'][2]:.0f} -> {b['minimap'][2]:.0f} px, base bars {a['bases'][2]:.0f} -> {b['bases'][2]:.0f} px, "
              f"banner bottom without boss {a['banner_bottom']:.0f} -> {compute(vw, 360.0, 5, 3, boss_bar=False)['banner_bottom']:.0f}")
    wide = [f for f in new if f[0] >= 640]
    assert not wide, wide
