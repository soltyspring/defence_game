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
| G3 | "pixel art turned blurry" | 2x frames stay a ×2 copy of 1x except at most the baseline pixels above |

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
| U1 | "all cards look the same" | for every pair of card icons on screen: (mean-colour ΔE ≥ 10 normal and ≥ 8 deutan) or shape distance ≥ 12 | 0.6 / 5.0: **FAIL now** |
| U2 | "the HUD eats the battlefield" | HUD pixels % never more than baseline + 0.5 pp in any scene. A reduction target is 04/01's (layout), not 06's | 10.05–18.55 % |
| U3 | "the HUD covers my units" | HUD-covered unit pixels stay 0 % | 0: PASS |
| U4 | crisp UI | G3 | — |
| — | logo, menu and result "look good" | **NOT MEASURABLE** (human). Measurable part: menu and result frames render (G1), and the title fits (VISUAL_CHECKS C14) | — |

## 4. How owners compare (same set, no copies)
1. Commit the change. 07 judges only committed SHAs.
2. Inside the lock, refresh the snapshot of that commit, then capture one tag (ko_1x is enough while iterating; all four tags for a final claim):
```
& .\coordination\heavy_run.ps1 -Label '<role>-art-baseline' -Script {
  & .\tools\qa\run_acceptance.ps1 -Head -Only data
  & .\tools\build\visible_launch.ps1 -ProjectPath $env:TEMP\qa07_head -Script res://tests/acceptance/capture_art_baseline.gd -Resolution 800x360 -TimeoutSec 300 -EvidenceDir <abs dir> -UserArgs '--out=<abs dir>','--tag=ko_1x','--locale=ko','--safe=34,0,34,0','--target=44'
}
python tools/qa/art_metrics.py --dir <abs dir> --tags ko_1x
```
3. Compare `<dir>/art_metrics.json` scene by scene with `evidence/art-baseline-ad47eda/art_metrics.json`. A before/after claim that uses other frames or other conditions is not accepted by 07.

**Shared roots:** C3 (hero), C5 (boss) and W1/W2 depend on both 03 and 09. 07 rejects whichever change makes them worse. The rule passes only when the combined result passes.
