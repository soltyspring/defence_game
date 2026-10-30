# 07-qa → 02-engine
Status: QUEUED (file request). Date: 2026-10-31. Evidence run: build/qa07/20261031-072353 (summary docs/verification/runs/20261031-072353.md). Rerun: `.\tools\qa\run_acceptance.ps1 -Only save,flow`.

## QA-B003 (P2) Save migration keeps wrong-typed fields → record_result script error
Steps: write `user://<any>.json` = valid envelope (checksum ok) with payload
`{"version":1,"unlocked_round":"abc","coins":-50,"stars":[3,2],"best_time":null,"settings":"loud"}`; `load_progress()`; then `record_result({"round_id":"r01","won":true,"stars":2,"time":80,"coins":5},0)`.
Expected: stars/best_time/settings become Dictionaries, coins ≥ 0, unlocked ≥ 1; the win is saved.
Actual: stars stays Array, best_time stays null → `progress.stars.get` / `best_time.get` script error, result not saved.
Fix suggestion: `_migrate` replaces any key whose type differs from `fresh()`. Acceptance: SAVE-05 and SAVE-06 PASS.

## QA-B001 / QA-B002 (cc; primary owner 04) — see 07-qa-to-04-client.md
B001: back press handled again by the screen mounted during the same `Window::_propagate_window_notification` walk (App.show_screen mounts synchronously). An App-level fix (defer navigation started from a notification, or a per-frame back latch) would also close it.
B002: `App._show_result` sets `battle.sim.paused = true`; snapshots keep `paused=true`, HUD re-shows its pause overlay under the result.

## QA-R1 Test hooks (so acceptance does not depend on internals)
Today the flow suite completes battles by stepping `App.battle.sim` directly. Please add (additive, documented in INTERFACES.md):
1. `--qa-seed=N` (or `App.qa_seed`) so non-autoplay battles use a reproducible seed.
2. Either document `App.battle.sim` as read-only QA access, or add `App.qa_fast_forward(seconds: float, policy: int)` that steps the current battle with `bot_player` (0 idle, 2 competent) and returns the sim time reached.

## QA-R2 Shared Godot import/export lock
To avoid 07/08 runs colliding with imports: hold an exclusive handle on `build/.godot-import.lock` while running `--import`, `-e` or `--export-*`. `tools/qa/run_acceptance.ps1` already waits on that file and on visible import/export processes for this project.

## QA-R3 Autoload wiring (already requested by 05/06)
AUD-02 (`Audio` autoload) and MON-04 (`Services`) report NOT_IMPLEMENTED until registered. When they are, tell 07 and I will add playback/disabled-state checks.
