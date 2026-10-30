# 10-research-systems handoff
Updated: 2026-10-31 ~08:52 KST · Session sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce · claude-opus-5.5 / trust-all, same window
Owned: docs/research/systems/**, coordination/status|handoffs/10-research-systems.md, coordination/requests/10-research-systems-to-*.md
Git protocol acknowledged. DECISIONS D1–D12 DEFAULT, Q1 PENDING. Unchanged, and no user questions from 10. No 09 paths touched.

## READ ACK / START
- ~08:19: coordinator correction 08:09 read (10 role, the 09 dispatch was misrouted).
- ~08:39: resume order after the new login read.
- ~08:45: review order "R3 code reading → execution evidence; rerun scenario B via the hook once R6 lands" read and STARTED. Quota 631.38/10000 = 6.31% at 08:45.

## This task (v0.6): R3 executed
- New probe docs/research/systems/probes/probe_battle_uid_dedup.gd (real autoloads, Save redirected to user://probe10/, real save.json SHA-256 F33DD39B…776A unchanged before and after, probe dir deleted).
- Result at HEAD e9dfaa4: the same battle_uid result applied twice is applied twice. App path coins 162→204, clears 1→2, persisted. Save.record_result path 100→200, 1→2. No applied_battles key.
- Scope: battle.gd `_ended_emitted` blocks the duplicate signal in normal play, so no current user path is shown. Proposed P2 (07 judges).
- Doc §6.4 SV-3 row and "프로브 2" section (command, expected, actual, limits) updated; requests to 02 (v0.6) and 07 (TP-03 runnable).

## R6 / scenario B
NOT READY: `"_fault" in Save` = false at e9dfaa4 (checked inside the probe run). Scenario B was not rerun via the hook. Wait reason unchanged: 02 lists R1/R2/R6 as NOT done.

## Commits (all PUSHED origin/main)
6ab1d48 · 9e3953f · 462991a · 14f7084 · 3c8cddb · c4a3d93 · 198e40a · 2aa6d28 · 9ca89e0 · v0.6: SHA in status after the helper call

## Exact next steps
1. At milestones, check save.gd for `_fault` and look for 02-engine-to-10-research-systems.md.
2. R6 lands → switch probe_save_rotation scenario B to the hook, rerun, update §6.4, tell 07, publish.
3. 02 adds applied_battles → rerun probe_battle_uid_dedup and expect duplicate_applied false / 162 / 1.
4. Stop at ≥97% quota.

## Errors / caveats
The probes call internal functions directly (`_on_battle_finished`), which is evidence about the persistence layer, not a user repro. No Godot processes of other roles were touched.
