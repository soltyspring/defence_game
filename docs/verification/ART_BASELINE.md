# Graphics baseline for independent judgement (owner: 07-qa)
Baseline SHA **ad47eda**: a clean `git archive` snapshot with its own import (import guard 0 missing) and a private APPDATA, captured 2026-11-01 02:07–02:12 inside `coordination/heavy_run.ps1` on `\\.\DISPLAY2`.
Evidence: [evidence/art-baseline-ad47eda/](evidence/art-baseline-ad47eda/) holds 28 frames, 4 `*_art_report.json`, `art_metrics.json` and `rerun_compare.json`. The layer frames are local in `build/qa07/art-baseline-ad47eda/run1/layers/` (git-ignored) and can be regenerated.
This file is 07's yardstick for the three graphics owners: 03 (characters, animation), 09-art-world (background, bases, effects) and 06-art-ui (UI, cards, icons, logo). It is written from the player's side and does not copy any owner's own criteria (03 Q1–Q13 are atlas-level; these are screen-level). Desktop frames only, not Android certification.

## 1. The fixed set
- **Condition:** 393×873 dp phone in landscape. The view is 800×360 logical px (1080×2400 at density 2.75, k = 3), with notches 34/0/34/0 and a 44 px touch target (04 ZOOM_PREVIEW).
  - 1x window: 800×360. 2x window: 1600×720, same layout.
  - Locales: ko and en.
- **Scenes:** `tests/acceptance/capture_art_baseline.gd`, one process per tag.

| Scene | What | Fixed by |
|---|---|---|
| 1_menu | main menu, returning player (10 rounds open), coins 0 | boot + 3 s |
| 2_r01_t10 / 3_r01_t30 | r01, competent bot (`bot_player` policy 2), LOW upgrades | exactly 600 / 1800 sim steps |
| 4_r06_t46 | 04's ZOOM_PREVIEW scenario: no upgrades, 17 scripted deploys, hero 150 px behind the front | exactly 2760 steps (04/03 frames are at t = 46.02 because their first 3 frames ran in real time) |
| 5_r08_peak | r08, competent bot, LOW upgrades, at the most units inside the camera | pure-sim pre-pass on a 0.25 s grid, t ≥ 20 s: step 9495, t = 158.25 s, 27 units; the run reproduced the count (`prepass_matches: true`) |
| 6_r10_boss | r10, competent bot, LOW upgrades, 1 s after the boss first enters the camera | pre-pass: boss in camera at step 6510; frame at step 6570, t = 109.5 s |
| 7_result | r01 result panel after the bot's win | 4 s after the end |

- Same frame on every re-run:
  - `seed(4242)` runs before `App.start_round`, so the battle seed is 641615738 in every round.
  - The battle clock is stopped in the same call (`time_scale = 0`), and only the script steps the sim.
  - The camera is snapped to hero x + 60 every frame, with no shake.
  - Tutorials are marked done, and each capture waits 3 s so transient toasts expire.
- **Re-run proof:** a second ko_1x run in the same lock is pixel-identical on **27/27 files**, main frames and layer frames (`rerun_compare.json`).
- **Baseline re-made 2026-11-01 02:5x–03:05** with the animation pass (§5), at the same SHA, through `tools/qa/art_compare.ps1`. The capture script sha256 is 3c092c46… and is recorded in every report (gate G2).
- **G2 line-end fix (2026-11-01 06:5x).** The harness hash is now computed after normalising the text: UTF-8, BOM dropped, CRLF → LF, then sha256.
  - Python `art_compare.canonical_sha256`, the capture script itself and the art_compare job (`<cap>/harness.json`, which also records the git blob id) all use this rule.
  - Checked on LF, CRLF and CRLF+BOM copies of the same file: one canonical value (fc1ccf01…), where the raw sha256 values were 3 different ones.
  - The committed baseline file (bbc839d blob) gives canonical 3c092c46…, the same as before, so the existing baseline and the 700692d table stay VALID (re-reported).
  - A changed capture script is accepted only if `<baseline>/harness_accepted.json` lists its hash with proof that it renders the baseline SHA pixel-identically. A test with a foreign hash gives VOID.
  - Against the first set, 107 of 108 files are pixel-identical (`remake_vs_first.json`).
  - The one difference is `ko_2x_6_r10_boss.png`: 184 px in one 2x row at the top edge of a card. The HUD's card cooldown shade sits at a fractional height there and depends on real time. All battlefield layers are identical.
  - The evidence folder now holds the re-made frames and metrics.
