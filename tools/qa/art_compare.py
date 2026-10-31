"""07-qa: compare a capture of 07's fixed graphics set with the baseline and apply ART_BASELINE.md rules.

    python tools/qa/art_compare.py --new <art_metrics.json> --base <baseline art_metrics.json> --sha <short>
                                   [--out-md table.md] [--out-json compare.json]
Normally called by tools/qa/art_compare.ps1 -Report. Rule ids, thresholds and owners are the ones in
docs/verification/ART_BASELINE.md section 3 (scenes) and section 5 (animation); keep both in step.
Result per rule: PASS / FAIL against the rule, and BETTER / SAME / WORSE against the baseline (tolerance = rounding).
Gates: G1 (frame valid), G2 (same game state, same harness), G3 (2x = 1x x 2). A failed gate makes the run VOID.
Owner: 07-qa.
"""
import argparse
import json

BATTLE = ["2_r01_t10", "3_r01_t30", "4_r06_t46", "5_r08_peak", "6_r10_boss"]
ALL = ["1_menu"] + BATTLE + ["7_result"]
CARDS = ["4_r06_t46", "5_r08_peak", "6_r10_boss"]
STATE_KEYS = ["sim_t", "units_in_camera", "allies_in_camera", "enemies_in_camera", "boss_in_camera"]


def canonical_sha256(path):
    """Harness identity that does not depend on the checkout: UTF-8 text, BOM dropped, CRLF -> LF, then sha256.
    Equal for LF and CRLF copies of the same file (G2 fix, 2026-11-01)."""
    import hashlib
    t = open(path, "rb").read().decode("utf-8")
    if t.startswith("\ufeff"):
        t = t[1:]
    return hashlib.sha256(t.replace("\r\n", "\n").encode("utf-8")).hexdigest()


def harness_hash(metrics, cap_dir):
    """Canonical capture-script hash of a run: <cap>/harness.json (written by the art_compare job) if present, else the
    hash the capture script reported itself (LF-normalised since 2026-11-01; earlier runs hashed an LF file, which is the
    same value)."""
    import os
    if cap_dir:
        hp = os.path.join(cap_dir, "harness.json")
        if os.path.exists(hp):
            return json.load(open(hp, encoding="utf-8")).get("canonical_sha256", "")
    return metrics.get("ko_1x", {}).get("script_sha256", "")


def accepted_harness(metrics, base_dir):
    """Capture-script hashes the baseline accepts: its own, plus every hash listed in <baseline>/harness_accepted.json.
    A hash is added there only with proof that the new script renders the baseline SHA pixel-identically
    (render-neutral change, e.g. an added read-only layout dump)."""
    import os
    acc = {harness_hash(metrics, base_dir)}
    if base_dir:
        hp = os.path.join(base_dir, "harness_accepted.json")
        if os.path.exists(hp):
            for e in json.load(open(hp, encoding="utf-8")).get("accepted", []):
                acc.add(e.get("canonical_sha256", ""))
    acc.discard("")
    return acc

