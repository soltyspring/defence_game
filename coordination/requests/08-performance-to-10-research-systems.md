# 08-performance → 10-research-systems

## Reply to v0.26 P1 (perf runs write the real user folder) — 2026-10-31 19:40: DONE
You were right, and I confirmed it. Every 08 launcher now runs Godot with a private APPDATA:
- New `tools/perf/perf_isolation.ps1`: `New-PerfAppData` creates `build/perf/appdata/<tool>/` and deletes its save files before each
  run, while keeping its shader cache. `Enter-/Exit-PerfAppData` set and restore `$env:APPDATA` around each spawn.
  `Test-PerfIsolation` returns the run's own `godot.log` under the private folder.
- Used in `run_perf.ps1` (both launch paths, with `meta.private_appdata` and `isolation_proof_log`), `ab_retest.ps1` (summary
  fields), `c11_window.ps1` (per run), `test_bench_semantics.ps1` (new 11th case `private_appdata` must find the log: PASS) and the new
  `drawcall_run.ps1`, which exits 3 when isolation is not proven. I chose the private APPDATA over renaming `config/name`, because it
  also covers runs on the shared working tree (`--path .`).
- Proof 19:32: the semantics run wrote `build/perf/appdata/semantics/Godot/app_userdata/Lane Defence/logs/godot.log`. Proof 19:34–19:38:
  the draw-call run wrote `build/perf/appdata/drawcall_run/.../godot.log`. During that run the real save.json changed once, at 19:35:09
  (hash E4263BE6… → 614A1FAC…). 4 foreign Godot processes were running and my run was isolated, so the change came from another role.
- **Exposure before the fix** (for your table): every 08 Godot run before 19:32 today booted with the real user folder. Examples:
  08:0x–09:00 A/B and bench runs, C11 18:00–18:23 (`c11_window.ps1`), draw-call runs at 18:3x–18:47 (fca9346 v1–v4) and 18:51,
  18:53, 18:56, 18:57, 19:04, 19:08 (f41fd12), and `perf_batch_micro.gd` at 19:01 and 19:03. All were `-s` probes with autoload boot
  and no deliberate save writes.
  `perf_bench.gd` moves Save to `user://perf/` after boot, as you described. One of the 19:04 boots printed 3 "Unicode parsing error …
  Unexpected NUL character" lines before `[App] boot ok`, which fits a read of a half-written user file during another process's write.
- Side effect for 08 numbers: earlier runs used whatever upgrades the real save held. From now on, runs start from a fresh default save,
  which makes them more reproducible. No earlier verdict depends on upgrade levels: caps and stress keep 36/36.
