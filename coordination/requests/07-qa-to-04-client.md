# 07-qa → 04-client
Status: QUEUED (file request). Date: 2026-10-31. Evidence run: build/qa07/20261031-072353. Rerun: `.\tools\qa\run_acceptance.ps1 -Only flow` (~25 s).

## QA-B001 (P2) One Android back press is handled twice
Steps A: finish a round → result screen → one back press. Expected: round select. Actual: `screen_changed` = `["round_select","menu"]`, ends on main menu.
Steps B: round select → one back press. Expected: main menu, quit dialog closed. Actual: main menu with `quit_layer.visible = true`.
Mechanism: Godot 4.7.2 `Window::_propagate_window_notification` (scene/main/window.cpp at tag 4.7.2-stable) walks children by live index. `result.gd` / `round_select.gd` emit `cmd_open_screen` synchronously inside `_notification`; App appends the new screen, and the walk then delivers the same back press to it (main_menu toggles its quit dialog). The suite reproduces this with a GDScript copy of that function (`suite_flow.gd::_window_notify`); `propagate_notification` does not reproduce it.
Fix suggestion: defer navigation from back handlers (`emit_cmd.call_deferred(...)`) or consume back once per frame. Acceptance: FLOW-23 and FLOW-23B PASS. (02 cc'd; an App-side latch would also work.)

## QA-B002 (P3) HUD pause overlay visible under the result panel
Steps: win or lose → result shown. Expected `hud.pause_layer.visible == false`. Actual true.
Cause: `hud._on_snapshot` maps `snapshot.paused` (App sets `sim.paused = true` when showing the result) to `_on_paused(true)` after `_on_battle_ended` already hid the layer.
Fix suggestion: ignore snapshot pause state after `battle_ended` until the next `battle_started`. Acceptance: FLOW-13B PASS.

## QA-R4 Visible-test launcher (secondary monitor)
QUALITY_REVIEW.md assigns the reusable secondary-monitor launcher to 04. 07 needs it for rendered-text (Hangul tofu/clipping), small-phone legibility and colour-blind frame checks. Please publish the command/arguments (window rect, monitor selection, screenshot output dir) when ready. 07 will not open game windows on the main monitor.

## Update 2026-10-31 09:00 (HEAD e9dfaa4; triage docs/verification/FAILURE_TRIAGE.md)
- QA-B001 (FLOW-23/23B) and QA-B002 (FLOW-13B) still FAIL at HEAD e9dfaa4 (run 20261031-083824, re-run 085129). Rerun: `.\tools\qa\run_acceptance.ps1 -Head -Only flow`.
- QA-W003 (cc): committed result.gd uses `ui.star_*` keys that exist only in 01's uncommitted text; HEAD shows raw ids until 01 commits.
- Typography challenge (coordinator 08:12): your captures `build/qa/real3/*_r05_v3_*` are workspace WIP. Observations to confirm, not yet bugs: card buttons draw a dot glyph instead of unit icons; skill buttons show only ♦ + cost (no name/icon); "Archer/Shield/Raider" fill ~90 of ~98 capture px; red bar edge above the result panel.
- **QA-R5**: please add `-ProjectPath <dir>` to `tools/build/visible_launch.ps1` (default = workspace) so 07 can run the same secondary-monitor capture against the clean HEAD snapshot `%TEMP%\qa07_head`. Until then 07 cannot make HEAD-condition typography verdicts without competing with your visible runs.
