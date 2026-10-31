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
