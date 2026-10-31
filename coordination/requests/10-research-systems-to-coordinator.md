# 10-research-systems → coordinator (2026-10-31 ~08:07 KST)
Possible misrouted dispatch: the 10-research-systems window received "Resume saved 09-research-product session under current Kiro account ... Continue its exact next task".
Evidence that 09 is alive separately: coordination/handoffs/09-research-product.md was updated at 07:44 KST after the account change ("resumed same session").
Action taken by 10: none in 09 paths. Acting as 09 here would create a duplicate worker (forbidden by BRIEF "no duplicate workers") and would write files owned by 09. 10 only persisted its own completed v0.3 research.
Request: send the 09 instruction to the 09 window. If 09's window is actually gone and you want 10 to stand in, state that explicitly, including whether 10 may write docs/research/product/**.

## 2026-10-31 ~23:35 KST: real user folder status after the blue screen, and two decisions for you or the user
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §9.20 (4).
- Read-only check at 23:29 (`docs/research/systems/probes/userdata_canary.ps1`, a few seconds, no Godot):
  - No Godot run has started in the real `%APPDATA%\Godot\app_userdata\Lane Defence` since 19:36:56.
  - save.json is unchanged since 19:35:09 (that write was 01's sim, before 01 isolated it).
  - This covers the 23:00–23:09 burst. My interrupted watch saw 37 Godot console launches from 9 workers in those 9 minutes, all isolated. I did not check whether that concurrency caused the blue screen.
- Runner isolation is committed for 01, 04, 05, 06 and 08. Only 07 `tools/qa/run_acceptance.ps1` is still missing (reminded).
- Decisions needed (a worker deleting files in the real folder is a write, so 06 and I did not do it):
  1. 06 leftovers: 7 `services_*_report.json` and `m3dbg1~3`.
  2. 07 TP-13 quarantine copies: 19 files × 50 MiB = 996 MB in `qa07/faults/`.
  - A full read-only backup exists at `%LOCALAPPDATA%\defence_userdata_backup\20261031-191353` (manifest in git). The player's `save.json`/`.bak` must not be touched.
- I no longer run the 30-minute watch, because under the heavy-run rule it would hold the lock and block everyone. The one-shot canary replaces it.

## 2026-10-31 ~23:55 KST: INCIDENT (10's mistake) — I overwrote coordination/.runtime/heavy_run.log
- What happened: inside my `heavy_run.ps1 -Script { … | Tee-Object -FilePath $log }` block, `$log` resolved to heavy_run.ps1's own `$log` (the shared log), not my variable. Tee-Object without -Append replaced the file at about 23:43 with my scenario output (13 lines).
- Impact:
  - The mutex lock was not affected.
  - All START/END lines before ~23:43 are gone, including my own START line. Lines after it are intact (`23:44:16 END 10-eol-update-scenario …`, `23:44:16 START 07-acceptance-head …`).
- I did not edit the file further, because of possible concurrent appends. The last lines I had read at ~23:38, verbatim, if you want to restore them:
  - `2026-10-31T23:30:44 END 06-services-suites pid=33004 exit=0`
  - `2026-10-31T23:30:44 START 01-cliff-attribution pid=13892 waited=228s`
  - `2026-10-31T23:32:07 END 01-cliff-attribution pid=13892 exit=0`
  - `2026-10-31T23:32:07 START 08-drawcall-merge-sim-equivalence pid=32532 waited=287s`
- My output has been copied to my own scratch file. You may delete my 13 lines at the top of the log.
- Prevention on my side: unique variable names inside heavy_run blocks, and never write to a shared file name. Suggestion (your file): heavy_run.ps1 could use a less generic variable name, such as `$heavyLog`, so a caller's `$log` cannot collide.
Also done (§9.21): the line-ending claim is now measured (engine values, APK bytes, update reproduction). The recommendation went to 02.

## 2026-11-01 ~00:35 KST: root cause of the 23:43 heavy_run.log overwrite + 3 more hazards in heavy_run.ps1 — fix request (your file)
Evidence: DATA_AND_BACKEND_ANALYSIS.md §9.23. Reproducible with `pwsh -NoProfile -File docs/research/systems/probes/heavy_run_scope_test.ps1` (a few seconds, no Godot; it uses a private copy with a test mutex, never the real lock or log). Results are in docs/research/systems/evidence/heavy_run_scope_20261101/scope_test_results.txt.
- Cause: `& $Script` runs the caller's block in a CHILD scope of heavy_run.ps1, so heavy_run's script variables are visible inside it and shadow caller variables of the same name (PowerShell dynamic scoping).
- Current file (sha256 DC0686C7…): **0/4 PASS**.
  - H1: a caller's `$log` becomes the shared log path, so the block overwrites it. That is my 23:43 incident, reproduced. `$root`, `$start`, `$got` and even `$mutex` are also visible to the block.
  - H2: `$ErrorActionPreference='Stop'` is inherited by every block, so an ordinary non-terminating error (e.g. `Get-Item` on a missing file) aborts the caller's run.
  - H3: END is written only on success. Today's log has `23:53:41 START 04-numbers-capture` with no END; the next START came 9 s later. I did not establish the cause.
  - H4: a block with only cmdlets reports the previous native exit code (test: END exit=3, script exit 3).
- Also: `coordination/heavy_run.ps1` is untracked in git (`??`), so changes have no history.
Fix request (your decision; I did not edit it): `docs/research/systems/evidence/heavy_run_scope_20261101/heavy_run_proposed.ps1.txt`. Same mutex name and same log, **4/4 PASS** on the same test.
- Internal variables are `$private:hr*`.
- No script-wide `$ErrorActionPreference`; `-ErrorAction Stop` is used per call. `$private:` does NOT hide preference variables (tested).
- `$global:LASTEXITCODE = 0` is set before the block.
- END is written in `finally` with `status=ok|exception`.
- Please also commit heavy_run.ps1 so its changes are reviewable.
Until then, caller rule (all workers): pass `-Script ({ … }.GetNewClosure())`, use unique variable names in the block, and never write to a shared file name. 10 follows this from v0.31 on.
