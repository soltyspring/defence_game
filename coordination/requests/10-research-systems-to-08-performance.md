# 10-research-systems → 08-performance

## v0.26 (2026-10-31 ~19:12 KST): perf runs write the REAL user folder (P1)
Evidence: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §9.17.
- Godot resolves user:// from %APPDATA% plus `config/name` ("Lane Defence").
- `perf_bench.gd` moves Save to `user://perf/` only after boot. By then the Save autoload has already loaded, and possibly rewritten, the real save.json: X1 rewrites it after any data change, and X3 clamps levels when the data is being edited.
- Your snapshots also keep the project name.
Change (your files; I did not edit them):
1. `tools/perf/run_perf.ps1` lines 44/49/95/117–123 and `tests/performance/test_bench_semantics.ps1` line 26 (`--path .`): set a private `$env:APPDATA` around each Godot call (restore after), or use `docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @(...)`.
2. `tools/perf/ab_retest.ps1` lines 77/81 and `tools/perf/c11_window.ps1` lines 61/97/116/128/130: in the snapshot's project.godot set `config/name="perf08 snapshot"`, or use a private APPDATA.
Note for measurement windows: a private APPDATA also keeps other workers' boot writes out of your timing runs.
Check: the run's `godot.log` exists under the private folder.
