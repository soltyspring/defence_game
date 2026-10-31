# 10-research-systems handoff
Updated: 2026-10-31 ~08:58 KST · Session sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce · claude-opus-5.5 / trust-all, same window
Owned: docs/research/systems/**, coordination/status|handoffs/10-research-systems.md, coordination/requests/10-research-systems-to-*.md
Git protocol acknowledged. DECISIONS D1–D12 DEFAULT, Q1 PENDING. Unchanged, and no user questions from 10. No 09 paths touched.

## READ ACK / START
- ~08:19: coordinator correction 08:09. ~08:39: resume after the new login. ~08:45: R3 execution task (done in a19289b).
- ~08:52: review order "content-DB integrity probe while waiting for R6" read and STARTED. Quota 860.31/10000 = 8.60% at 08:54. Done in 1aaea61.
- ~09:00: review order "meta-coin economy flow probe from HEAD data, compare with 01 upgrade_budgets.json" read and STARTED. Done as v0.8 (see below). Quota 1134.72/10000 = 11.35% at 09:02.

## v0.10 (02 save fix retest, ~09:20 KST)
- Read 02-engine-to-10-research-systems.md (09:15): R1/R2/R4/R6 accepted and implemented in 08ef082; R3/R5 partial; R7/R8 deferred.
- Executed at HEAD 5426645 (save.gd identical to HEAD; the only uncommitted change in app.gd is 02's log print):
  - probe_save_rotation scenario C via the R6 hook: 8/8 PASS (4 points × healthy/after-recovery, unlocked 6, no silent reset).
  - The emulated A2/B also give 6.
  - probe_battle_uid_dedup: 162 / 1 PASS (persisted).
- Notes sent to 02/07 (P3): result.gd:89 shows "+coins" for duplicate/unsaved results; `.corrupt-*` files are not pruned; tmp-recovery toast after a harmless fault.
- 01 theme labels are still not committed (no data/text commit after 67bf9ca), so the theme check is still pending.

## v0.9 (theme A recheck, ~09:13 KST)
- User decision: Q1 = A (bakery knights vs mold legion), DECIDED by the user. Source: coordinator-to-01-director.md "USER DECISION 2026-10-31 09:03 KST". HEAD DECISIONS.md still reads PENDING; 01 owns recording it. 10 did not edit it.
- Theme labels are not committed yet (data/text last changed in 67bf9ca). Rerun at HEAD 9ca4a43: ERROR 0, WARN 0, INFO 1. The v0.7 boss_overlord ERROR is closed (03 393ada2).
- Added DUP_NAME and STALE_NAME checks plus a `CI NAMES` baseline line to probe_content_integrity.gd (mutation-tested 3/3). Requests sent to 01 (run before commit, post the SHA), 03 (item 1 closed), 07 (new checks). Doc §9.2 updated. During this edit I damaged the §9.3 heading, then repaired it and verified the heading order.

## v0.8 (economy flow)
- Probe docs/research/systems/probes/probe_economy_flow.gd, run on a clean HEAD 07e97ca snapshot (data + budgets only, no autoloads).
- It reproduces 01's greedy budgets exactly (20/20 entries, diff 0).
- Findings: max-out deficit 2,360–3,140 (14–18 r10 replays; 8–10 with the ASSUME scripted-kill ceiling). The L5 tier (2,740) is replay-only on the first-clear path. INTENT checkpoint shortfall only before r05 on LOW (20 coins, 1 r04 replay). No surplus during r01–r10; zero sinks after max-out. The scripted kill coins (12–138) exceed ECONOMY.md's "20–60".
- No play time, win rate or retention estimated. Request sent to 01 with the numbers. Doc §9.3.

## This task (v0.7)
- New probe docs/research/systems/probes/probe_content_integrity.gd. It is read-only, prints one line per finding, and exits 1 on ERROR.
- HEAD f88ce03 was run in a clean `git archive` snapshot because the working tree had uncommitted 01 rounds and 03 manifest changes. The snapshot used no autoloads and a renamed project, so it never touched the real save. Result: ERROR 1 = boss_overlord anim_set missing from the committed manifest (owner 03, already in their working tree and their next task 1), INFO 1 = schema_version missing in 15/21 data files (owner 01, proposal).
- Working tree: ERROR 0.
- Mutation self-test: 10/10 injected defect classes caught.
- Overlap analysis: 07 suite_data DATA-01..14 and 03 validate.py check_data_refs. 03's validator ignores the `anim_set` and `projectile` keys and the engine-built icon names.
- Requests: 03 (new file: boss_overlord tracking + validator gap), 01 (schema_version proposal, data side clean), 07 (add only the gap checks), 02 (optional selftest or loader warning).
- Doc: DATA_AND_BACKEND_ANALYSIS.md §9.2.

## R6 / scenario B
NOT READY at f88ce03. Not rerun. Same reason (02 R1/R2/R6 not done).

## Commits (all PUSHED origin/main)
6ab1d48 · 9e3953f · 462991a · 14f7084 · 3c8cddb · c4a3d93 · 198e40a · 2aa6d28 · 9ca89e0 · a19289b · 1aaea61 (v0.7) · v0.8: SHA in the final report

## Exact next steps
1. After 01 commits the theme A labels: rerun probe_content_integrity at HEAD (clean snapshot), diff `CI NAMES` against the v0.9 baseline in §9.2, and report missing/duplicate/stale names to 01.
2. Scenario B via the hook: DONE (v0.10). Only rerun if save.gd changes again.
3. When applied_battles lands: rerun probe_battle_uid_dedup and expect 162 / 1.
4. Wait for 01's reply on the v0.8 economy questions (intent checkpoints, L5 replay-only, post-max sink).
5. Stop at ≥97% quota.

## Errors / caveats
The HEAD run uses a partial snapshot (data, manifest and atlas JSON only). That suffices for this probe, which reads only those files. Godot created a "Probe10 Snapshot" user dir, which I deleted afterwards.
