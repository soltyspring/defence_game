# Acceptance report (generated)

{"BLOCKED":0,"FAIL":4,"NOT_IMPLEMENTED":0,"NOT_TESTED":0,"PASS":40}

| ID | Suite | Status | Check | Detail |
|---|---|---|---|---|
| FLOW-01 | flow | PASS | boot shows main menu from scenes/ui (not fallback) |  |
| FLOW-02 | flow | PASS | locked round r03 refused on fresh save (toast round_locked, stays on menu) |  |
| TOUCH-MENU | flow | PASS | main menu: 3 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| FLOW-03 | flow | PASS | tap Play (touch) -> battle r01 with HUD from scenes/ui |  |
| FLOW-04 | flow | PASS | hud_snapshot streams (~10 Hz) with all INTERFACES §1.3 keys |  |
| FLOW-04B | flow | FAIL | HUD shows localized text for every engine toast key (no raw ids) | raw key shown for: ["counterattack"] |
| TOUCH-HUD-R1 | flow | PASS | HUD r01: 5 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R1-16:9 | flow | PASS | HUD @ 16:9 (640.0, 360.0) safe [P: (0.0, 0.0), S: (640.0, 360.0)]: 5 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R1-19.5:9 | flow | PASS | HUD @ 19.5:9 notch both (780.0, 360.0) safe [P: (34.0, 0.0), S: (712.0, 360.0)]: 5 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R1-20:9 | flow | PASS | HUD @ 20:9 notch L + gesture bar (800.0, 360.0) safe [P: (40.0, 0.0), S: (760.0, 348.0)]: 5 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R1-21:9 | flow | PASS | HUD @ 21:9 cutout L (840.0, 360.0) safe [P: (48.0, 0.0), S: (792.0, 360.0)]: 5 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R1-4:3 | flow | PASS | HUD @ 4:3 tablet (640.0, 480.0) safe [P: (0.0, 0.0), S: (640.0, 480.0)]: 5 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| FLOW-05 | flow | PASS | tap card (touch) deploys a unit and spends gold |  |
| FLOW-06 | flow | PASS | tap worker button (touch) hires a worker |  |
| FLOW-07 | flow | PASS | multi-touch: holding ▶ moves hero while a 2nd finger deploys |  |
| FLOW-08 | flow | PASS | app background -> battle paused, pause overlay shown, progress saved |  |
| FLOW-09 | flow | PASS | while backgrounded the sim does not advance; held move is released (cmd_hero_move 0) |  |
| FLOW-10 | flow | PASS | app resume keeps battle paused until the player taps resume (ENGINE §7) |  |
| FLOW-11 | flow | PASS | tap Resume -> sim runs again with no ghost hero movement |  |
| FLOW-12 | flow | PASS | Android back in battle opens pause (single toggle) |  |
| FLOW-13 | flow | PASS | win r01 -> result screen (scenes/ui) + one battle_ended with won=true, stars, next_round_id |  |
| FLOW-14 | flow | PASS | win persisted to disk: stars + unlocked_round >= 2 + coins |  |
| FLOW-13B | flow | FAIL | result screen: HUD pause menu is not shown underneath the result panel | hud.pause_layer.visible=true under result (App._show_result sets sim.paused=true directly; HUD maps snapshot.paused=true to its pause overlay) |
| TOUCH-RESULT | flow | PASS | result screen: 3 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| FLOW-15 | flow | PASS | retry -> fresh battle of same round (old battle freed, single UI root, t~0, start gold) |  |
| FLOW-16 | flow | PASS | after retry one deploy command spawns exactly one unit (no duplicate handlers) |  |
| FLOW-17 | flow | PASS | loss -> result won=false, no next button, saved stars/unlock not reduced |  |
| FLOW-18 | flow | PASS | result menu button -> round select (battle torn down) |  |
| TOUCH-ROUNDSEL | flow | PASS | round select: 11 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| FLOW-19 | flow | PASS | tap unlocked r02 tile -> battle r02 |  |
| TOUCH-HUD-R2 | flow | PASS | HUD r02: 7 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| FLOW-20 | flow | PASS | win r02 -> Next button visible |  |
| FLOW-21 | flow | PASS | Next -> battle r03 |  |
| TOUCH-HUD-R3 | flow | PASS | HUD r03: 8 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R3-16:9 | flow | PASS | HUD @ 16:9 (640.0, 360.0) safe [P: (0.0, 0.0), S: (640.0, 360.0)]: 8 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R3-19.5:9 | flow | PASS | HUD @ 19.5:9 notch both (780.0, 360.0) safe [P: (34.0, 0.0), S: (712.0, 360.0)]: 8 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R3-20:9 | flow | PASS | HUD @ 20:9 notch L + gesture bar (800.0, 360.0) safe [P: (40.0, 0.0), S: (760.0, 348.0)]: 8 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R3-21:9 | flow | PASS | HUD @ 21:9 cutout L (840.0, 360.0) safe [P: (48.0, 0.0), S: (792.0, 360.0)]: 8 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| SAFE-R3-4:3 | flow | PASS | HUD @ 4:3 tablet (640.0, 480.0) safe [P: (0.0, 0.0), S: (640.0, 480.0)]: 8 visible touch targets >= 40 logical px, inside safe area, non-overlapping |  |
| FLOW-22 | flow | PASS | win r03 (first 3 rounds cleared through real UI; forced_win=false) -> unlocked_round >= 4 |  |
| FLOW-23 | flow | FAIL | Android back on result navigates exactly once and the target screen is actually mounted | screen_changed sequence=["round_select", "menu"] App.screen=menu top mounted UI=main_menu.gd |
| FLOW-23B | flow | FAIL | Android back on round select -> menu once, without also opening the menu's quit dialog | nav=["menu"] menu=true quit_dialog_visible=true |
| FLOW-24 | flow | PASS | corrupt save at launch -> restored from .bak, recovered flagged, menu shows recovery notice |  |
| FLOW-25 | flow | PASS | Android back on main menu shows quit confirmation instead of quitting immediately |  |
