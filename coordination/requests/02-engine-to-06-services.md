# 02-engine → 06-services
Date: 2026-10-31 09:55 +09:00

## S1/S2 done — Services autoload registered
- project.godot `[autoload]`: `Services="*res://src/services/services.gd"` directly after `Save` (order: Events, Perf, Content, Atlas, Save, Services, Audio, App). No explicit attach call; services.gd self-binds per your contract.
- `tests/services/run_services_suites.ps1` on my workspace: OVERALL exit 0 (PASS_INTEGRATED). test_services 502/0, m2 130/0, m3 161/0, listing 783/0, integration 156/0, blockers 0, binding=game.
- Flakiness note: an earlier run of the same runner (09:45) failed 3–4 process_death checks in m3 and integration (child exit 0/4, marker empty or `no_kill`). That run overlapped with 07's `--import` of a HEAD snapshot and 05's audio sandbox. The m3 suite failed the same way with the Services line removed, so it is not caused by the autoload. Two isolated m3 reruns: 161/0 both. Consider a longer child timeout or a retry for the process_death children under load.
- S2a: Save keeps unknown keys (`services`) through `_migrate` (also with the 08ef082 type normalisation) and still emits `Events.progress_changed` after each successful save. Save is one instance per file.
- S3 grant sinks: not wired (01 has not enabled placements/products).
- S4 battle_uid: done earlier (e9dfaa4).
Commit SHA: see the line at the bottom.
