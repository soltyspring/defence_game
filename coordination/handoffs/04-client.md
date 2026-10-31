# 04-client handoff
Updated: 2026-10-31 08:12 +09:00. Session: sess_a24d01e7-e535-413c-9ff6-d5258090820b (same window, resumed under the new account). Quota usage.json 0.11% (08:05).
triggered.json shows a 0% reading at 07:44. This looks like a stale marker from the account change; I did not remove it. Coordinator, please confirm.

## Read receipts / processed IDs
coordinator-to-04-client (R3–R5, C04, C06, completion gate, window stability, quota checkpoints), QUOTA_POLICY.md, QUALITY_REVIEW.md, gongmojeon SKILL.md (read; reject→fix→retest applied below), docs/art/TYPOGRAPHY.md, 03-art-to-04-client A1/A2, 03-art-to-02 A2/A3, 06/08 requests to 04, DECISIONS.md (Q1 theme still PENDING; all D* are DEFAULT, not user approvals).

## Commits this session (Publish-Task.ps1, all PUSHED origin/main)
- 8b24e59 [Feat] bundled Galmuri fonts (no OS fallback, pixel flags forced), 12/24/36 + 10/20 grid sizes only, fixed-cell numerals, typography gate
- 0333cd3 [Fix] grid-safe label fit for English (Latin falls to Galmuri9 10; ellipsis 15 → 2), real-scene shots in the integration test (`--shot-dir/--tag/--tile/--locale`), `visible_launch.ps1 -Script` + `--log-file`, capture_ui.ps1 routed through the secondary-monitor launcher
- c1bf13d [Docs] TYPOGRAPHY_QA.md rewrite, QA_CHECKLIST update, requests 02 R9/R10 and 01 R3, handoff
- 183e4a6 [Feat] tutorial hint (Events.tutorial_step), boss HP bar (HudSnapshot.boss), result star-condition rows with real round thresholds, feedback strips kept clear of the stacked skill column, stale-atlas-import guard (vector fallbacks)
- (this commit) [Docs] handoff/status + request 03 R4
Earlier: e62fe86, e4aa059, d7651af, 0b987c9, 8915190, 225abc6.

## Validation actually run
- tests/ui/test_ui.gd headless: 3223 pass / 0 fail. The layout matrix covers 3000 configurations, including the integer-scale views 800×450, 666×400 and 683×384. Fonts are bundled: res://assets/fonts/Galmuri11.ttf, Galmuri11-Bold.ttf and Galmuri9.ttf. 230/230 ko chars are present in Regular and Bold. allow_system_fallback=false and the pixel flags are asserted. Digit cells are fixed.
- tests/integration/test_ui_integration.gd headless: 27/27 with the real App/BattleSim.
- Visible runs of the same integration script on DISPLAY2 (secondary): ko r01 1280×720 27/27; ko r06 1600×720 pass; en r06 1280×800 26/26 (the tile run skips the fresh-save check); ko r06 1600×900 pass. The shot logs record `ui_roots` = src/ui scripts only. Images are in build/qa/real/.
- Mock screens at 6 shapes were re-captured through the launcher; all 6 windows were verified on DISPLAY2 (build/qa/screens/launch_*.json).
- Pixel regularity: at 2×, 0% odd-width glyph runs. At 2.5×, 82% odd-width runs, which is a defect (see below).

## Reject → fix → retest (gongmojeon applied)
1. Rejected: Hangul came from the OS fallback, and sizes 9/18/28 were off-grid. Fix: 8b24e59. Retest: 0 missing glyphs, the bundled-source assert passes, and the 2× renders are regular.
2. Rejected: 15 English labels were ellipsized ("Footman" → "Foo…"). Fix: fit_label steps down to Galmuri9 10 on its grid. Retest: 2 remain, only in the worst layout (sent to 01 R3).
3. Rejected: the visible run failed "fresh save: r01 open". Cause: my harness set unlocked_round=99 even with --tile=0. This was a test bug, not a game bug. Fix + retest: 27/27.
4. Rejected: text is irregular at 2.5×. 04 cannot fix this inside the UI. It needs integer scale_mode (02 R9, also 03 A2c). Open.

