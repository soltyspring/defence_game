# Re-verification plan for after 18:30 KST (owner: 07-qa)
Written 2026-10-31 17:58–18:10 +09:00 during 08's quiet measurement window (18:00–18:30): **no Godot, editor or emulator was started for this document**; only `git show`/`git grep` and Python. Everything below marked *expected* is a prediction from code/data/03's Python composites, **not yet verified in the game**.
Note on location: the coordinator asked for `docs/qa`; that path is 04-owned (OWNERSHIP.md), so 07 keeps this plan in its own `docs/verification/`.

## Build under test
Clean `git archive` of origin/main HEAD at start time (≥ c6d0e9e), containing 03 11ceacb + e3c4621, 04 a6369ba + baa1672, 02 09508b1 + 4b5926d. Runner `.\tools\qa\run_acceptance.ps1 -Head` (import guard must report `import_missing_after_guard=0`), then captures through `tools/build/visible_launch.ps1 -ProjectPath %TEMP%\qa07_head` on `\\.\DISPLAY2` only. Every capture passes the brightness guard (mean ≥ 8/255) or is marked VOID (locked PC).

## Order (so a failure early does not waste the window)
1. `run_acceptance.ps1 -Head` full (≈ 60 s + import). Gate: FAIL 0 expected (last: 152/0 at 09508b1).
2. `capture_m8.gd` ko/en × 1×/2× × notch 34+34 (title, upgrades, HUD).
3. `capture_crowd.gd --autoplay --round=r08 --seconds=180` ko 2× (damage numbers, bars, nest).
4. `cvd_sim.gd` on the crowd peak and a t≈25 s frame; `tools/qa/frame_metrics.py` on r01 HUD frames.
5. `check_apk_label.ps1` only if 02/04 report a HEAD-built APK (QA-W004).

## Checklist with expected values
| # | Item | Commit(s) | How 07 measures | Expected (source) | Pass rule |
|---|---|---|---|---|---|
| V1 | Sky share of the battle frame | 03 11ceacb (Wheatfield Village, far layer view_y 100→50) | `frame_metrics.py --rev <HEAD> --band 0.12,0.83` on r01 t≈2 s ko 2× notch | Coordinator target ≈ 18 %; 03 `biome_check.py` reports **24.7 %** (line method, ≤ 35 %). 07 baseline with the OLD meadow: **39.5–46.1 % full frame, 47.5–55.8 % in band** (68866e9 / 97c8b9c captures, exact sky-palette method) | Report the number; PASS if ≤ 35 % (03's own line) and lower than the 07 baseline; the 18 % target is reported, not enforced, until 01/03 fix one metric |
| V2 | Village / mould identity | 03 11ceacb, e3c4621 | visual review of r01 and r08 frames | wheat field + bakery houses; enemy base = mould mound with cave mouth facing left, spore stalks (03 A32) | Both readable at 1× in a real frame; else re-open QA-J1 identity part |
| V3 | Nest readable at screen edge | 03 e3c4621 | r08 frame where only 24–40 px of the nest are on screen; CVD frames | 03 Python composite: contrast ΔE 30–33 vs village street, 99.6–99.8 % pixels distinct, protan ≥ 29 (docs/art/ART_AUDIT.md Round 10) | Nest edge visibly distinct from background in normal + protan/deutan frames |
| V4 | Damage numbers | 02 09508b1 (Galmuri9 10 px, merge, vertical stagger ≤ 6 steps) | `capture_crowd.gd` new fields `damage_number_overlaps`, `damage_numbers_max_drawn` (reads `battle_view._placed_text` each frame) + zoomed crop | **0 overlaps** by construction unless > 6 numbers stack at one spot; numbers above HP bars | `damage_number_overlaps == 0` over 180 s and no number on a bar in the zoom → QA-B012 VERIFIED |
| V5 | World HP bars under CVD | not changed (static read: `_hp_bar` still 2 px, `C_BAR_PLAYER` vs `C_BAR_ENEMY` only) | zoom of unit bars + enemy base bar in deutan frame | **still hue-only** (prediction from code) | QA-B013 stays PARTIAL unless bars differ by pattern/luminance |
| V6 | Title logo per language | 04 a6369ba (ui_title_ko/en pages), baa1672 | `capture_m8.gd` default + `--force-text-title` | ko logo / en logo on separate pages; text fallback = Q3 title, no "Lane Defence" fallback left (baa1672) | complete, inside 572 px safe width, ko/en, 1×/2× |
| V7 | Menu texture residency | 03/04 A10 (menu 0.375 MiB) | `Atlas.texture_report()` on menu and after entering battle (add to capture_m8 report) | menu holds only the current-language title page; released on battle entry | title page absent from `texture_report` in battle |
| V8 | Home-screen (launcher) name | 02 4b5926d (`package/name="Bakery Knights"`, `config/name_localized` ko/en) | `check_apk_label.ps1` on an APK built from a committed HEAD | ko "빵집 기사단", en "Bakery Knights" (Q4) | exit 0 on a HEAD-built APK → QA-W004 closed |
| V9 | Desktop window title | same | visible run: read HWND title via the launcher JSON / `DisplayServer.window_get_title()` | Godot uses `config/name_localized[locale]`: ko → "빵집 기사단", en → "Bakery Knights"; other locales fall back to `config/name` = **"Lane Defence"** | ko/en correct; the fallback is reported as an observation |
| V10 | Resource word | 01 a262640 (밀가루/Flour) | data scan + upgrade screen capture | `upgrade.supply_regen` still "보급 증가"/"Supply Boost" unless 01 changed it (QA-B018) | all resource mentions use one word |
| V11 | Save after "save_uncertain" restart | 02 4b5926d (`result.save_uncertain`) | PUR-C6 + TP suites already cover the codes; add a flow check that the result screen does not claim "saved" when `save_uncertain` | no success wording when uncertain | to be designed after reading the 04 result screen code |

## Risks to watch while testing (from static reading)
- **R-a (data safety, desktop)**: `config/name` is still "Lane Defence". On desktop, Godot's `user://` folder is derived from the project name (`app_userdata/Lane Defence`). If anyone renames `config/name`, existing desktop saves move out of reach unless `application/config/use_custom_user_dir` keeps the folder. Android uses the package id, so phones are not affected. 07 will report this to 02 before any rename, not file it as a bug.
- **R-b**: package id `com.soltyspring.lanedefence` cannot change after the first store upload (already flagged to 01/02).
- **R-c**: Python-only measurements (03's composites, 07's frame_metrics) are not game evidence until repeated on a real HEAD frame.

## Executed 2026-10-31 18:32–19:33 at HEAD fca9346 (results in VISUAL_CHECKS M12, BALANCE_CROSSCHECK last section)
V1 PASS (17.0 %) · V2/V3 PASS · V4 FAIL (QA-B012 reopened) · V5 PARTIAL (as predicted) · V6 PASS · V7 not measured (texture_report not added yet) · V8 WAITING (no SHA-named APK) · V9 not measured (window title read not added) · V10 still FAIL (QA-B018, data) · V11 not designed yet.
