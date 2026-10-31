# Game Save ↔ Services integration contract (owner: 06-services)
Version: 2 (2026-10-31). Status: **INTEGRATED (desktop headless evidence).** 02 registered `Services="*res://src/services/services.gd"` after `Save=` in project.godot (commit 141d226, 2026-10-31 09:18). Re-run 2026-10-31 ~15:45 KST: `test_services_integration.gd` exit 0, `verdict=PASS_INTEGRATED`, `binding=game`, I1–I4 PASS, I5 NOT_REQUIRED_YET, I6 PASS; every R/P row `binding=game`, `game_evidence=true`. Still not covered: Android device process death/storage, real SDK/store (mocks only), game grant sinks (S3, not needed while disabled).

Monetization stays undecided (D9 DEFAULT). This contract does not enable real ads, billing, consent SDKs or analytics; services run in `disabled` mode after integration too.

## 1. What 02 must do (02-owned files only)
| Step | File (owner) | Exact change |
|---|---|---|
| S1 | `project.godot` (02) | Add `Services="*res://src/services/services.gd"` **after** `Save=` in `[autoload]` (before `App` is fine). |
| S2 | none required | As an autoload named `Services`, `services.gd` binds itself to `/root/Save` in `_ready` (`attach_save`) and rebinds within one frame after every `Save.load_progress()`. If 02 prefers explicit wiring: call `Services.attach_save(Save, Events)` once after the first load. |
| S2a | `src/core/save.gd` (02) | Keep `services` through `_migrate` (already true: unknown keys kept). Keep emitting `Events.progress_changed` after each successful save (used as the save epoch). Keep ONE Save instance per file. |
| S3 | gameplay (02) | Only when 01 enables a placement/product: set `Services.ads.grant_sink` / `Services.purchases.grant_sink`. The sink applies the reward **in memory**, returns true, and **never saves**. Not needed today (`I5 = NOT_REQUIRED_YET`). |
| S4 | battle.gd (02) | DONE: `battle_uid` in BattleInfo/BattleResult (battle.gd:65/74/210). Integration check I6 verifies the real generator against the offer policy. |

## 2. Acceptance gate (02 and 07 can run it now)
```powershell
pwsh -File tests/services/run_services_suites.ps1                 # all 4 service suites, sequential
tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_integration.gd
```
| Exit | Meaning |
|---|---|
| 0 | all checks pass AND I1–I4 pass on the game's own wiring → integration evidence |
| 2 | no failures, integration BLOCKED (was the result until 02 S1 landed) |
| 1 | a failure (report lists it) |
Report: `user://services_integration_report.json` (`verdict`, `integration.I1..I6`, `rows.<ID>.{status, binding, game_evidence}`, `blockers`).

Integration checks:
| ID | Check | Today |
|---|---|---|
| I1 | `Services` autoload registered after `Save` in project.godot | PASS (2026-10-31) |
| I2 | `/root/Services` store is persistent and is `Save.progress["services"]` | PASS |
| I3 | save epoch bound to `/root/Events` (grant-sink contract enforcement) | PASS |
| I4 | after `Save.load_progress()` the store is stale, and is rebound after ONE frame of `Services._process` | PASS |
| I5 | game grant sink present, required only when 01 enables a placement/product | NOT_REQUIRED_YET |
| I6 | real `battle_uid` generator accepted by `reward_policy.gd`, unique per call | PASS |

`-- --simulate-integration` makes the test add `services.gd` as `/root/Services` itself, to show what S1 would produce. Result on 2026-10-31: I2 `PASS_SIMULATED`, I3/I4 PASS, every row PASS with `binding=services_node_simulated`, `game_evidence=false`, exit 2. **Simulated is not game evidence.**

## 3. Failure injection used (no 02 fault hook needed)
| Fault | How | Rows |
|---|---|---|
| Save cannot write | create a directory named `save.json.tmp` in the save dir → `FileAccess.open(tmp)` fails in save.gd | R2, R3, P1 |
| Crash / memory loss | `Save.load_progress()` from disk (drops in-memory progress) | R3, R8, R14, R15, P1 |
| Process death | child Godot process (`tests/services/integration_child.gd`, game autoloads loaded) kills itself with `OS.kill(own pid)` before commit / after commit / after the sink saved | R4, R5, R7 |
| Torn main file | truncated `save.json` → save.gd `.bak` recovery | R15 |
| Broken grant sink | sink saves itself and returns true / false; returns false without saving | R6, R8, R9 |
| Reload during ad | `Save.load_progress()` while an ad session is active | R14 |
When 02 ships the debug-only save fault hook requested by 07/10, these rows can switch to it; the expected results do not change.

Isolation: every write goes to `user://svc_int_test/<case>/` (the autoload Save is redirected there and restored afterwards). The `hygiene` group hashes the player's `user://save.json` and `.bak` before and after and fails if they changed. The directory is deleted at the end.

## 4. Expected outcomes
See `REWARD_STATE_TABLE.md` (IDs R1–R16, P1–P6, D1–D6). Invariant on every row: never coins without the ledger entry, so no duplicate reward. Rows R8/P2 deliberately lose one reward when the game breaks the sink contract; R13 loses one grant if two Save instances exist.

## 5. Disabled-mode checks (run in every gate run)
D1 default factory and `/root/Services` (if registered) are `disabled`, all `live.*` false; D2 01 data flags turned on do not enable anything in disabled mode; D3 release build / `production` request fall back to disabled; D4 consent flow `unsupported`, no choice changed; D5 no production adapter files, ad unit IDs, keys, URLs or device-id calls in src/services; D6 Android `permissions/internet=false` in export_presets.cfg (read-only check of a 02/04 file; must stay off until ads/billing are approved).

## 6. Not covered
Android process death, storage and lifecycle (desktop Windows only); real SDK/store behaviour (mocks only); the game's own reward application code (no sink exists yet).
