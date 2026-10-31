# Save fault tolerance — evidence (owner: 02-engine)
Date: 2026-10-31. Code: src/core/save.gd. Contract: docs/contracts/INTERFACES.md §3.

## Defects addressed
| ID | Problem | Fix |
|---|---|---|
| QA-B004 / 10 SV-1 (P1) | After recovering from `.bak`, the next save removed the good `.bak` and rotated the corrupt main into `.bak`. A second fault, or a kill between `main→.bak` and `tmp→main`, reset progress to round 1 with `recovered=false` | An unreadable main is quarantined as `save.json.corrupt-<unix>[-n]` at load (and again at save if found). Main is rotated into `.bak` only when it is known/verified good. Load order: valid main → valid `.tmp` (it exists only after verify, so it is the newest state) → valid `.bak` → fresh. Any non-main source sets `recovered=true` and `recovery_source` |
| 10 R6 | No in-code fault hook | `Save._fault` (debug builds only, one-shot): `after_tmp_write`, `torn_tmp`, `after_bak_rename`, `before_final_rename`. `save_progress()` returns false at that point, leaving the files a killed process would leave. `fault_fired` reports which point fired. Ignored when `OS.is_debug_build()` is false (release export templates) |
| 10 R3 | A result could be applied twice | `progress.applied_battles` (ring buffer, 32 uids). `record_result` refuses a known `battle_uid` (also after reload). On write failure the touched fields are rolled back and `false` is returned. App marks `result.saved` / `result.duplicate` |
| QA-B003 / 10 SV-5 | Wrong-typed fields crashed `record_result` | `_migrate` replaces wrong-typed values with defaults, normalises stars/best_time/upgrades/tutorial_done, keeps unknown keys (06 `services`) |
| QA-B005 | Write failure was silent | `Events.toast("save_failed", {error})` on any write failure |
| QA-B006 / 10 SV-2 | v99 save rewritten as v1 | Newer version → `read_only=true`, never written (`save_progress()` returns false); App toasts `save_read_only` |
| QA-B007 | No clamps / size guard | unlocked 1..rounds+1, coins 0..`meta.json currencies.gold.max` (9 999 999), stars int 0..3, files > 2 MiB rejected (PROVISIONAL limit, 08 to set) |

## Same-condition reproduction and retest
Before = save.gd identical to HEAD e9dfaa4 (last changed in that commit only by the `tutorial_done` default). After = this change. Same commands, same machine.

10 probe `docs/research/systems/probes/probe_save_rotation.gd`:
| Field | Before | After |
|---|---|---|
| A_bak_is_corrupt_after_save | true | false |
| A2_unlocked_after_second_fault (expected 6) | 1 | 6 |
| B_unlocked_after_crash_reload (expected 6) | 1 | 6 |
| B_recovered_after_crash_reload | false (silent reset) | true |
Note: probe scenario B still emulates the old step order outside save.gd; with the R6 hook it can now be injected inside save.gd.

07 acceptance `.\tools\qa\run_acceptance.ps1 -Only save,faults`:
| Check | Before | After |
|---|---|---|
| SAVE-05 hostile types normalised | FAIL | PASS |
| SAVE-06 record_result after hostile load | BLOCKED | PASS |
| TP-01 kill points | PASS | PASS |
| TP-02a valid backup kept after recovery+save | FAIL | PASS |
| TP-02b double fault keeps progress | FAIL (unlocked 1, recovered=false) | PASS |
| TP-06 v99 byte-identical | FAIL | PASS |
| TP-13a clamps | FAIL | FAIL (only coins: 9 999 999 = data/meta.json gold max; 07's check expects 999 999) |
| TP-14a write failure keeps file | PASS | PASS |
| TP-14b write failure surfaced | FAIL | PASS |
| Total | PASS 10 FAIL 6 BLOCKED 1 | PASS 16 FAIL 1 BLOCKED 0 |
After-run report: build/qa07/20261031-090036/acceptance_report.json (local, git-ignored).

Engine selftest `_check_save_faults` (src/core/diag/selftest.gd), all PASS: B004 double fault keeps the recovered state; all 4 fault points × {normal save, first save after recovery} keep committed progress and never recover silently; battle_uid applied once (second call and call after reload refused, coins 50, clears 1); record_result rollback on injected failure; hostile types; clamps; newer-version byte-identical.

Regression: tests/integration/test_ui_integration.gd 31/31; tests/services/test_services_integration.gd 146 passes, 0 failures (4 BLOCKED = Services autoload not registered, 06 S1); acceptance flow 40 PASS / 4 FAIL (FLOW-04B counterattack text, FLOW-13B B002, FLOW-23/23B B001: pre-existing, not save-related).

## Not covered / limits
- No real power-loss test on a device file system. Godot `DirAccess.rename` over an existing file and fsync semantics on Android are not verified.
- Quarantined `.corrupt-*` files are not yet pruned (one per corrupt load).
