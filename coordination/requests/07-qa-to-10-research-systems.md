# 07-qa → 10-research-systems
Status: QUEUED (file request). Date: 2026-10-31 08:10. Reply to 10-research-systems-to-07-qa.md.

Implemented `tests/acceptance/suite_faults.gd` (commit f99094f). No 02 fault hook exists, so kill points are rebuilt as the exact file states a kill leaves, from real save.gd output. Results at clean HEAD 462991a (build/qa07/head-462991a):
| TP | Result | Note |
|---|---|---|
| TP-01 (after tmp write / after bak rename / torn tmp) | PASS | committed state kept at all three points |
| TP-02 (SV-1) | **FAIL** | confirmed by execution: after one recovery the next save deletes the valid .bak; kill during that save → fresh progress, recovered=false. Filed QA-B004 P1 to 02 |
| TP-06 | FAIL | v99 rewritten as v1 (QA-B006 P3) |
| TP-13 | FAIL (clamp) / PASS (deep nesting, 50 MB no crash, 6.8 s desktop) | QA-B007 P3 |
| TP-14 | PASS (file intact) / FAIL (no player notice) | QA-B005 P2 |
| TP-03, TP-04, TP-05, TP-11 | NOT_TESTED | need battle_uid / upgrade purchase API / data/migrations.json / restore flow, none exist in runtime yet |

## 2026-10-31 23:5x: reply to v0.26 / v0.28 (user:// isolation, 996 MB)
- `tools/qa/run_acceptance.ps1` now gives every Godot child (import, acceptance, services suites, `--version`) a private `APPDATA=build/qa07/<ts>/appdata`. Without its own Godot log under that folder the run exits 3. env.txt records the real `qa07\` state and the save.json/.bak hashes before and after.
- Proof at HEAD 3e355a8 (run 20261031-234416): 3 own logs; real `qa07\` 214 files, newest 18:40:12, before and after; real save hashes unchanged (614A1FAC…/E4263BE6…); 0 new logs in the real folder.
- TP-13: suite_faults.gd now deletes its own `*.corrupt-*` and `tp13.*` files at the end. The runner also prunes files > 1 MiB under the private folder (0 left to prune in this run).
- Probes (`probe_balance`, sim re-run) go through your `isolated_godot.ps1`. All runs are inside `coordination/heavy_run.ps1`.
- The old 996 MB: `tools/qa/clean_real_qa07.ps1` deletes only the `qa07\` subtree. Its dry run lists 214 files, every one with a same-size copy in your backup `%LOCALAPPDATA%\defence_userdata_backup\20261031-191353`. 07 has not applied it yet; it waits for the user's yes. Please keep that backup until then. Policy: docs/verification/USERDATA_POLICY.md.
