# 10-research-systems handoff
Updated: 2026-10-31 ~08:21 KST · Session sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce (per coordinator correction 08:09) · claude-opus-5.5 / trust-all, same window
Owned: docs/research/systems/**, coordination/status|handoffs/10-research-systems.md, coordination/requests/10-research-systems-to-*.md
Git protocol acknowledged. DECISIONS D1–D12 DEFAULT, Q1 PENDING. Unchanged, and no user questions from 10.

## READ ACK / START (~08:19 KST)
Read: coordinator-to-10-research-systems.md including the 08:09 correction (10 role confirmed, the 09 dispatch was misrouted, and the old quota notices are HISTORICAL); 07-qa-to-10 (08:10); 06-services-to-10 (08:12); 09-to-10 R09-10-1 (answered in v0.3 §5.8). No reply files exist from 02 or 01. STARTED the follow-up task. No 09 paths were touched.

## Follow-up result
| Owner | Request | State |
|---|---|---|
| 02 | R1–R9 | **NO REPLY.** The R6 fault hook does NOT exist: save.gd at HEAD 30a14bd has no hook, its last commit is 1eb4637, and the working tree only has 02's uncommitted `tutorial_done: []`. 02's last handoff is the 07:32 checkpoint with an uncommitted WIP note |
| 07 | SV-1 | DONE by 07: TP-02 FAIL → QA-B004 P1 (owner 02). Also QA-B005/B006/B007. TP-03/04/05/11 NOT_TESTED because the runtime APIs are missing |
| 06 | TP-08 etc. | DONE by 06: the "both or neither" policy was verified with a real save.gd and a child-process kill (desktop only) |
| 01 | #5/#6 | NO REPLY. data/migrations.json absent |
Scenario B could NOT be rerun through a hook (blocker: 02 R6). As a substitute, I re-executed the probe on the current tree (30a14bd + 02's uncommitted line): A2 6→1, B 6→1 with recovered=false. SV-1 is unchanged.

## Commits
- v0.1 6ab1d482ffea0bc84f587da3415da76821f54f97 PUSHED; v0.2 9e3953f2027d5746f47cc7b603d3975745b35785 PUSHED; v0.3 462991ae8dc335e045901f9e702f364144d24170 PUSHED; status 14f7084da3e43c1d3808314b77e9b94810b40a2c PUSHED
- v0.4 (this follow-up): SHA in status after the helper call

## Exact next steps
1. Wait for coordination/requests/02-engine-to-10-research-systems.md, and for the R6 hook to land in save.gd (grep `_fault`).
2. Once it lands: adapt probe scenario B to set the hook (`before_final_rename`) instead of emulating, rerun, update §6.4, notify 07, and publish.
3. Wait for 01's reply on #5/#6.
4. Stop at ≥97% of the current account's quota (2.84% at 08:18).

## Errors / caveats
The probe's scenario B emulates the order of file operations; it does not inject a fault inside save.gd. One harmless "get_node absolute path" probe-environment error. Other roles' Godot processes were running and were not touched.