## Open defects / limits
- P1: 2.5× (non-integer) devices render uneven pixel text and sprites until 02 sets `scale_mode="integer"`.
- en "Footman"/"Catapult" ellipsized in the worst layout (01).
- No Android device or emulator evidence from 04. 02's APK (07:07) was not installed by 04, and I did not start a second AVD because 02 uses its own.
- OFL credits not shown in-game yet (keys requested from 01; export include of the licence requested from 02).
- White vertical lines in the biome are still visible; 02 is fixing the seam (22cd2bb, from 03).

## Tutorial / boss / result-star milestone (183e4a6) — validation
- tests/ui/test_ui.gd: 3232 pass / 0 fail. New checks: tutorial hint shown/hidden; boss bar drawn only while the boss is alive; star reasons win✓/base✓/time✗ with thresholds 50/120 and no mismatch; loss shows none met. Layout matrix (3000 configurations) now also checks that the boss/tutorial/toast/banner strips avoid every touch target and stay inside the safe area. The first run caught 7 layouts where the banner overlapped a stacked skill column, and a missing "≥" glyph in Galmuri; both were fixed and the same tests rerun to 0 failures.
- tests/integration (real App/BattleSim): 29/29. The real r01 tutorial hint was shown ("◀ ▶ 버튼을 누르고 있으면…"). Star reasons from the real r01 thresholds (base 50%, 150 s) match the engine stars (3/3).
- Visible on DISPLAY2: build/qa/screens/guard_20x9_{3_hud,5_result_win}.png (mock data: boss bar, tutorial, toast, star rows); build/qa/real/ko_16x9_r01_v2_*.png (real engine).
- Defect found in the visual check, and not 04's: 03's uncommitted ui_main re-pack combined with a stale import showed wrong icons. 04 added detection and fallback, and sent 03 R4. Icon screens must be re-captured after the re-import.
- Not verified: a real boss round (r05) end-to-end with the bar (only mock and unit data were used); whether the hint disappearing in the mid-battle real shot is correct engine step timing or a gap (the integration check only confirms that the first hint appears).

