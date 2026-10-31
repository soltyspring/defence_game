# 10-research-systems handoff
Updated: 2026-10-31 ~15:41 KST · Session sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce · claude-opus-5.5 / trust-all, same session (reopened for window separation)

## RESUME after user restart (~15:38 KST)
- Read: this handoff, coordinator-to-10-research-systems.md (the QUOTA CHECKPOINT text is historical; I did not stop for it), 01-director-to-10-research-systems.md R1 (D17 schema_version, D19 no mid-round resume, #6 rules accepted, migrations.json in backlog).
- Lost-work check: working tree for owned paths is clean. `git diff HEAD origin/checkpoint/quota-20261031-092323/10-research-systems` shows no differences in docs/research/systems, my handoff or my status (the checkpoint commit 3a4fe47 holds the same content as main). No temp leftovers, no probe Godot processes. **Nothing lost.**
- An interrupted earlier resume attempt left nothing behind. It had only run the probe and a failed name diff (a PowerShell console encoding problem, fixed with UTF-8 output encoding).
- User decision: Q1 = A "빵집 기사단 vs 곰팡이 군단" (DECIDED by the user). HEAD DECISIONS.md still shows PENDING; 01 records it.
- Quota: 2278.54/10000 = 22.79% at 15:37.

## v0.13 (~16:12 KST): R3 upgrade transaction + R5 content_version
- New probe docs/research/systems/probes/probe_upgrade_transaction.gd, run in a clean full HEAD ab00170 snapshot (renamed project, `--import`, Save redirected to user://probe10).
- A: no purchase API, so the purchase itself cannot be tested.
- B: executed a naive direct edit + save_progress() with an R6 fault. Memory stays 40/L2 and a later set_setting persists it, i.e. a double-charge risk.
- C: acceptance C1–C5 auto-runs when an API exists. The cases were validated with temporary reference/naive implementations patched into snapshot copies only: 5/5 vs 2/5 (the naive one double-charges, has no rollback, and lets 59 coins buy a 60 item).
- D: a level above max_level is kept (9 vs 5) and applied (hp_mult 1.64 vs 1.32); no content_version.
- R5 proposal and acceptance sent to 02; TP-04/TP-05 notes to 07; refund-rule decision request to 01. Doc §9.4.
- Next on resume: when `buy_upgrade` (or another candidate name) exists, rerun the probe in a clean snapshot; when content_version lands, check part D for level 5 / 1.32.

## v0.12 (~15:56 KST): theme A check + save retest
- Theme labels: integrity probe at clean HEAD snapshots. abe2303 (after 14b01e2) gave WARN 26 STALE_NAME; 43b4692 (after 01's 5930430) gives ERROR 0 / WARN 0 / INFO 0. 0 missing keys, 0 DUP_NAME. Name diff table in doc §9.2. 01 reply sent.
- Save: probe_save_rotation C 8/8 PASS (abe2303 tree, save.gd = HEAD). probe_battle_uid_dedup 162/1 PASS in a clean full HEAD 8c8635f snapshot, because 02's uncommitted app.gd in the working tree has lost all newlines and fails to parse. Warned 02 and 07.
- D22 economy answers noted in §9.3.

## v0.11 (this resume)
- probe_content_integrity at a clean HEAD 2884231 snapshot: ERROR 0, WARN 0, **INFO 0**, exit 0. This confirms D17 by execution.
- Name diff vs the v0.9 baseline: 0 display-name changes. Theme labels are still not committed (the only data/text change is toast.counterattack in cbfb0a8). The theme check stays pending on 01.
- Doc §9.2 v0.11 note and a 01 request were written.

## Below: prior final checkpoint (still valid)
# (previous) 10-research-systems handoff — FINAL CHECKPOINT (user stop order)
Updated: 2026-10-31 ~09:24 KST · Session sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce (per coordinator correction 08:09) · claude-opus-5.5 / trust-all, same window
Owned: docs/research/systems/**, coordination/status|handoffs/10-research-systems.md, coordination/requests/10-research-systems-to-*.md
State at stop: NO task in progress. Working tree for owned paths was clean before this file was written. No Godot or other processes started by 10 are running (checked: no Godot process with docs/research/systems/probes or probe10 in its command line). No temp leftovers (%TEMP%\probe10_* none, user://probe10 absent).
Quota: 1730.42/10000 = 17.30% at 09:17.

## User decisions (preserved, not edited by 10)
- Q1 = A "빵집 기사단 vs 곰팡이 군단", DECIDED by the user (coordinator-to-01-director.md "USER DECISION 2026-10-31 09:03 KST"). HEAD DECISIONS.md still showed Q1 PENDING at my last check; 01 records it.
- D1–D13 are DEFAULTs (not user approvals). 10 asked the user no questions.

## Done (all verified, all PUSHED origin/main)
| Ver | SHA | Content |
|---|---|---|
| v0.1 | 6ab1d48 | DATA_AND_BACKEND_ANALYSIS.md: competitor evidence/UNKNOWN matrix (DB vendor/schema UNKNOWN), save/transact/backend designs, TP-01..14 |
| v0.2 | 9e3953f | §9.1 content-table mapping |
| v0.3 | 462991a | SV-1 reproduced (probe_save_rotation), §5.8 09 symptoms, run checkpoint |
| v0.4/5 | 3c8cddb, c4a3d93, 198e40a, 2aa6d28, 9ca89e0 | reply tracking, wait reasons |
| v0.6 | a19289b | R3 reproduced (probe_battle_uid_dedup: 162→204, 1→2) |
| v0.7 | 1aaea61 | probe_content_integrity (mutation-tested 10/10), boss_overlord ERROR (03) |
| v0.8 | cd76358 | probe_economy_flow: reproduces 01 upgrade_budgets 20/20; L5 tier 2,740 replay-only; max-out 14–18 r10 replays |
| v0.9 | d554099 | integrity rerun at HEAD 9ca4a43: ERROR 0 (boss_overlord closed by 03 393ada2); DUP_NAME/STALE_NAME checks + CI NAMES baseline |
| v0.10 | 1b34102a115f591cc307d5812bcc38b93879ee21 | 02 08ef082 retest: hook-based scenario B 8/8 PASS; battle_uid 162/1 PASS |
| chore | 05779b700ec98104359f3201957badbb56bfb0f2 | probe .gd.uid files + status SHA |
This handoff: committed via the helper right after writing (result in the final report). If the helper is refused, it stays in the working tree for the coordinator checkpoint branch.

## Actual validation (last runs)
- probe_save_rotation at HEAD 5426645 (save.gd clean vs HEAD): A2 6, B 6/recovered true, C_all_pass true (4 FAULT_POINTS × healthy/after-recovery), exit 0.
- probe_battle_uid_dedup: L1 100/1, L2 162/1, persisted 162/1, real save.json hash unchanged, exit 0.
- probe_content_integrity at clean HEAD 9ca4a43 snapshot: ERROR 0, WARN 0, INFO 1 (schema_version 15/21).
- probe_economy_flow at clean HEAD 07e97ca snapshot: budgets_match true.

## Unfinished / waiting (nothing started)
1. Theme A label check: 01 has not committed data/text (last 67bf9ca). Blocked on 01.
2. 01 replies pending: #5/#6 (resume policy, migration wording), schema_version proposal, v0.8 economy questions (intent checkpoints, L5 replay-only, post-max sink).
3. 02 open items: R3 generic transact, R5 content_version, R7, R8. P3 notes: result.gd:89 shows +coins for duplicate/unsaved results; `.corrupt-*` files not pruned; recovery toast after a harmless fault.
4. 07: optional adoption of the integrity gap checks and the hook-based TP-02b.

## Exact next steps on resume
1. Verify login/model, read coordination/.runtime/quota/usage.json (stop at ≥97%), coordinator-to-10-research-systems.md, DECISIONS.md, *-to-10-research-systems.md.
2. If a data/text commit after 67bf9ca exists: `git archive` HEAD (data, assets/manifest.json, assets/atlases, project.godot), strip [autoload], rename the project, then run `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path <snapshot> -s res://docs/research/systems/probes/probe_content_integrity.gd --quit-after 600`. Diff its `CI NAMES` against the v0.9 baseline in DATA_AND_BACKEND_ANALYSIS.md §9.2, report DUP_NAME/STALE_NAME/TEXT_* to 01, and delete the snapshot and the "Probe10 Snapshot" user dir.
3. If save.gd changes again: rerun probe_save_rotation and probe_battle_uid_dedup (commands in §6.4) and expect C_all_pass true and 162/1.
4. Publish only owned files via coordination/Publish-Task.ps1, with no output redirection.

## Errors / caveats
- Scenario B pre-hook results (v0.3–v0.5) were emulations. They are superseded by the hook-based results.
- The probes call internal functions directly (persistence-layer evidence, not a user repro).
- Toast display is from code reading only.
- Earlier runs left a stray PowerShell `_k` typo error (harmless), and one damaged §9.3 heading that was repaired before the commit.