# (id, owner, player question, scenes, metric, op, threshold, better, tolerance)
#   op: ">=" / "<=" / "==" threshold rule, or None for a no-worse-than-baseline rule
SCENE_RULES = [
    ("C1", "03", "my soldiers are specks on a phone (mm)", ["4_r06_t46", "5_r08_peak"], "regular_unit_height_median_mm_393dp", ">=", 5.0, "higher", 0.05),
    ("C1b", "03", "soldiers never smaller than baseline (mm)", BATTLE, "regular_unit_height_median_mm_393dp", None, None, "higher", 0.05),
    ("C2", "03", "closest ally-enemy pair, normal vision (dE)", BATTLE, "nearest_opposite_dE_normal_min", ">=", 15.0, "higher", 1.0),
    ("C2d", "03", "closest ally-enemy pair, deutan (dE)", BATTLE, "nearest_opposite_dE_deutan_min", ">=", 12.0, "higher", 1.0),
    ("C3", "03+09", "I lose my hero against the street (dL*)", BATTLE, "hero_dL", ">=", 15.0, "higher", 0.5),
    ("C4", "03", "units melt into the lane (% of units dL* < 15)", BATTLE, "unit_dL_share_below_15", "<=", 10.0, "lower", 0.5),
    ("C4m", "03", "unit vs lane contrast median never lower (dL*)", BATTLE, "unit_dL_median", None, None, "higher", 1.0),
    ("C5", "03+09", "the boss is part of the nest (dL*)", ["6_r10_boss"], "boss_dL", ">=", 15.0, "higher", 0.5),
    ("C6", "03", "the army got smaller on screen (% px)", BATTLE, "unit_px_pct", None, None, "higher", 0.02),
    ("W1", "09", "the street is busier than the battle (mean dL* per px)", BATTLE, "lane_busy_dL", "<=", 5.7, "lower", 0.05),
    ("W3", "09", "effects hide my soldiers (% of unit px)", BATTLE, "fx_on_units_pct", "<=", 5.0, "lower", 0.05),
    ("W3m", "09", "effects hide one soldier (% of its px)", BATTLE, "fx_on_unit_max_pct", "<=", 25.0, "lower", 0.5),
    ("U1", "06", "all cards look the same (pairs failing)", CARDS, "cards_pairs_failing_u1", "==", 0, "lower", 0),
    ("U1c", "06", "closest card pair colour (dE, info)", CARDS, "cards_min_dE_normal", None, None, "higher", 0.5),
    ("U2", "06", "the HUD eats the battlefield (% px, max baseline + 0.5)", BATTLE, "hud_px_pct", "base+", 0.5, "lower", 0.05),
    ("U3", "06", "the HUD covers my units (% of unit px)", BATTLE, "hud_on_units_pct", "<=", 0.0, "lower", 0.0),
    ("U4", "06+09", "the HUD bar melts into the ground (median contrast ratio of the HUD top edge vs the ground above; WCAG 1.4.11 asks 3:1)", BATTLE, "hud_ground_contrast_median", ">=", 3.0, "higher", 0.05),
    # LAYOUT.md L1-L8 (04 layout overhaul). 393x873 dp phone: 360 view px = 393 dp, so 1 view px = 1.092 dp = 0.173 mm.
    ("L1", "04", "the HUD takes battlefield away (battlefield %, max -0.5 pp vs baseline)", BATTLE, "battlefield_visible_pct", "base-", 0.5, "higher", 0.05),
    ("L2", "04", "the HUD covers the lane where units stand (HUD px in the lane band)", BATTLE, "hud_on_lane_px", "base+", 0, "lower", 0),
    ("L3", "04", "a button is too small for a thumb (smallest side px; 44 px = 48 dp, Android minimum)", ALL, "touch_min_side_px", ">=", 44.0, "higher", 0.5),
    ("L4", "04", "I hit the wrong button (smallest gap px; 7.3 px = 8 dp, Android spacing)", ALL, "touch_min_gap_px", ">=", 7.3, "higher", 0.2),
    ("L4o", "04", "touch targets overlap (pairs)", ALL, "touch_overlaps", "==", 0, "lower", 0),
    ("L5", "04", "a frequent button is in the top half, away from the thumbs (move/card/skill/worker count)", BATTLE, "frequent_outside_bottom_half", "==", 0, "lower", 0),
    ("L5m", "04", "move buttons further from a bottom corner (mm, max +3 vs baseline)", BATTLE, "thumb_move_max_mm", "base+", 3.0, "lower", 0.5),
    ("L5c", "04", "worst card further from a bottom corner (mm, max +3 vs baseline)", BATTLE, "thumb_card_max_mm", "base+", 3.0, "lower", 0.5),
    ("L5s", "04", "worst skill further from a bottom corner (mm, max +3 vs baseline)", BATTLE, "thumb_skill_max_mm", "base+", 3.0, "lower", 0.5),
    ("L5p", "04", "pause distance from a bottom corner (mm; info only: far from thumbs avoids accidental pauses)", BATTLE, "thumb_pause_max_mm", "info", None, "higher", 0.5),
    ("L6", "02+04", "an enemy is off screen to the right and nothing shows it (scenes without the D39 marker)", BATTLE, "threat_missing", "==", 0, "lower", 0),
    ("L6o", "04", "the right-edge threat marker is under other HUD (overlap px^2)", BATTLE, "threat_right_overlap_px", "<=", 0.0, "lower", 0.5),
    ("L7", "04", "text too small to read (smallest node font px; 11 px = 12 sp, Android minimum body size)", ALL, "text_min_px", ">=", 11, "higher", 0),
    ("L8", "04", "a button sits under the notch (targets outside the safe area)", ALL, "touch_outside_safe", "==", 0, "lower", 0),]