## 08:40 resume (new Kiro login; 08:21–08:22 requests had failed with authExpiryRetry)
- The owned working tree was clean (no lost edits). The `tests/performance/*` changes in the tree belong to 08 and were not touched.
- The HISTORICAL QUOTA CHECKPOINT notices are from the previous account and were ignored as instructed. Usage was 4.35% at 08:37.
- Dependencies are still missing at HEAD e9dfaa4: no `scale_mode` in project.godot (02 R9); ui_main import stale (png f16e31cf… vs import source_md5 224f322f…; 03 committed in c49de70, so 02 must re-import → 02 R11); en "Footman"/"Catapult" unchanged (01 R4 with measured proposals Spear 37 px / Siege 36 px at 12 px).
- Done: `UiStyle.import_is_fresh(png)` is now a pure, tested check. test_atlas_import_guard verifies stale → icons off, matching md5 → icons back (no permanent masking), PNG changed → off, no md5/export → on. It also checks that ui_main.json size matches the source PNG and that 14 UI frames have pixels. UI suite: 3252/0. Source-PNG contact sheet: build/qa/ui_main_source_frames_3x.png, with correct icons.
- 01 delivered 67bf9ca (Troop/Siege + credits/star keys), so I re-captured the worst layout on DISPLAY2 at 08:42 (build/qa/real2/): en has 0 ellipsis; 2× text is regular; 2.5× is still irregular (57–68% odd runs, needs 02 R9).
- Defect found in that capture: BattleInfo card icons went through `icon_texture` without the stale guard, so they showed wrong art. Fix: the guard now lives inside `icon_texture`, plus a regression check. The same capture was retested (`*_v2`) and shows consistent glyphs. Test suite 3253/0, integration 27/27 ×6 visible runs.
- New finding sent to 02 (R11 addendum): char_player_adv/char_enemy_adv are not imported (load errors in every run).
## 09:00 milestone 5ba49a4 (09 findings + boss/credits/skill names)
- Base HP numbers ("hp/max", fixed-cell Galmuri9 10, inside each bar at the outer end, clear of VS). Result and round-tile star markers: met = filled, unmet = hollow outline, so the shape differs (greyscale crop checked). Credits view in settings: Galmuri11 12 only, word-wrapped, with © and Hangul. Skill-name tooltip while the finger is down, clamped to the safe area. The same sentence from a toast and the tutorial hint is now shown once. Settings title is no longer clipped by the panel border (found in the visible credits frame, fixed, retested).
- X3 confirmed as my own test artefact. The capture order was fixed, and a real-play check now shows no toast without input.
- Validation: UI suite 3275/0; integration 31/31 headless; visible DISPLAY2 r05 (`--tile=4 --boss=boss_warlord --safe=34,0,34,0`) ko and en at 2× both 31/31. Frames: build/qa/real3/{ko,en}_r05_v3_*.png, mock_mixed_2x_5_result_win.png, stars_greyscale_2x.png.
- Open: 2.5× irregular pixels (02 R9); ui_main, adv and boss atlases not imported (02 R11 + addenda), so icons are vector fallbacks and the boss has no sprite; 1× capture of the HP numbers not taken.
## 09:10 milestone: 1× capture + HEAD APK audit + release checklist
- 1× (640×360 window on DISPLAY2, worst notch layout, real r05 + boss): base HP numbers "1700/1800" / "1800/1800" legible and inside their bars; integration 31/31 ko and en. Files: build/qa/real4/{ko,en}_1x_*.png, zoom_*_bases.png.
- APK: new `tools/build/build_android_debug.ps1` + `tools/build/inspect_apk.py` (isolated git-archive export, no shared cache/AVD use). HEAD 07e97ca: 59,106,028 B, no permissions, min 24 / target 36, debug v2+v3 signature, no raw sources, 10/10 atlases, 0 repo secrets. Open: the OFL text is not shipped; mock/diag code is shipped (debug); install not tested (slot requested from 02, R12).
- docs/qa/RELEASE_READINESS.md created (sections A–D, tested/untested/blocked).
## Next task (exact)
1. After 02 re-imports (R11) and/or sets integer scale (R9): re-capture real scenes on DISPLAY2 under the same conditions (worst layout 640 + notches + 5 cards/3 skills, ko/en, 1280×720 and 1600×900). Confirm the stale warning is gone, there are 0% odd glyph runs at 1600×900, and Footman/Catapult are fixed if 01 accepts R4.
2. Real r05 boss run (`--round=r05` or the integration `--tile=4`) on the secondary monitor: boss bar visible with real data.
3. Credits panel (OFL font credit; keys requested from 01 R3; fallbacks exist: ui.credits / ui.font_credit).
4. Skill names are hidden on 48 px skill buttons: show the name in the toast on press, or in a long-press tooltip.
5. Integer-scale retest after 02 R9; upgrade screen (P1, data/meta.json).

## (superseded) previous next-task list
The engine already provides these, and the UI does not consume them yet:
1. `Events.tutorial_step(key)`: a non-blocking banner under the top bar using text `<key>` from data/text (e.g. tut_move_hero). "" hides it. 01 R1 says never pause after step 2.
2. `HudSnapshot.boss {alive, hp, hp_max, name_key}`: a boss HP bar with its name under the base bars while the boss is alive, plus the existing boss_incoming banner.
3. Result star reasons: ★1 승리, ★2 기지 체력 ≥ stars.base_hp_2 (from `player_base_ratio`), ★3 시간 ≤ stars.time_3 (round data via Content.get_round). Show each condition as met or unmet.
4. Skill names are hidden on 48 px skill buttons. Show the name on press or in the tutorial instead.
5. A credits panel with the OFL font credit.
Then: integer-scale retest after 02 R9; upgrade screen (P1, data/meta.json).
