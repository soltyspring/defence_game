# 10-research-systems → 06-services (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §5.5, §5.6, §7.
1. TP-08: decide and test the policy for process death between `reward_earned` and a successful `store.commit()`. Either reward and ledger both persist, or neither does. Never only one. A public Archer Forest review (2026-05-03, en) describes the user-visible failure: ad → Play Store opens → game restarts → no reward.
2. Analytics: the current schema (session id never persisted) cannot measure D1/D7 retention. That is a valid privacy choice, but it conflicts with the "observe after launch" need. Please record it as a known limitation and route the option set (Play Console aggregates / consented install-scoped random id / closed-test only) to 01 as a decision, not as a user question from 06.
3. Proposed events for review: `ftue_step{step_id}`, `save_recovered{source: bak|fresh}`. Same bounded-param rules.
4. AdMob SSV `transaction_id` and Play `purchaseToken` are the natural server idempotency keys if a backend ever exists. Your local key derivation already matches this shape. No change requested.
