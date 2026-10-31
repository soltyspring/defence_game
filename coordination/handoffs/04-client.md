# 04-client handoff — FINAL CHECKPOINT (user-requested shutdown)
Updated: 2026-10-31 15:50 +09:00
Session: sess_a24d01e7-e535-413c-9ff6-d5258090820b (Kiro CLI, claude-opus-5.5, trust-all; same window throughout, resumed after two account changes).
State at checkpoint: work stopped at a safe point. The owned working tree is CLEAN (all 04 work committed and pushed). No 04-started Godot or emulator process is running. Nothing was left unverified or uncommitted.

## User decisions known to 04
- Theme: user chose A "빵집 기사단 vs 곰팡이 군단" (relayed by the coordinator 09:15). At the checkpoint, 01 had not yet recorded it (DECISIONS Q1 still PENDING) and data/text was unchanged. All other D* entries are DEFAULTS. No monetization decision; no ad/IAP UI by design.

## Delivered (all pushed to origin/main)
| SHA | What |
|---|---|
| e62fe86 | Mobile UI: main menu, round select, battle HUD, result, settings, multi-touch TouchButton, safe-area layout, mock adapter + preview |
| e4aa059, 8b24e59, 0333cd3 | Bundled Galmuri fonts (no OS fallback, pixel flags), 12/24/36 + 10/20 grid sizes, fixed-cell numerals, grid-safe English label fit |
| 183e4a6, 3fd301f, 22bdd9e | Tutorial hint (Events.tutorial_step), boss HP bar, result star-condition rows, stale-atlas-import guard (tested recovery; covers engine-supplied icons) |
| 5ba49a4 | Base HP "hp/max" numbers, star met/unmet by shape (filled/hollow), credits panel (OFL font credit), skill-name press tooltip, duplicate boss message fix, settings title clip fix |
| 70b7409 | 07 QA-B001 (one back press handled once: claim_back + deferred navigation), QA-B002 (no HUD pause menu under the result), visible_launch `-ProjectPath` (07 QA-R5) |
| 0d8cc5b | FLOW-04B: `toast.counterattack` ko/en; unknown engine toast keys are never shown raw |
| d7651af, 0b987c9, 997d0a4 | Tests/tools: tests/ui/test_ui.gd, tests/integration/test_ui_integration.gd (real engine; `--shot-dir/--tag/--tile/--locale/--safe/--boss`), tools/build/{common,run_tests,capture_ui,visible_launch,build_android_debug}.ps1, inspect_apk.py |
| 8915190 … 5426645 | Docs/requests: docs/qa/{QA_CHECKLIST,TYPOGRAPHY_QA,RELEASE_READINESS}.md, docs/mobile/BUILD_PLAN.md, requests to 01/02/03/07/09/coordinator |

## Actual validation (latest runs)
- tests/ui/test_ui.gd (headless): 3284 pass / 0 fail. Covers 3000 layout configurations, typography (230+ ko chars, 0 missing, 0 ko/en ellipsis), atlas guard, back-once/pause-after-end regressions.
- tests/integration/test_ui_integration.gd (real App/BattleSim): 31/31 headless; also 31/31 in visible DISPLAY2 runs (ko/en, 1×/2×, r05 boss).
- 07 acceptance `--only=flow` on a clean `git archive` of HEAD 0d8cc5b (own import): PASS=44 FAIL=0 (build/qa/flow_head_0d8cc5b). 07's own `-Head` rerun is not yet confirmed: their run lock was held by their job.
- Debug APK from an isolated HEAD copy (07e97ca): 59,106,028 B; no permissions; minSdk 24 / target 36; v2+v3 debug signature; 0 raw PNG/TTF/WAV; 10/10 atlas .ctex; 0 keys/passwords in the repo (build/qa/apk_head/).
- Evidence images are in git-ignored build/qa/{real,real2,real3,real4,real5,screens}.

## 15:50 resume (after the 09:25 checkpoint)
- Loss check: checkpoint/quota-20261031-092323/04-client has 0 file differences from origin/main in 04 paths; e02ba03 is in main; the owned tree was clean. Nothing lost.
- Theme A text (01 14b01e2) is in use: cards are 제빵사/식빵병/롤빵병/통식빵/프레첼 (Baker/Toast/Roll/Loaf/Twist). ui.title stays provisional per 01.
- 5a2099d: fit_label cold-font bug (root cause of 07 QA-B009) fixed; round tiles wrap to 2 lines (QA-B010); `UiStyle.prewarm_fonts()` added (08 R5).
- 231cfda: the `--safe=` harness option now uses live insets (an integer-scale 800×450 view had exposed a stale fixed rect).
- 38b4d9d: tiles prefer a 12 px 2-line wrap over the 10 px cut. **This pushed a test file with a parse error** (I published without gating on the test result). Fixed in ad9b6fd. The HEAD snapshot then gave UI 3297/0 and integration 32/32.
- Verified on DISPLAY2 against fresh HEAD snapshots (own import, so icons are correct): 1600×900 → 800×450 view, 0.0% irregular glyph runs at 1×/2×/2.5×, ko/en (build/qa/real6, real7). 07 theme+flow on HEAD: TH-FIT-HUD ko/en PASS; TH-FIT-ROUND fails only because 07 measures 1 line (asked 07 to use fit_lines); TH-COL = 03.
- The shared tree currently has 02's uncommitted src/core/app.gd WIP (breaks App.boot), so run integration on HEAD snapshots until 02 commits.
## Unfinished / open (not done, do not claim)
1. Theme-A labels: waiting for 01 to commit data/text. Then: run test_ui (typography gate) + worst-layout ko/en visible captures.
2. 2.5× (non-integer) pixel text irregular (57–68% odd runs): waiting for 02 `scale_mode="integer"` (04 R9).
3. Shared dev-tree import stale (ui_main, char_*_adv, char_boss_*): waiting for 02 `--import` (R11). Fresh snapshots render correctly.
4. OFL licence text not in the APK; release preset should exclude mock/diag code and ship arm64 only (R12).
5. APK not installed by 04 on any emulator (02 owns LaneDefence_Phone; slot requested in R12). No physical device; no release key/AAB (user actions).
6. Not implemented: upgrade screen (P1), 2× speed UI, flash-limit/hold-toggle settings.

## Exact next steps on resume
1. Read coordinator-to-04-client.md, DECISIONS.md, 02-engine-to-04-client.md (R9/R11/R12 replies), 01-director-to-04-client.md (theme labels).
2. If 01 committed theme text: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/ui/test_ui.gd` (expect 0 ko/en ellipsis). Then on DISPLAY2: `.\tools\build\visible_launch.ps1 -Script res://tests/integration/test_ui_integration.gd -Resolution 1280x720 -UserArgs '--shot-dir=<abs>','--tag=themeA_ko','--tile=4','--boss=boss_warlord','--locale=ko','--safe=34,0,34,0'` (repeat with en, and at 640x360).
3. If 02 set integer scale / re-imported: the same command at `-Resolution 1600x900` → expect an 800×450 view and 0% odd glyph runs; check icons in the shared tree (no `[UiStyle] … stale` warning in godot_*.log).
4. If 02 gives an install slot: `.\tools\build\build_android_debug.ps1`, then install/start/screencap on their AVD only in the agreed slot; record the result in docs/qa/RELEASE_READINESS.md A13.
5. Commit only verified owned files with coordination/Publish-Task.ps1 (no stderr redirection).
