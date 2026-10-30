# 04-client handoff
Updated: 2026-10-31 07:22 +09:00 (resumed once after the rate-limit cooldown as instructed; no retry loop)

## Read receipts / processed IDs
BRIEF.md, OWNERSHIP.md (8-worker expansion: tests/acceptance, tests/performance, tests/services are no longer mine; 06 owns ad/IAP adapters in src/services), GIT_WORKFLOW.md, QUALITY_REVIEW.md, WINDOW_STABILITY.md, QUOTA_POLICY.md, coordinator-to-04-client R3/R4/R5/C04/C06, 02-engine-to-04-client R1+R2, 01-director-to-04-client R1+R2, DECISIONS.md D1–D10 (Q1 theme still PENDING), ENGINE.md/INTERFACES.md v1.0, assets/manifest.json + ui_main.json.
gongmojeon SKILL.md (outside the workspace) not read yet; the hostile-review method was applied below in spirit only.

## Commits (all via Publish-Task.ps1, all PUSHED to origin/main)
- e62fe86 [Feat] menu/round select/HUD/result + multi-touch input (39 files)
- e4aa059 [Fix] hud_top.gd parse error (from my own bad batch edit), ui_main atlas icons, Korean text auto-fit, locale auto-detect, engine toast key fallback
- d7651af [Test] compile gate + Korean typography fit test + real-engine UI integration test
- 0b987c9 [Chore] tools/build: common.ps1, run_tests.ps1, capture_ui.ps1, visible_launch.ps1
- docs/mobile, docs/qa, coordination files: see the next commit after 0b987c9 (SHA recorded in git log; "[Docs] ..." by 04-client)

## Delivered and how it was validated
| Item | Evidence | Type of evidence |
|---|---|---|
| 04 screens compile and mount in the REAL engine (not fallback) | integration test 27/27: App.ui_source == scenes/ui for menu, round_select, hud, result, hud-after-retry; root script paths asserted | headless, real App/BattleSim |
| Real card deploy, hero hold-move, pause freezes sim time, resume, win → result, retry | same test (deployed 0→1, gold 62→32, hero x 70→127, t frozen at 1.45) | headless, synthetic touches through Viewport GUI |
| Layout/safe-area/touch-target math | 2100 configurations, test_ui.gd | math only, not a phone |
| Multi-touch, emulated-mouse dedupe, battlefield pass-through, lifecycle/back | test_ui.gd | synthetic events |
| Korean text fits narrowest slots | typography_report.json, test_ui.gd | font metrics on Windows fallback font |
| Visible real game on the secondary monitor only | build/qa/visible/launch_20261031_071349.json: DISPLAY2, first-seen rect -1608,299, verified with MonitorFromWindow, topmost; OS capture screen_20261031_071349_008s.png shows the real r01 HUD over 03 art | real desktop render |
| Data text keys integrated | all 49 ui./toast. keys now come from data/text (01); FALLBACK_KO only covers gaps | test_ui.gd key check |

## Strongest rejection reasons (still open)
1. P1: no bundled Korean font. 127/131 UI chars rely on OS fallback; Android rendering is unknown (requested from 03 R1).
2. P1: no APK built yet, so there is no Android evidence of any kind (startup, touch, safe area, font).
3. No physical-phone check of finger size, legibility at 8–12 logical px, notch, or gesture bar. All touch tests are synthetic.
4. Tutorial banners, boss HP bar, star-reason display and the upgrade screen are not implemented, although 02 now exposes the fields.
5. The earlier mock suite passed while hud.gd failed to compile, because Godot skips code after script errors. This is fixed with the compile gate and section-completion checks, and the same scenario was retested: the gate passes now that the scripts compile.
6. Visual: two white vertical lines in the r01 sky (reported to 02/03). Gold digits are proportional (the readout shifts as numbers change).

## Next tasks (04, in order)
1. Android debug APK: tools/build/build_android_debug.ps1 → export, apksigner verify, aapt2 badging; then a workspace-local AVD (x86_64 android-36) on the secondary monitor: install, start, logcat, screencap. Record exact blockers if anything fails.
2. Tutorial banner and boss HP bar from HudSnapshot.boss / BattleInfo.tutorial; star reasons on the result screen.
3. Switch to the bundled font when 03 delivers it, then re-run the typography and visible captures.
4. Data validation test (01 R2.1) in tests/data/.
5. Release pipeline doc + script skeleton (signing via env vars), privacy/data-disclosure notes (06 owns adapters).

## Dependencies
02: main/App (OK). 03: font (pending). 01: Q1 theme (pending; text keys are already data-driven). Device: none attached.
