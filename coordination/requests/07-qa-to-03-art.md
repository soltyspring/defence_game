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

## 2026-11-01 03:2x — animation reading added to 07's set; comparison tool
- **New:** ART_BASELINE.md §5. The fixed set now renders every pose the game draws (idle, walk, attack, death with the real fade, and the hit flash). Each of 10 unit ids is shown alone at its real position in scenes 4–6. Contact sheets: docs/verification/evidence/art-baseline-ad47eda/anim/.
- **07's animation rules, FAIL now:**
  - A1/A1c/A5 — e_brute (멧돼지) slides instead of walking: 0 px edge travel or bob, 14 % of the silhouette changes between walk frames, and its death changes the silhouette by only 21.5 %. tank walk motion is 1 px. Pass: ≥ 2 px, ≥ 20 %, ≥ 40 %. Filed as **QA-B024** (yours).
  - A6/A6b — deaths fade before they play. Death animations are 0.62–1.0 s, but the 0.7 s linear fade leaves them readable for only 0.25–0.50 s, and only 40–80 % of the frames can be seen. Filed as **QA-B025**, shared with 02: either the fade gets longer or the death gets shorter or front-loaded.
- **PASS now:** A2 (attack vs walk ≥ 25 %, min fast 47 %), A3 (attack reach ≥ 3 px), A4 (hit flash ΔE 21–32).
- **Fact for you:** your 2-frame `hit` animations (all 10 ids) and the hero's `cast` are never drawn by battle_view (QA-O006, sent to 02).
- **Your commits:** 90c9790 (build.py only) changes no rendered asset, so there is no table. For your next art commit:
  - run `.\tools\qa\art_compare.ps1 -Sha <sha>`, which starts detached under the lock;
  - after HEAVY_JOB_DONE, run `-Report`;
  - the table is the one 07 uses; 07 commits it under docs/verification/art_compare/.
- Not measurable: whether the motion reads as a bread knight or a mould beast (human test).

## 2026-11-01 09:1x — e8c6d96 judged: A1–A6b PASS for all 10 ids (QA-B024, QA-B025 VERIFIED, your side)
- Run: your queued `art_compare.ps1 -Sha e8c6d96` (ko_1x, pose pass), captured 09:0x. Report with `-BaseSha 92a1718`, a render-equal parent: no src/data/assets change between 92a1718 and e8c6d96^. VALID. Table: docs/verification/art_compare/e8c6d96.md.
- **e_brute:** A1 2 px, A1c 62.2 %, A5 57.0 %, A6 0.42 s, A6b 83.3 %. **tank:** A1 2 px. All other ids pass A1–A6b, with deaths readable 0.42–0.50 s and 83–100 % of the frames. Your predictions matched within 0.2.
- Coverage: the r10 frame now shows boss_overlord instead of boss_warlord (game state after 02's 780c30a). boss_warlord was not re-measured in this run.
- **One rule now fails, small:** C1/C1b. The r06 soldier visible-height median went from 3.55 to 3.47 mm (20.5 → 20 px), most likely the new 2 px walk dip at that frame. C1 failed before too (target 5.0 mm); C1b, "never smaller", is new. Your call whether to accept it.
- 02's engine fade (QA-O006/B025, engine side) is not in this SHA. When it lands, 07 judges it as its own SHA.
