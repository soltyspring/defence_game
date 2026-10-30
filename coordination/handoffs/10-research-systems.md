# 10-research-systems handoff
Updated: 2026-10-31 ~08:07 KST (same session, resumed after account change; quota 10.9/10000 = 0.11% at 08:06)
Model/agent: claude-opus-5.5 / trust-all, same window, no restart. Session ID: not exposed in-session (see coordination/.runtime/quota/sessions.json; 10 cannot identify its own entry).
Owned: docs/research/systems/**, coordination/status|handoffs/10-research-systems.md, coordination/requests/10-research-systems-to-*.md
Git protocol read and acknowledged. Decisions: DECISIONS D1–D12 DEFAULT, Q1 PENDING. Unchanged, and 10 asked no user questions.
Processed: coordinator-to-10-research-systems.md including the "Research review gate", "Source hygiene" and two QUOTA CHECKPOINT blocks (both handled); QUOTA_POLICY; 09→10 R09-10-1 (acknowledged and answered in §5.8; 10 did not re-collect KO reviews and did not duplicate 09's design/visual analysis).

## Misrouted dispatch (needs coordinator action)
At ~08:06 this 10 window received "Resume saved 09-research-product session ... continue its exact next task". 09's own handoff was updated at 07:44 after the account change, which shows 09 is running in its own window. Taking over 09's task here would create a duplicate 09 worker and write to 09-owned paths, both of which BRIEF/OWNERSHIP forbid. **10 did NOT perform any 09 work.** Request: coordinator-to-coordinator note in coordination/requests/10-research-systems-to-coordinator.md. If the coordinator confirms that 09's window is really dead, it should say so explicitly, and then 10 can act as a 09 stand-in.

## Commits
- 6ab1d482ffea0bc84f587da3415da76821f54f97 v0.1 PUSHED
- 9e3953f2027d5746f47cc7b603d3975745b35785 v0.2 PUSHED
- v0.3 (this task): SHA recorded in status after the helper call

## v0.3 changes
- SV-1 REPRODUCED by executing the unmodified save.gd with research probe docs/research/systems/probes/probe_save_rotation.gd (headless, isolated user://probe10/, deleted afterwards). Recovery from .bak, then one save, leaves the corrupt file as .bak. A second corruption gives unlocked_round 6→1. The emulated crash window gives 6→1 with recovered=false (silent). Scenario B is an emulation of save.gd's file-operation order, not an in-code fault.
- SV-2 = 07 QA-O003, SV-5 = 07 QA-B003 (cross-referenced, no duplicate work).
- §5.8: 09 symptom table mapped to data requirements; run checkpoint options (a/b/c) with run.json example; TP-15.
- Hiring-tag rule and source-hygiene statement added. Requests to 02 (v0.3 + R9), 07 (SV-1 acceptance case), 01 (#5 resume decision, #6 migration/entitlement rules).

## Validation
- Probe output: PROBE10_SAVE_ROTATION {"A_recovered":true,"A_unlocked_after_load":6,"A_save_ok":true,"A_bak_is_corrupt_after_save":true,"A2_unlocked_after_second_fault":1,"A2_recovered":true,"B_recovered":true,"B_unlocked_after_crash_reload":1,"B_recovered_after_crash_reload":false}, exit 0.
- Doc: all S# refs defined, TP-01..15 present, git diff --check clean, no .local_inspect.
## Errors / caveats
- The first probe run hung (I used `_init`, so it ran before the tree existed). I stopped only my own 2 probe Godot processes, PIDs 36536/29868. Other workers' Godot processes were not touched.
- One "get_node() absolute path outside active tree" error came from the probe environment and did not affect the save result.
- Concurrent headless Godot processes from other roles were running at the time. My probe is file-I/O only, so no performance claims depend on it.

## Next steps
1. Wait for replies from 02 (R1–R9), 07 (SV-1 case) and 01 (#5/#6), and for coordinator clarification of the misrouted 09 dispatch.
2. After 02 adds the fault hook (R6), rerun scenario B with an in-code fault and update §6.4.
3. Stop at ≥97% quota.
Outstanding questions: none to the user.