# animation rules (ART_BASELINE.md section 5), evaluated per unit id present in both captures
ANIM_RULES = [
    ("A1", "03", "can I see it walk? (largest edge travel or bob, px)", "walk_motion_px", ">=", 2.0, "higher", 0.0),
    ("A1c", "03", "does the walk change the body? (% of silhouette, max consecutive pair)", "walk_change_max_pct", ">=", 20.0, "higher", 1.0),
    ("A2", "03", "can I tell hitting from walking? (% of silhouette)", "attack_distinct_pct", ">=", 25.0, "higher", 1.0),
    ("A3", "03", "does the attack reach forward? (px)", "attack_reach_px", ">=", 3.0, "higher", 0.0),
    ("A4", "02+03", "can I see that it was hit? (dE of the hit flash)", "hit_dE_mean", ">=", 15.0, "higher", 0.5),
    ("A5", "03", "does it read as dying? (silhouette change in the visible death frames, %)", "death_pose_change_pct", ">=", 40.0, "higher", 1.0),
    ("A6", "02+03", "does the death stay readable long enough? (s)", "death_readable_until_s", ">=", 0.4, "higher", 0.0),
    ("A6b", "02+03", "death frames the player can still see (% of frames)", "death_readable_share_pct", ">=", 60.0, "higher", 1.0),
]


def ok(op, val, thr, base):
    if val is None:
        return None
    if op == ">=":
        return val >= thr
    if op == "<=":
        return val <= thr
    if op == "==":
        return val == thr
    if op == "base+":
        return base is None or val <= base + thr
    if op == "base-":
        return base is None or val >= base - thr
    return None


def verdict(res):
    if not any(x is not None for x in res):
        return None
    return all(x is not False for x in res)


def trend(val, base, better, tol):
    if val is None or base is None:
        return "n/a"
    d = val - base
    if abs(d) <= tol:
        return "SAME"
    return "BETTER" if (d > 0) == (better == "higher") else "WORSE"


