# 06-services → 10-research-systems (reply, 2026-10-31)
Status: QUEUED (file reply).
1. TP-08 (process death between reward_earned and commit): policy is "both or neither", enforced by writing the ledger entry before the reward is applied and by one atomic save. Evidence: tests/services/test_services_m3.gd `process_death` kills a child Godot process (OS.kill on its own pid) using the real src/core/save.gd: kill before commit → [coins 0, ledger 0], kill after commit → [100, 1], sink saved then kill → [100, 1]. Desktop Windows only; the game has not wired it yet (02 S2 open). The Archer Forest failure mode (ad → store opens → restart → no reward) maps to "kill before commit": nothing persisted, the same occasion can be retried once.
2. Retention limitation recorded in docs/services/ANALYTICS_EVENTS.md §6 and routed to 01 as a decision (06-services-to-01-director.md, M3 update).
3. `ftue_step`, `save_recovered` listed as proposed (ANALYTICS_EVENTS.md §7); not in the schema until 01 accepts.
4. Acknowledged: AdMob SSV transaction_id / Play purchaseToken as server idempotency keys. No change.

# 2026-10-31 ~23:08 KST — reply to v0.26 / v0.28: isolation committed (29d31be)
- `tests/services/svc06_isolation.ps1` (new) is used by `run_services_suites.ps1`, `run_services_on_head.ps1` and `try_debug_aab.ps1`. Before the first Godot call it sets a private `%TEMP%\svc06_iso_*\appdata` as APPDATA for the runner process and all Godot children, including the m3/integration grandchildren.
- The real save.json/.bak are hashed in PowerShell **before** Godot starts and again after. The real folder is only read.
- **Proof** printed as one `SVC06_ISOLATION {json}` line: this run's godot logs under the private folder, and 0 new `services_*` reports in the real folder. A missing proof makes OVERALL exit 1.
- **First isolated full run** (23:00:34–23:01:04, 4 other Godot processes running): OVERALL exit 0; isolated=true, private_logs=5 (Godot keeps 5), new reports in the real folder 0, new godot logs in the real folder 0, real save unchanged. AAB run 23:01–23:07: isolated=true, same zeros.
- **Leftovers from before the fix:** 7 `services_*_report.json` (18:44, 19:04) and `m3dbg1~3` remain in the real folder. 06 did **not** delete them, because deleting is a write to the real folder. Tell 06 (or the coordinator) if they should be removed and by whom.
- Not covered: someone running a single suite directly with `godot -s` still boots Save in the real folder. The suite headers will point to the runner.
