# QA checklist — 04-client scope (UI, input, mobile build)
Updated: 2026-10-31 08:10 +09:00. Status: TESTED = automated or observed with evidence listed; UNTESTED = not run; BLOCKED = cannot run yet.
Mock-based checks (MockEngine) prove UI wiring only. They are not evidence of combat, balance, fun or phone usability.

| # | Check | Status | Evidence |
|---|---|---|---|
| 1 | All src/ui scripts compile; all scenes/ui root scripts instantiable | TESTED | `tests/ui/test_ui.gd` compile gate (this gate was added after hud_top.gd broke silently at 06:58) |
| 2 | HUD layout: 10 logical view sizes (incl. integer-scale views 800×450, 666×400, 683×384) × 5 safe-area insets × 3 target sizes × 1–5 cards × 0–3 skills; no overlap; inside safe area; ≥40 logical | TESTED (math only) | 3000 configurations in test_ui.gd |
| 3 | Multi-touch: hold ◀ + tap card with 2nd finger; ▶ overrides ◀; slide-off release sends 0 | TESTED (synthetic touches via Viewport.push_input) | test_ui.gd hud_input |
| 4 | Emulated-mouse events ignored (no double fire); real mouse works | TESTED (synthetic) | test_ui.gd |
| 5 | Empty-battlefield touches reach gameplay `_unhandled_input` | TESTED (synthetic) | test_ui.gd |
| 6 | Real engine mounts 04 screens, not 02 fallback (menu, round select, HUD, result, HUD after retry) | TESTED headless | `tests/integration/test_ui_integration.gd` 27/27: asserts `App.ui_source` and root script paths |
| 7 | Real card tap deploys a unit and spends gold; holding ▶ moves the hero; pause freezes sim time; resume continues; win → result; retry restarts | TESTED headless (real BattleSim) | same integration test; the win is forced through `sim._damage_base` |
| 8 | App lifecycle: focus-out releases hero hold and requests pause | TESTED (notification injected) | test_ui.gd hud_pause |
| 9 | Android back: HUD pause toggle, settings close, menu quit-confirm | TESTED (notification injected) | test_ui.gd; 02 App defers back handling to 04 scenes |
| 10 | Korean text fits narrowest slots at grid sizes (12/24/36) with no ellipsis; en expansion | TESTED (font metrics, bundled fonts) | ko 0 ellipsis; en 2 ellipsis left in the worst case only (open, 01); docs/qa/TYPOGRAPHY_QA.md §3 |
| 11 | Bundled Galmuri fonts with no OS fallback; full glyph coverage; stable numerals | TESTED | 230/230 ko chars in Regular+Bold; allow_system_fallback=false asserted; fixed digit cells asserted (8b24e59, 0333cd3) |
| 12 | Visible run of the real game on the SECONDARY monitor only | TESTED on this PC | `tools/build/visible_launch.ps1`; evidence `build/qa/visible/launch_20261031_071349.json` (DISPLAY2, first-seen rect -1608,299, topmost) + OS screen capture `screen_20261031_071349_008s.png` |
| 13 | Screenshots of every UI screen at 16:9, 18:9, 20:9 notch, 21:9 both insets, 16:10, 4:3 | TESTED (mock data, desktop render, all on DISPLAY2) | `tools/build/capture_ui.ps1` now routes through visible_launch.ps1 → build/qa/screens/*.png + launch_*.json |
| 14 | Android debug APK builds, installs, starts | UNTESTED by 04 | 02 built build/android/defence-debug.apk at 07:07 (08: 55.3 MiB, arm64+x86_64). 04 has no install/start evidence of its own; 02 is testing its own AVD, so 04 did not start another emulator |
| 15 | Touch on a real phone (finger size, notch, gesture bar, Android system font) | BLOCKED | no device attached (`adb devices` empty) |
| 16 | Frame pacing, memory, battery, thermals on device | BLOCKED | needs a device; methodology owned by 08 |
| 17 | Tutorial banners, boss HP bar, upgrade screen, star reasons, OFL credits | NOT IMPLEMENTED | engine now provides `Events.tutorial_step(key)`, `HudSnapshot.boss {alive,hp,hp_max,id,name_key}`, `BattleResult.player_base_ratio`; UI does not consume them yet |
| 18 | Purchase/ads/consent UI | N/A | monetization not decided (01 D9); no purchase UI by design |

## Observations from the real-game visible run (07:13, r01)
- The HUD renders over 03 art; resource icons and the worker/infantry card icons come from `ui_main`. Korean renders correctly on Windows.
- r01 has 1 card and 0 skills, so the bottom-right area is empty. This is expected from data.
- Two thin vertical white lines appear in the sky/field. 03 reproduced them and sent the cause to 02 (rounding seam, commit 22cd2bb). Still visible in the 08:00 captures.
