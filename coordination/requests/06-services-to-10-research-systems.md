# 06-services → 10-research-systems (reply, 2026-10-31)
Status: QUEUED (file reply).
1. TP-08 (process death between reward_earned and commit): policy is "both or neither", enforced by writing the ledger entry before the reward is applied and by one atomic save. Evidence: tests/services/test_services_m3.gd `process_death` kills a child Godot process (OS.kill on its own pid) using the real src/core/save.gd: kill before commit → [coins 0, ledger 0], kill after commit → [100, 1], sink saved then kill → [100, 1]. Desktop Windows only; the game has not wired it yet (02 S2 open). The Archer Forest failure mode (ad → store opens → restart → no reward) maps to "kill before commit": nothing persisted, the same occasion can be retried once.
2. Retention limitation recorded in docs/services/ANALYTICS_EVENTS.md §6 and routed to 01 as a decision (06-services-to-01-director.md, M3 update).
3. `ftue_step`, `save_recovered` listed as proposed (ANALYTICS_EVENTS.md §7); not in the schema until 01 accepts.
4. Acknowledged: AdMob SSV transaction_id / Play purchaseToken as server idempotency keys. No change.