- **Masks:** `tools/qa/art_metrics.py` takes exact pixel differences between frames of the same frozen state:
  - HUD: UI layer hidden.
  - TEXT: damage numbers hidden.
  - FX: effects and projectiles hidden.
  - UNIT: units and hero hidden, minus HP-bar rects.
  - Check: 0 UNIT pixels fall outside the recorded unit rects, and 2x has exactly 4× the 1x pixels.

## 2. Baseline numbers (ko_1x; 1x and 2x ratios are identical, en differs only in HUD text by ≤ 0.05 pp)
| Metric (player question) | r01 t10 | r01 t30 | r06 t46 | r08 peak | r10 boss |
|---|---|---|---|---|---|
| units in camera, ally / enemy ("do I see the fight?") | 2 / 1 | 4 / 5 | 5 / 6 | 10 / 17 | 14 / 1 (boss) |
| unit sprite pixels, % of screen ("how much of the screen is my army?") | 0.28 | 0.58 | 1.09 | 1.28 | 0.87 |
| same, after HUD, effects and numbers cover it | 0.28 | 0.58 | 1.06 | 1.24 | 0.87 |
| J1 rect % (capture_m8 definition: walk-frame boxes + base boxes) | 1.4 | 4.3 | 4.6 | 8.4 | 7.2 |
| soldier visible height, median px / mm on the 393 dp phone | 25.5 / 4.42 | 20.0 / 3.47 | 20.5 / 3.55 | 24.5 / 4.25 | 29.0 / 5.03 |
| unit vs what is behind it, ΔL* median / min (who) | 14.5 / 12.1 (hero) | 25.6 / 8.7 (hero) | 24.7 / 5.1 (hero) | 23.4 / 8.6 (e_spitter) | 24.1 / 10.3 (hero) |
| units with ΔL* < 15 | 66.7 % | 11.1 % | 18.2 % | 18.5 % | 20.0 % |
| hero ΔL* ("can I find my hero?") | 12.1 | 8.7 | **5.1** | 15.8 | 10.3 |
| boss ΔL* (boss_warlord, 45 px tall) | — | — | — | — | 11.0 |
| ally vs enemy mean colour ΔE76, normal / deutan / protan | 29.6 / 28.9 / 24.8 | 27.1 / 26.1 / 22.4 | 25.1 / 23.7 / 20.3 | 21.0 / 18.8 / 15.5 | 21.4 / 19.4 / 16.4 |
| closest ally–enemy pair ΔE, normal / deutan | 24.6 / 23.6 | 23.7 / 22.2 | 22.4 / 21.4 | 15.0 / **11.9** | 17.5 / 14.6 |
| unit pixels covered by effects, all / worst unit | 0 / 0 % | 0 / 0 % | 2.34 / 9.45 % | 2.53 / 17.41 % | 0 / 0 % |
| unit pixels covered by HUD / by damage numbers | 0 / 0 % | 0 / 0 % | 0 / 0 % | 0 / 0 % | 0 / 0 % |
| HUD pixels, % of screen | 10.05 | 10.12 | 15.28 | 16.18 | 18.55 |
| lane background detail behind units, mean \|ΔL*\| per px | 5.20 | 5.43 | 5.17 | 5.16 | 5.15 |
| card icons: closest pair, mean-colour ΔE normal / shape distance | — (1 card) | — | **0.6** (식빵병/통식빵) / 9.2 | 3.6 (통식빵/화덕포, both dimmed) / 5.0 | 1.4 (식빵병/롤빵병) / 5.0 |

