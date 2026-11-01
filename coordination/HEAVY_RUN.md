# Heavy local runs: one at a time (coordinator rule, 2026-10-31 23:20 KST)
Trigger: at 23:08:55 KST the PC blue-screened (bugcheck 0x50 PAGE_FAULT_IN_NONPAGED_AREA, dump C:\WINDOWS\Minidump\103126-9296-01.dmp, report 06f7293b-9441-47d6-953b-f2f4f9b3ecd2). The dump needs admin rights and was not analysed, so the faulting driver is unknown. This PC has 40+ older kernel error reports (0x193, 0x3b, 0x7f, 0x133, 0xa, 0x7e) from Feb-Oct 2026, so the instability predates this project; heavy parallel load is the likely trigger. At the time: 10 workers at xhigh, 03 running Godot import plus 8 capture runs, 06 rerunning the debug AAB (Gradle), 05/04 preparing Godot runs.
Damage found after reboot: .git/refs/remotes/origin/main zero-filled (restored to 6303e18, git fsck clean), coordination/.runtime/quota/usage.json zero-filled (rewritten by quota_guard). Session logs intact.
Rule for all workers: Godot (headless, visible, import, export), Gradle/AAB/APK builds, emulator and any measurement longer than 1 minute run only inside
  & .\coordination\heavy_run.ps1 -Label '<NN>-<task>' -Script { <command> }
It holds a machine-wide mutex (Local\defence_heavy_run), so only one heavy run exists at a time; waits are logged in coordination/.runtime/heavy_run.log. Do not bypass it. Batch fewer variants per run.
Coordinator: restart workers 30 s apart, check heavy_run.log and the process list for parallel Godot/Gradle/qemu, and report repeated crashes to the user (the user may want to inspect the dump with admin rights or update the NVIDIA / USB Mobile Monitor (Amyuni 2021) display drivers).


## Detached heavy runs (coordinator rule, 2026-11-01 01:55 KST)
Trigger: between 01:46 and 01:50, the agent tool calls of 05, 01 and 10 hit their 30-minute limit while waiting for the lock or just after taking it. The killed wrapper released the mutex, but its Godot child kept running, so two heavy runs overlapped (see the NOTE lines in heavy_run.log). Waits for the lock are now 20-30 minutes, so a foreground wait inside one tool call is no longer safe.
Rule for all workers, effective now: start every heavy run DETACHED, then poll in short tool calls.
  1. Put the heavy command(s) with all their arguments in one small job file, e.g. build/heavy/<NN>-<task>-job.ps1 (git-ignored).
  2. & .\coordination\heavy_run_detached.ps1 -Label '<NN>-<task>' -ScriptFile build\heavy\<NN>-<task>-job.ps1
     It returns at once with "HEAVY_JOB_STARTED pid=<pid> out=<log>". The job waits for the lock in its own hidden pwsh.
  3. Poll with short tool calls (each well under 30 minutes): Select-String -LiteralPath <log> -Pattern '^HEAVY_JOB_DONE'. The last line is "HEAVY_JOB_DONE exit=<n>".
  4. Do not queue a second job for the same task while one is queued or running. Never kill a job process or a Godot child.
  5. Do docs and static work while waiting. Keep using isolated APPDATA and DISPLAY2 inside the job file, as before.
Tested by the coordinator against a private copy of heavy_run.ps1 with a test mutex: two queued jobs ran one after the other, exit codes 0 and 7 were reported, and the real lock and log were not touched.



## 2026-11-01 02:11 KST coordinator: heavy_run.log lines were being lost; fixed
Cause: several processes appending with Add-Content at the same moment lose lines. Test on this PC: 3 writers x 200 lines kept 307 of 600 with Add-Content and 600 of 600 with an exclusive append handle plus retry. That is how START/END lines went missing (10-v032-c-content-migration-retry has no END although its job finished 02:04:46; 23:53 04-numbers-capture START without END). heavy_run.ps1 now writes its own START/END lines through Write-HrLine (exclusive handle, retry up to 30 s). Checks: scope test 4/4 PASS (sha256 967B50B9...), 8 concurrent test jobs on a private mutex gave 8 START, 8 END, 0 overlaps. Backup: coordination/.runtime/heavy_run.ps1.bak-0210. Jobs already holding or waiting for the lock keep the old code until they end.
Rule for you: when you add a NOTE line to coordination/.runtime/heavy_run.log, do not use Add-Content or Out-File -Append. Use an exclusive append, for example:
  $f=[IO.File]::Open('coordination\.runtime\heavy_run.log','Append','Write','Read'); $b=[Text.Encoding]::UTF8.GetBytes("<your line>"+[Environment]::NewLine); $f.Write($b,0,$b.Length); $f.Dispose()
(retry if it throws IOException). Never rewrite or truncate the log.

