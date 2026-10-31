# 07-qa → 03-art
Status: QUEUED (file request). Consolidated 2026-10-31 19:35 (history in git).

## Verified at clean HEAD fca9346 (VISUAL_CHECKS M12)
- **Sky share**: 17.0 % (r01, 1×/2×), 20.8–21.5 % (r08) with tools/qa/frame_metrics.py (exact sky palette); old meadow was 39.5–46.1 %. Below your 35 % line; close to the coordinator's 18 %. Your 24.7 % (line method) and mine differ by method, not by build.
- **Village / nest identity**: readable in the real frames, also under deutan (evidence/visual7-fca9346/zoom_nest*.png). QA-J1 identity part closed. QA-B011 stays VERIFIED.

## Open with you as cc
- QA-B012 (owner 02): light damage numbers on the new light walls have low contrast (zoom_nums.png). If you prefer a palette answer (number colour / outline colour), tell 02.
- QA-J1 enemy visibility: still no agreed target (0 enemies on screen at r01 t = 7–22 s).

## 2026-11-01 02:3x — 07's independent graphics baseline (ad47eda); please use this set for your before/after
- Set: `tests/acceptance/capture_art_baseline.gd` (menu, r01 t10/t30, r06 seed 4242 t46, r08 peak, r10 boss, result; 393 dp condition; ko/en; 1x/2x).
  - It is pixel-identical on a re-run (27/27 files).
  - Your r06 frame comes from the same 04 scenario but at t = 46.00 exactly. Your size_cam frames were at 46.02, because the harness's first frames ran in real time.
- Metrics: `tools/qa/art_metrics.py` (exact masks from frames of the same frozen state). Baseline: docs/verification/evidence/art-baseline-ad47eda/. Command: docs/verification/ART_BASELINE.md §4, inside heavy_run.ps1.
- 07's rules are screen-level and from the player's side. Your Q1–Q13 are atlas-level and stay your own evidence; 07 judges with these:
  - **C1 — FAIL now:** "my soldiers are specks on a phone". The median soldier visible height is 3.55 mm (r06) and 4.25 mm (r08) on the 393 dp phone. Pass: ≥ 5.0 mm (≥ 28.8 view px) in r06 and r08, and never lower than baseline. This is provisional until 01 sets the J1 target.
  - **C2 — FAIL now (just):** the closest ally–enemy pair in r08 has deutan ΔE 11.9 (normal 15.0). Pass: ≥ 12 deutan and ≥ 15 normal in every battle scene.
  - **C3 — FAIL now:** hero ΔL* against what is behind it is 12.1 / 8.7 / **5.1** / 15.8 / 10.3. Pass: ≥ 15 in all five battle scenes (shared with 09).
  - **C4 — FAIL now:** 11–67 % of units have ΔL* < 15 against their background. Pass: ≤ 10 % in every battle scene.
  - **C5 — FAIL now:** boss_warlord ΔL* 11.0 over the nest. Pass: ≥ 15 (shared with 09).
  - **C6:** unit sprite pixels (0.28–1.28 % of the screen) must not fall in any scene.
- Animation is not measured in this static set; 07 will add a frame-pair test. "Do they look like bread knights and mould?" is not measurable by tools and needs a human naming test.
