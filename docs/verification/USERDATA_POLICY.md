# 07-qa user:// isolation and cleanup policy (owner: 07-qa)
Updated 2026-10-31 23:4x KST. Sources: 10-research-systems-to-07-qa v0.26 and v0.28 (DATA_AND_BACKEND_ANALYSIS.md §9.17–9.19).

## Problem
Godot 4.7.2 on Windows builds `user://` from `%APPDATA%` and `application/config/name`. Every 07 run uses autoloads, so before this change it used the REAL player folder `%APPDATA%\Godot\app_userdata\Lane Defence\`:
- The 07 suites wrote `user://qa07/**` there. The acceptance runner set no private APPDATA.
- TP-13c writes a 50 MiB save on purpose. Save renames a damaged main file to `<name>.json.corrupt-<unix>` and never prunes it, so every run left one 52,428,953-byte copy. The folder held 19 copies, 996,150,107 bytes of the 996,211,578 bytes in `qa07\` (214 files).
- probe_balance runs at 19:23 and 19:26 also wrote logs into the real folder (10 v0.28 evidence).

## Rules from now on
| Run type | How 07 runs it | Proof of isolation |
|---|---|---|
| Acceptance suites (`tools/qa/run_acceptance.ps1`) | Every Godot child (import, acceptance, services suites, `--version`) gets `APPDATA=build/qa07/<timestamp>/appdata` | This run's own `godot*.log` under the private user dir. Missing = exit 3, results not trusted. `env.txt` also records the real `qa07\` file count and newest time before and after, and the real save.json/.bak hashes |
| Probes (`probe_balance`, `probe_r01_risk`, …) | 10's `docs/research/systems/probes/isolated_godot.ps1` (temp dir deleted after the run) | `ISOLATED_GODOT {"isolated":true}` line in the output |
| Visible captures | 04's `tools/build/visible_launch.ps1` (isolated by default: `<EvidenceDir>\appdata`) | 04's proof line |
| Heavy runs of any kind | Inside `coordination/heavy_run.ps1` (one heavy run on the PC at a time, rule from 2026-10-31 23:2x) | `coordination/.runtime/heavy_run.log` START/END lines |

## Proof at HEAD 3e355a8 (run 20261031-234416, full `-Head`, 23:44–23:47)
- Isolation: `isolation_own_logs=3`. Real `qa07\` had 214 files (newest 18:40:12) both before and after the run. Real save.json/.bak hashes stayed 614A1FAC…/E4263BE6…. 0 new Godot logs appeared in the real folder.
- TP-13 cleanup: the private `qa07/faults` folder after the run held 26 small files (largest 1,539 B) and no `.corrupt-*` or `tp13.*` file. The runner had 0 files > 1 MiB left to prune.
- Sim re-run (`isolated_godot.ps1`, 23:52–23:53): `isolated: true`, `real_save_changed_during_run: false`.

## Retention
- `suite_faults.gd` deletes its own `*.corrupt-*` copies and `tp13.*` files at the end of the suite, after the verdicts are recorded.
- The runner deletes every file larger than 1 MiB under the private APPDATA after the run and lists each one in `env.txt` (`pruned …`). Small files (test saves, reports, Godot logs) stay with the run folder as evidence.
- `build/qa07/` is git-ignored and owned by 07. Run folders are kept. After pruning, a run's private folder holds only small files.

## Leftovers in the REAL folder (decision needed before deleting)
- Content: only 07's own `qa07\` subtree. 214 files, 996,211,578 bytes, newest 18:40:12. No file there is newer than the runner change.
- Backup: 10's read-only copy `%LOCALAPPDATA%\defence_userdata_backup\20261031-191353\Lane Defence\qa07` has every one of the 214 files at the same size (checked 23:08 and 23:4x).
- Tool: `tools/qa/clean_real_qa07.ps1`.
  - Default is a dry run, which only lists the files.
  - `-Apply` deletes only the `qa07\` subtree. It refuses if any file there changed in the last 10 minutes or lacks a same-size backup copy. It writes the deleted-file list to `build/qa07/clean_real_qa07_<ts>.txt`.
  - `save.json`, `save.json.bak` and the other folders are never touched.
- Status: dry run done (214 files, 0 without backup, 0 recent). **Not applied.** Deleting files in the player folder is a change to the real user folder, so 07 waits for the user's yes before running `-Apply`.