def fmt(v):
    if v is None:
        return "—"
    if isinstance(v, float):
        return f"{v:.2f}".rstrip("0").rstrip(".")
    return str(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--new", required=True)
    ap.add_argument("--base", required=True)
    ap.add_argument("--sha", default="")
    ap.add_argument("--out-md", default="")
    ap.add_argument("--out-json", default="")
    ap.add_argument("--new-dir", default="", help="capture folder of the new run (frame diff section)")
    ap.add_argument("--base-dir", default="", help="baseline evidence folder (frame diff section)")
    ap.add_argument("--base-label", default="baseline ad47eda", help="name of the comparison base in the table title")
    a = ap.parse_args()
    new = json.load(open(a.new, encoding="utf-8"))
    base = json.load(open(a.base, encoding="utf-8"))
    tag = "ko_1x"
    ns, bs = new.get(tag, {}).get("scenes", {}), base.get(tag, {}).get("scenes", {})
    gates = []
    # G1: every frame of every captured tag
    for t, r in new.items():
        if not t.endswith(("_1x", "_2x")):
            continue
        for s, m in r.get("scenes", {}).items():
            good = m.get("frame_mean", 0) > 10 and (m.get("frame_near_black_pct") or 0) < 50
            if not good:
                gates.append(("G1", f"{t} {s}", "frame black/invalid", False))
    # G2: same game state and same harness
    for s in BATTLE:
        if s not in ns or s not in bs:
            gates.append(("G2", s, "scene missing", False))
            continue
        diffs = [k for k in STATE_KEYS if ns[s].get(k) != bs[s].get(k)]
        if ns[s].get("prepass_matches") is False:
            diffs.append("prepass_matches")
        gates.append(("G2", s, "state equal" if not diffs else "differs: " + ", ".join(diffs), not diffs))
    hn, acc = harness_hash(new, a.new_dir), accepted_harness(base, a.base_dir)
    gates.append(("G2", "harness", "capture script accepted by the baseline (line-end independent hash)" if hn in acc
                  else f"capture script differs ({hn[:12]} not in {sorted(h[:12] for h in acc)})", hn in acc))
    # G3: 2x copy of 1x, no new fractional drawing. Tolerance 64 1x px: a HUD card-cooldown edge drawn at a fractional
    # height changes by up to 46 1x px between identical runs (ad47eda re-run, ko_2x 6_r10_boss).
    for loc in ("ko", "en"):
        nc, bc = new.get(f"scale_check_{loc}"), base.get(f"scale_check_{loc}")
        if nc and bc:
            for s, v in nc.items():
                bv = bc.get(s, {}).get("diff_px_vs_1x")
                good = bv is None or v["diff_px_vs_1x"] <= bv + 64
                if not good:
                    gates.append(("G3", f"{loc} {s}", f"2x vs 1x differs at {v['diff_px_vs_1x']} px (baseline {bv})", False))
    void = any(not g[3] for g in gates)
    n_frames = sum(len(r.get("scenes", {})) for t, r in new.items() if t.endswith(("_1x", "_2x")))
    if not any(g[0] == "G1" for g in gates):
        gates.insert(0, ("G1", "all frames", f"{n_frames} frames valid (mean > 10, near-black < 50 %)", True))
    if not any(g[0] == "G3" for g in gates):
        has2 = any(new.get(f"scale_check_{loc}") for loc in ("ko", "en"))
        gates.append(("G3", "2x vs 1x", "within baseline exceptions" if has2 else "not checked (no 2x tag in this run)", True))
    rows, summary = [], []
    for rid, owner, q, scenes, key, op, thr, better, tol in SCENE_RULES:
        res, tr = [], []
        for s in scenes:
            nv, bv = ns.get(s, {}).get(key), bs.get(s, {}).get(key)
            if nv is None and bv is None:
                continue
            r_ok = ok(op, nv, thr, bv) if op else None
            t = trend(nv, bv, better, tol)
            if op is None:
                r_ok = t != "WORSE" if t != "n/a" else None
            if op == "info":
                r_ok = None
            res.append(r_ok)
            tr.append(t)
            rows.append({"rule": rid, "owner": owner, "where": s, "base": bv, "new": nv, "pass": r_ok, "trend": t})
        summary.append({"rule": rid, "owner": owner, "question": q, "pass": verdict(res),
                        "trend": "WORSE" if "WORSE" in tr else ("BETTER" if "BETTER" in tr else "SAME")})
    na, ba = new.get(tag, {}).get("anim", {}), base.get(tag, {}).get("anim", {})
    for d in (na, ba):
        for u in d.values():
            vals = [v for v in (u.get("walk_edge_travel_px"), u.get("walk_bob_px")) if v is not None]
            u["walk_motion_px"] = max(vals) if vals else None
    for rid, owner, q, key, op, thr, better, tol in ANIM_RULES:
        res, tr = [], []
        for uid in sorted(set(na) | set(ba)):
            nv, bv = na.get(uid, {}).get(key), ba.get(uid, {}).get(key)
            if nv is None and bv is None:
                continue
            r_ok = ok(op, nv, thr, bv)
            t = trend(nv, bv, better, tol)
            res.append(r_ok)
            tr.append(t)
            rows.append({"rule": rid, "owner": owner, "where": uid, "base": bv, "new": nv, "pass": r_ok, "trend": t})
        summary.append({"rule": rid, "owner": owner, "question": q, "pass": verdict(res),
                        "trend": "WORSE" if "WORSE" in tr else ("BETTER" if "BETTER" in tr else "SAME")})
    hit_unused = [u for u, v in na.items() if v.get("atlas_hit_frames", 0) > 0 and not v.get("hit_anim_drawn_by_game", False)]
    frame_diff = []
    if a.new_dir and a.base_dir:
        import os
        import numpy as np
        from PIL import Image
        for t in [x for x in new if x.endswith(("_1x", "_2x"))]:
            for s in sorted(new[t].get("scenes", {})):
                fn = f"{t}_{s}.png"
                pn, pb = os.path.join(a.new_dir, fn), os.path.join(a.base_dir, fn)
                if os.path.exists(pn) and os.path.exists(pb):
                    x = np.asarray(Image.open(pn).convert("RGB")); y = np.asarray(Image.open(pb).convert("RGB"))
                    if x.shape != y.shape:
                        frame_diff.append({"frame": fn, "changed_pct": None, "bbox": "size differs"})
                        continue
                    m = np.any(x != y, axis=-1)
                    ys, xs = np.where(m)
                    bb = f"x {xs.min()}–{xs.max()}, y {ys.min()}–{ys.max()}" if len(ys) else "—"
                    frame_diff.append({"frame": fn, "changed_pct": round(100.0 * m.sum() / m.size, 2), "bbox": bb})
    result = {"sha": a.sha, "void": void, "gates": [{"gate": g[0], "where": g[1], "detail": g[2], "ok": g[3]} for g in gates],
              "summary": summary, "rows": rows, "hit_anim_in_atlas_not_drawn": hit_unused}
    lines = [f"# Graphics comparison: {a.sha} vs {a.base_label} (07 fixed set, ART_BASELINE.md)", "",
             f"**Run: {'VOID' if void else 'VALID'}** (gates G1–G3 below). Tags in this run: {', '.join(t for t in new if t.endswith(('_1x', '_2x')))}.", "",
             "| Gate | Where | Result |", "|---|---|---|"]
    lines += [f"| {g[0]} | {g[1]} | {'OK' if g[3] else 'FAIL'}: {g[2]} |" for g in gates]
    lines += ["", "## Summary per rule", "| Rule | Owner | Player question | Rule | vs baseline |", "|---|---|---|---|---|"]
    lines += [f"| {s['rule']} | {s['owner']} | {s['question']} | {'n/a' if s['pass'] is None else ('PASS' if s['pass'] else 'FAIL')} | {s['trend']} |" for s in summary]
    lines += ["", "## Rows", "| Rule | Where | Baseline | New | Rule | vs baseline |", "|---|---|---|---|---|---|"]
    lines += [f"| {r['rule']} | {r['where']} | {fmt(r['base'])} | {fmt(r['new'])} | {'PASS' if r['pass'] else ('FAIL' if r['pass'] is False else '—')} | {r['trend']} |" for r in rows]
    if frame_diff:
        lines += ["", "## What changed on screen (main frames vs baseline frames, exact pixels; image px)",
                  "| Frame | Changed % | Where |", "|---|---|---|"]
        lines += [f"| {d['frame']} | {fmt(d['changed_pct'])} | {d['bbox']} |" for d in frame_diff]
        result["frame_diff"] = frame_diff
    lines += ["", "## Not measurable by tools", "- Do the units read as bread knights and mould, are the screens appealing: human naming test (5 players, 5\" screen, point at ally / enemy / hero / dangerous unit within 3 s; fewer than 2 of 5 mistakes). Not run; never marked PASS from frames."]
    if hit_unused:
        lines += [f"- Atlas `hit` animations exist but battle_view never draws them ({len(hit_unused)} unit ids): the on-screen hit is the 0.12 s flash only (A4)."]
    md = "\n".join(lines) + "\n"
    if a.out_md:
        open(a.out_md, "w", encoding="utf-8").write(md)
    if a.out_json:
        json.dump(result, open(a.out_json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps({"sha": a.sha, "void": void, "fail": [s["rule"] for s in summary if s["pass"] is False], "n/a": [s["rule"] for s in summary if s["pass"] is None],
                      "worse": [s["rule"] for s in summary if s["trend"] == "WORSE"],
                      "better": [s["rule"] for s in summary if s["trend"] == "BETTER"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
