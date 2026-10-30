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

## Update 2026-10-31 08:10 — new executed failures (evidence: build/qa07/head-462991a, clean HEAD snapshot; summary docs/verification/runs/head-462991a.md). Rerun: `.\tools\qa\run_acceptance.ps1 -Head -Only save,faults`
Still OPEN at HEAD 462991a: QA-B001, B002 (04), B003.

### QA-B004 (P1, data loss) backup rotation deletes the only good copy (= 10-research SV-1, now executed)
Steps: save twice (main=B, .bak=A) → overwrite main with `{ corrupted main` → `load_progress()` (recovers A, recovered=true) → `save_progress()`.
Expected: a valid backup remains. Actual: valid .bak removed, corrupt main renamed into .bak (TP-02a). Killing the process after the .bak rename and before the final rename (state rebuilt from real save output) → reload gives fresh progress, unlocked_round 1, recovered=false (TP-02b): all progress lost silently.
Fix direction: rotate main into .bak only if `_read(main)` succeeds; on load also accept a verified `.tmp` when main is missing. Acceptance: TP-02a, TP-02b PASS, TP-01 stays PASS.

### QA-B005 (P2) save failure is silent
Steps: make `<save>.tmp` unopenable (TP-14 creates a directory with that name) → `save_progress()`. Actual: returns false, previous file intact (good), no signal/toast. Request: emit `Events.toast("save_failed", {})` (04 renders; 01 adds text). Acceptance: TP-14b PASS.

### QA-B006 (P3) v99 save rewritten as v1 (TP-06). Request: if payload version > VERSION, load read-only and skip writes (or keep unknown fields and the higher version). Acceptance: TP-06 byte-identical.

### QA-B007 (P3) no clamp/size guard (TP-13a/c): unlocked_round 1e12, coins 9 999 999 999 and stars "x"/99 survive load; a 50 MB save is fully parsed (6.8 s desktop). Request: clamp unlocked to rounds+1, coins to meta cap, stars to int 0..3; reject files over a size limit (08 to set). Acceptance: TP-13a PASS.

### QA-W002 (workspace WIP, not filed as bug) — uncommitted `src/gameplay/battle_sim.gd` calls `_cue()` (lines ~620/627) which is not defined, so `battle.gd` fails to compile and no battle starts (workspace run 20261031-080624, FLOW-03). HEAD is fine. Please do not commit it in that state.