Notes:
- **J1 and "enemies in camera" differ from the earlier 5.0–6.9 % and 0.** The earlier numbers came from a 640-wide view, a casual bot and r01 t = 7–22 s. This set uses the 800-wide 393 dp view and a competent bot that walks forward. Both sets are true; only this set is the comparison base from now on.
- **Pixel exactness at 2x:** the 2x frame equals the 1x frame scaled ×2 except for 11–252 1x pixels. The changed pixels sit in the worker-card corner (all battle scenes), the menu band at y ≈ 160–200 and near the r08 enemy group. Something there is drawn at fractional positions. This is recorded as the baseline, not as a defect.
- **Observation QA-O005 (02, P3):** damage numbers on the enemy base stack into a column up to ≈ 8 rows high (r10 boss frame, r01 result frame). This is not a QA-B012 regression: there are 0 overlaps.

## 3. 07's rejection reasons and pass rules
How to read the rules:
- **"Better"** means: the same set at the new SHA passes every hard reject below, meets the owner's improvement line, and does not push another owner's metric past its tolerance.
- **Tolerance:** the metrics are deterministic, so tolerance only covers rounding: ±0.05 pp for %, ±0.5 for ΔE and ΔL*.
- **FAIL now** marks rules that the baseline itself already fails. These are the strongest current rejection reasons.

### Gates for every owner
| ID | Player-side reason | Rule |
|---|---|---|
| G1 | "the screen is broken" | every frame has mean > 10 and near-black < 50 %, otherwise the run is void |
| G2 | "it plays differently" | same `sim_t`, units in camera, ally/enemy counts and `prepass_matches: true` as the baseline for each scene. Any difference means the art change touched gameplay or the harness: void until explained |
| G3 | "pixel art turned blurry" | 2x frames stay a ×2 copy of 1x except at most the baseline pixels above + 64 1x px (the card-cooldown edge varies by up to 46 px between identical runs) |

