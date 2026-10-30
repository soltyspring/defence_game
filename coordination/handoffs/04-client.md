# 04-client handoff
Updated: 2026-10-31 08:12 +09:00. Session: sess_a24d01e7-e535-413c-9ff6-d5258090820b (same window, resumed under the new account). Quota usage.json 0.11% (08:05).
triggered.json shows a 0% reading at 07:44. This looks like a stale marker from the account change; I did not remove it. Coordinator, please confirm.

## Read receipts / processed IDs
coordinator-to-04-client (R3–R5, C04, C06, completion gate, window stability, quota checkpoints), QUOTA_POLICY.md, QUALITY_REVIEW.md, gongmojeon SKILL.md (read; reject→fix→retest applied below), docs/art/TYPOGRAPHY.md, 03-art-to-04-client A1/A2, 03-art-to-02 A2/A3, 06/08 requests to 04, DECISIONS.md (Q1 theme still PENDING; all D* are DEFAULT, not user approvals).

## Commits this session (Publish-Task.ps1, all PUSHED origin/main)
- 8b24e59 [Feat] bundled Galmuri fonts (no OS fallback, pixel flags forced), 12/24/36 + 10/20 grid sizes only, fixed-cell numerals, typography gate
- 0333cd3 [Fix] grid-safe label fit for English (Latin falls to Galmuri9 10; ellipsis 15 → 2), real-scene shots in the integration test (`--shot-dir/--tag/--tile/--locale`), `visible_launch.ps1 -Script` + `--log-file`, capture_ui.ps1 routed through the secondary-monitor launcher
- (this commit) [Docs] TYPOGRAPHY_QA.md rewrite, QA_CHECKLIST update, requests 02 R9/R10 and 01 R3, this handoff
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

## Next task (exact): tutorial / boss / result-star UI gap
The engine already provides these, and the UI does not consume them yet:
1. `Events.tutorial_step(key)`: a non-blocking banner under the top bar using text `<key>` from data/text (e.g. tut_move_hero). "" hides it. 01 R1 says never pause after step 2.
2. `HudSnapshot.boss {alive, hp, hp_max, name_key}`: a boss HP bar with its name under the base bars while the boss is alive, plus the existing boss_incoming banner.
3. Result star reasons: ★1 승리, ★2 기지 체력 ≥ stars.base_hp_2 (from `player_base_ratio`), ★3 시간 ≤ stars.time_3 (round data via Content.get_round). Show each condition as met or unmet.
4. Skill names are hidden on 48 px skill buttons. Show the name on press or in the tutorial instead.
5. A credits panel with the OFL font credit.
Then: integer-scale retest after 02 R9; upgrade screen (P1, data/meta.json).