### 03-art (characters, animation)
| ID | Strongest rejection reason | Pass rule | Baseline |
|---|---|---|---|
| C1 | "my soldiers are specks on a phone" | soldier visible height median ≥ **5.0 mm** on the 393 dp phone (≥ 28.8 view px) in r06 and r08; never lower than baseline in any scene | 3.55 / 4.25 mm: **FAIL now** |
| C2 | "I can't tell my army from theirs" | closest ally–enemy pair ΔE ≥ 15 normal and ≥ 12 deutan in every battle scene; never lower than baseline − 1 | r08 deutan 11.9: **FAIL now** (just) |
| C3 | "I lose my hero against the street" | hero ΔL* ≥ 15 in all 5 battle scenes (shared with 09: the background is half of it) | 5.1–15.8: **FAIL now** (4 of 5) |
| C4 | "units melt into the lane" | ≤ 10 % of units with ΔL* < 15 in every battle scene; median never lower than baseline − 1 | 11–67 %: **FAIL now** |
| C5 | "the boss is part of the nest" | boss ΔL* ≥ 15 (shared with 09) | 11.0: **FAIL now** |
| C6 | "the army got smaller" | unit sprite pixels % never lower than baseline in any scene | — |
| — | animation reads (walk, attack, hit, death) | NOT MEASURED in this static set. 07 will add a frame-pair test; until then 03's atlas checks are 03's evidence, not 07's | — |
| — | "do they look like bread knights / mould?" | **NOT MEASURABLE** by tools: human naming test (5 players, 5" screen, point at ally/enemy/hero/dangerous unit within 3 s, fewer than 2 of 5 mistakes) | not run |

### 09-art-world (background, bases, effects)
| ID | Strongest rejection reason | Pass rule | Baseline |
|---|---|---|---|
| W1 | "the street is busier than the battle" | lane background detail ≤ baseline + 0.5 (≤ 5.7) in every scene, unless the unit ΔL* median rises by ≥ 3 in that scene | 5.15–5.43 |
| W2 | "the background swallows my hero / the boss" | C3 and C5 apply; a background change that lowers hero or boss ΔL* in any scene is rejected | **FAIL now** (as C3/C5) |
| W3 | "effects hide my soldiers" | unit pixels covered by effects ≤ 5 % per scene and ≤ 25 % for the worst unit | 2.53 % / 17.41 %: PASS |
| W4 | bases (village keep, mould nest) | not separated by a mask in this set; J1 rect only. "Does the nest look like a mould nest?" is **NOT MEASURABLE** (human) | — |

### 06-art-ui (UI, cards, icons, logo)
| ID | Strongest rejection reason | Pass rule | Baseline |
|---|---|---|---|
| U1 | "all cards look the same" | for every pair of card icons on screen: (mean-colour ΔE ≥ 10 normal and ≥ 8 deutan) or shape distance ≥ 12 | 0.6 / 5.0; failing pairs 6/10 (r06), 1/10 (r08), 2/10 (r10): **FAIL now** |
| U2 | "the HUD eats the battlefield" | HUD pixels % never more than baseline + 0.5 pp in any scene. A reduction target is 04/01's (layout), not 06's | 10.05–18.55 % |
| U3 | "the HUD covers my units" | HUD-covered unit pixels stay 0 % | 0: PASS |
| U4 | "the HUD bar melts into the ground" (06 955adc0 measured 2.60–2.66:1 on 09's new street) | median, over screen columns, of the WCAG relative-luminance contrast between the top 2 px inside the bottom HUD and the ground 2–4 px above it: ≥ 3.0 ([WCAG 2.1 SC 1.4.11](https://www.w3.org/TR/WCAG21/#non-text-contrast) asks 3:1 for UI component boundaries) | ad47eda ko_1x: r01 2.44 (**FAIL now**), r06/r08/r10 3.51; 10th percentile 2.44 everywhere. Shared 06 (HUD frame) + 09 (ground) |
| U4 | crisp UI | G3 | — |
| — | logo, menu and result "look good" | **NOT MEASURABLE** (human). Measurable part: menu and result frames render (G1), and the title fits (VISUAL_CHECKS C14) | — |

## 4. How owners compare (same set, same table for everyone)
1. Commit the change and wait until it is on origin/main. 07 judges only committed SHAs.
2. Start the capture. It runs detached under the PC-wide lock (`coordination/heavy_run_detached.ps1`) and returns at once:
```
.\tools\qa\art_compare.ps1 -Sha <commit>                       # ko_1x (+ animation pass) while iterating
.\tools\qa\art_compare.ps1 -Sha <commit> -Tags ko_1x -NoAnim   # UI-only commits: no pose pass (fewer GPU frames)
.\tools\qa\art_compare.ps1 -Sha <commit> -Tags ko_1x,en_1x,ko_2x,en_2x   # final claim (one tag per window, still one job)
```
   - The job makes a clean `git archive` of the commit with its own import (private APPDATA, import guard) and overlays 07's capture script.
   - It runs a headless dry check, then captures each tag on the secondary monitor.
   - Poll the printed log for `^HEAVY_JOB_DONE` in short calls.
3. Make the table (light, no Godot):
```
.\tools\qa\art_compare.ps1 -Sha <commit> -Report -Tags <same tags>
```
   - This writes `build/qa07/art_compare/<sha>/table.md` and `compare.json`, plus `anim_sheets/` with one contact sheet per unit id.
   - The table holds the gates (G1–G3; any FAIL = VOID), PASS/FAIL per rule, and BETTER/SAME/WORSE against the baseline per scene and per unit.
   - 07 commits the table of every art commit it judges under `docs/verification/art_compare/<sha>.md`.
4. A before/after claim built from other frames or other conditions is not accepted by 07.
5. **When gameplay changed in between** (a bot, sim or data commit between the baseline and the art commit), G2 makes the run VOID against ad47eda. This first happened with 02's 780c30a. In that case 07 captures the art commit's parent once and compares with it:
```
.\tools\qa\art_compare.ps1 -Sha <art commit>^ -Tags ko_1x [-NoAnim]   # one job, if no capture of a render-equal parent exists yet
.\tools\qa\art_compare.ps1 -Sha <art commit> -Report -Tags ko_1x -BaseSha <parent>
```
   - The absolute rules are unchanged. BETTER/SAME/WORSE then describe that one commit.
   - A capture can serve as the parent of a later commit only if no render-affecting path (src, data, scenes, assets, project.godot) changed in between.
6. `art_compare.ps1` refuses to queue a second job for a SHA while one is queued or running, whoever started it. Two roles queued 92a1718 at 07:29 and 07:35; the second job found the `.capture_done` mark and exited without Godot.

**Shared roots:** C3 (hero), C5 (boss) and W1 depend on both 03 and 09. 07 rejects whichever change makes them worse. The rule passes only when the combined result passes.

## 5. Animation reading (added 2026-11-01, same SHA and frozen states)
- **Method:** `capture_art_baseline.gd --anim`, ko_1x only (1x view px).
  - In scenes 4–6, one instance per unit id is shown alone at its real position on the real background, with every other unit, the UI, damage numbers and effects hidden.
  - Each pose the game can draw is rendered: idle, walk, attack and death frames, at t = (i + 0.5) / fps. Death also fades exactly as battle_view does: alpha = dead_t / 0.7 with dead_t = 0.7 − t.
  - The hit reaction the game draws is also rendered: a 0.12 s red flash on walk frame 0.
  - `art_metrics.py` masks each pose against the empty background. HP bars are hidden for troops, and hero/boss bar rects are masked.
  - Contact sheets (×2): [evidence/art-baseline-ad47eda/anim/](evidence/art-baseline-ad47eda/anim/), with rows idle, walk, attack, hit flash, death.
- **Coverage:** 10 unit ids. siege, e_bomber and boss_overlord were not on screen in scenes 4–6. The worker is drawn separately and is not a combat unit.
- **Fact from code:** every one of the 10 ids has a 2-frame `hit` animation in its atlas, but `battle_view._anim_name()` only maps walk / attack / death / idle. The hit animation is never shown; the player sees only the flash (observation QA-O006, 02 wiring, 03 FYI). The hero's `cast` animation is unused the same way.

| Unit | walk change (max consecutive, % of silhouette) | walk motion (largest edge travel or bob, px) | attack vs closest walk frame % | attack reach px | hit flash ΔE | death silhouette change % | death readable until s (share of frames) |
|---|---|---|---|---|---|---|---|
| melee_basic 식빵병 | 76.0 | 2 | 85.8 | 8 | 24.9 | 83.7 | 0.38 (50 %) |
| ranged_basic | 69.2 | 2 | 77.4 | 3 | 25.1 | 80.6 | 0.38 (50 %) |
| tank 통식빵 | 62.3 | **1** | 69.3 | 5 | 25.6 | 82.1 | 0.50 (67 %) |
| fast | 66.3 | 2 | 47.1 | 5 | 30.8 | 78.8 | **0.25 (40 %)** |
| hero_captain | 66.1 | 4 | 80.2 | 9 | 32.1 | 84.5 | 0.38 (50 %) |
| e_grunt | 74.4 | 4 | 77.7 | 6 | 22.4 | 86.5 | 0.50 (67 %) |
| e_spitter | 69.2 | 3 | 83.1 | 9 | 27.0 | 79.9 | 0.38 (50 %) |
| e_swarm 초파리 떼 | 81.2 | 3 | 96.3 | 3 | 21.1 | 100 | 0.50 (80 %) |
| e_brute 멧돼지 | **14.0** | **0** | 62.4 | 4 | 25.1 | **21.5** | 0.43 (50 %) |
| boss_warlord | 58.4 | 2 | 76.4 | 18 | 25.2 | 85.0 | 0.43 (43 %) |

07's animation rules (player side; lengths on the 393 dp phone, 1 view px = 0.17 mm, about 2 arcmin at 30 cm):
| ID | Owner | Strongest rejection reason | Pass rule (each unit id) | Baseline |
|---|---|---|---|---|
| A1 | 03 | "that unit is sliding, not walking" | largest edge travel or bob over the walk cycle ≥ 2 px (0.35 mm, about 4 arcmin) | **FAIL now**: e_brute 0, tank 1 |
| A1c | 03 | same, for the body as a whole | ≥ 20 % of the silhouette changes between two consecutive walk frames | **FAIL now**: e_brute 14 % |
| A2 | 03 | "I can't tell who is hitting" | the most distinct attack frame differs from its closest walk frame by ≥ 25 % | PASS (min fast 47 %) |
| A3 | 03 | "the attack does not reach" | front edge moves forward ≥ 3 px in the attack | PASS (min 3: ranged, swarm) |
| A4 | 02+03 | "I can't see that it was hit" | hit reaction ΔE ≥ 15 over the body | PASS (21–32). It lasts only 0.12 s, and the drawn hit animation is unused (QA-O006) |
| A5 | 03 | "it just vanishes, it doesn't die" | silhouette change ≥ 40 % within the death frames the player can still see | **FAIL now**: e_brute 21.5 % |
| A6 | 02+03 | "it disappears before I see it die" | death stays readable ≥ 0.4 s (≥ 25 % of the body at mean \|ΔL*\| ≥ 10) | **FAIL now**: fast 0.25 s; melee, ranged, hero, spitter 0.38 s |
| A6b | 02+03 | same, as wasted frames | ≥ 60 % of the death frames are still readable | **FAIL now** in 7 of 10 ids (40–50 %). Death animations are 0.62–1.0 s, but the linear 0.7 s fade (02) hides the second half |
| — | — | "does it move like a bread knight / a mould beast, does it feel alive" | **NOT MEASURABLE** by tools (human test; never marked PASS from frames) | not run |

These rules judge what the game draws on screen. 03's atlas Q5–Q8 measure the sprite sheets and stay 03's own evidence.

## 6. Judged art commits (tables in [art_compare/](art_compare/))
| SHA | Owner | Run | Result vs baseline |
|---|---|---|---|
| ad47eda | — | reference (baseline vs itself) | VALID, all SAME; FAIL rows are the baseline's own failures |
| 700692d | 06-art-ui | ko/en × 1x/2x, VALID (G1–G3 OK) | UI changed where 06 said: menu logo (3.1 % ko / 4.1 % en of the frame), move buttons and skill plates (0.43–0.69 %). U1 unchanged (card badges are not built into ui_main yet). U2 HUD pixels +0.03–0.07 pp (PASS, but the trend is WORSE in r06/r08/r10). U3 0. No other owner's metric moved |
| 90c9790 | 03 | not captured | tools/art/build.py only, no rendered asset changed (06 rebuilds ui_main next) |
| ad47eda (layout) | — | ko_1x, layout baseline, VALID | new capture script (layout dump) proven render-identical; L1–L8 baseline: [art_compare/ad47eda-layout.md](art_compare/ad47eda-layout.md), rules in [LAYOUT.md](LAYOUT.md) |
| adc0965 | 06-art-ui | ko_1x, no pose pass, VALID | **U1 PASS (BETTER):** failing card pairs 6/1/2 → 0/0/0. Closest mean-colour ΔE 0.6 → 11.7 (r06), 3.6 → 11.2 (r08), 1.4 → 14.3 (r10). The deutan-close pair 식빵병/롤빵병 (ΔE 3.4) passes on shape 17.5. U2 HUD +0.10–0.43 pp (PASS, WORSE; r06 15.71 % is 0.07 pp from the limit); L1 the same. L4 unchanged FAIL (04) |
| 02ec60f | 06-art-ui | ko_1x, no pose pass, VALID | same screen as adc0965 (26/27 identical, the 27th is the real-time cooldown edge). The new HUD chrome is not wired yet |
| 92a1718 | 09-art-world | ko_1x, no pose pass, **VOID against ad47eda** | G2: game state differs in r01 t10, r08 and r10. 02's 780c30a (bot stall fix) changed the bot before this commit, so the baseline no longer applies. 07 compares it with its parent a67b9f1 (queued) |
| e8c6d96 | 03 | ko_1x with the pose pass, VALID against 92a1718 (render-equal parent) | **A1–A6b PASS for all 10 ids** (QA-B024, QA-B025 VERIFIED, 03 side); matches 03's prediction (brute A1 2 px, A1c 62.2 %, A5 57.0 %, A6 0.42 s, A6b 83 %). C1 r06 soldier median 3.55 → 3.47 mm (one frame pose, −0.5 px): C1b FAIL, WORSE. Other rows SAME. The new game state shows U1 2/10 failing pairs with all cards dimmed (QA-B021 reopened), U4 1.41–2.0 and L6 missing marker in r01 (QA-B026 seen on capture). These are not caused by e8c6d96 |
