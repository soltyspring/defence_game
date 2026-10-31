# 10-research-systems handoff
Updated: 2026-10-31 ~17:56 KST · Session sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce · claude-opus-5.5 / trust-all, same session (reopened for window separation)

## RESUME after user restart (~15:38 KST)
- Read: this handoff, coordinator-to-10-research-systems.md (the QUOTA CHECKPOINT text is historical; I did not stop for it), 01-director-to-10-research-systems.md R1 (D17 schema_version, D19 no mid-round resume, #6 rules accepted, migrations.json in backlog).
- Lost-work check: working tree for owned paths is clean. `git diff HEAD origin/checkpoint/quota-20261031-092323/10-research-systems` shows no differences in docs/research/systems, my handoff or my status (the checkpoint commit 3a4fe47 holds the same content as main). No temp leftovers, no probe Godot processes. **Nothing lost.**
- An interrupted earlier resume attempt left nothing behind. It had only run the probe and a failed name diff (a PowerShell console encoding problem, fixed with UTF-8 output encoding).
- User decision: Q1 = A "빵집 기사단 vs 곰팡이 군단" (DECIDED by the user). HEAD DECISIONS.md still shows PENDING; 01 records it.
- Quota: 2278.54/10000 = 22.79% at 15:37.

## v0.22 (~17:56 KST): competitor public policies vs D26/R5 (no Godot)
- Coordinator decision: 18:00–18:30 KST is 08's quiet window; this task ran no Godot.
- §9.13 table a1–c6 from S27–S31. Random Dice help center scan: FAQ IDs 1–860 → 26 items, 0 about balance compensation or rollback. Excluded: Discord (login), fandom (unofficial, 403), cafe.naver.com/randomdice (fan cafe, clubid 29999506). Scratch in .local_inspect/hs/ (git-ignored).
- To 01: D26 refund needs a paid-cost source; proposed a per-buy paid record plus retired_costs; no clawback rule; store note rule. To 02: same contract, idempotent once-per-content_version migration, plus an acceptance case.
- Next after 18:30: rerun C6 (F1 fix 4b5926d) in a clean snapshot; rerun the economy table only when 01 commits r02–r06; R5 acceptance when 02 lands content_version.

## v0.21 (~17:41 KST): economy yardstick + menu toast recheck
- probe_economy_policies.gd + run_economy_policies.ps1 (default: working-tree data; `-Rev HEAD`). At HEAD 40382b0: P0 2,540 unspent before r10; P1 24 levels, card−enemy negative from r06/r08; P2 29 levels, negative from r09. One-line command written in the 01 request.
- probe_toast_series.gd via visible_launch on DISPLAY2 (HEAD 8302f5d, not locked): a menu toast changes 0 px over 2.2 s; only hud.gd/fallback_hud handle toasts. Verdict: a missing display path, not timing. Reported to 04. Corrected my §6.4 claim that the recovery toast notifies the user.
- F1 still waiting.

## v0.20 (~17:36 KST): a262640 recompute + upgrade panel screen check
- Economy before (c1ce3f5) vs after (ee30b9d): cost 6,280→5,595, LOW/HIGH r10 replays 18/14→14/10. L5 per-100-coin efficiency 2.9–5.4 → 3.8–7.6; ranged/fast L5 now beat L4. 01 request sent.
- probe_upgrade_ui.gd run via 04 visible_launch on DISPLAY2 (HEAD 8104970 snapshot): 5 cases, text and coins match Save. P3 notes (stale menu wallet behind the modal, save_failed toast not visible, uncertain reuses the save_failed toast) sent to 04. Evidence in docs/research/systems/evidence/upgrade_ui_8104970/.
- F1: not fixed (save.gd last 4d77225). Waiting; 02 note added.
- Scratch outputs are in docs/research/systems/.local_inspect (git-ignored) because %TEMP% files vanished.

## v0.19 (~17:22 KST): buy_upgrade C1–C13 automated
- probe_upgrade_transaction.gd: part E (C6–C13, C5b) and a 120 s watchdog. Run at a clean origin/main ed7218a full snapshot: 14/14 PASS (2.0 s).
- F1 (P3): in the after-recovery state, an after_tmp_write failure returns save_failed but the .tmp is adopted on reload (440/L2). Sent to 02.
- R5 D still fails. Temporary "no max_level decrease after launch" rule proposed to 01. Measurement method sent to 07.
- My own measurement bug: the C13 revision_delta was computed too late. Fixed and reran. Doc §9.10.

## v0.18 addendum (~17:30 KST)
- buy_upgrade landed (02 4d77225). probe_upgrade_transaction at a clean HEAD 0478edd snapshot: C1–C5 PASS. R5 part D still fails. Next: automate C6–C13 in the probe.

## v0.18 (~17:21 KST): engine durability verdict + competitor device-change policy
- Exact engine: `--version` 4.7.2.stable.official.ed1daf0bf. The tag 4.7.2-stable resolves to commit ed1daf0bf001b61586d9930840f2f1394092c079 (GitHub API).
- Q1 No sync before rename (flush=fflush L329–332, close=fclose, rename=::rename; 0 fsync hits). Q2 Android user:// = FileAccessUnix/DirAccessUnix (os_android.cpp L120/L133). Q3 flush yes (not durable), fsync no; save_and_swap is off and unused.
- 02: no change needed to the current order. Proposals: A time-spaced .bak rotation, B coalesce saves, C native fsync (not recommended). 06: B1 backup rules unchanged (new request file section).
- Competitors (public docs only): Random Dice Helpshift account FAQ (cross-platform login, one store account per game account, no transfer for simple device change, does not keep platform account info). GameDuo company terms (guest = temporary member; device change or app deletion → no recovery as an "example" clause; whether it applies to Archer Forest is unknown). Doc §9.9, sources S23–S26.

## v0.17 (~17:06 KST): save atomicity check before buy_upgrade
- save.gd at HEAD c15e43a was read only. It writes tmp → flush → verify → rotate or quarantine → rename, and loads main → tmp → bak → fresh. Version is read from the payload; the envelope version is ignored.
- probe_save_load_cases.gd: 14 cases (zero-byte, truncated, checksum, non-object, tmp newer, torn tmp, all corrupt, >2 MiB, v99 read-only, envelope-only 99, legacy no version, BOM, plain JSON, fresh). No loss except all-corrupt (fresh + recovered). My first L03/L09 constructions were wrong; fixed and reran.
- Android: Godot master flush = fflush only, no fsync (S21). AtomicFile syncs (S22). Power-loss loss is expected to be the last save or two via .bak. Device test NOT done.
- Extra acceptance C6–C13 sent to 02 and 07. Doc §9.8, sources S21/S22.

## v0.16 (~16:56 KST): chapter-1 coin flow + cost/effect bend
- User decisions: Q3 working title "빵집 기사단: 곰팡이 디펜스" (16:19). Q2 on hold, so there is no paid or ad currency in the model.
- Wait check: 22d99ea is in HEAD. No buy_upgrade/content_version in src, so C1–C5 and R5 are still pending.
- probe_economy_flow extended: chapter-1 end state, per-track r10 replays to max, monetization flag check, intent constant updated to D22 640. probe_upgrade_effect rerun (data unchanged since ea16a8e).
- Results: LOW end 27 levels / 3,170 to max / 18 r10 replays; HIGH 30 / 2,510 / 14. No coin pile-up during r01–r10. Cost/effect per 100 coins halves at L2→L3; L5 is lowest (2.9–5.4); siege L5 is worst. 01 request with tables sent. Doc §9.7.

## v0.15 (~16:41 KST): content version change vs existing saves
- New probe docs/research/systems/probes/probe_content_migration.gd plus driver run_content_migration.ps1. It works in throwaway HEAD a9223df snapshot copies with mutated data and a %TEMP% legacy save fixture.
- Results: M1 round removal skips ahead (r08 unlocked) and drops chapter stars 14→12. M2 insert locks r07. M3 swap has no effect here. M4 max_level 5→3 keeps L5 (hp 1.32), no refund. M5a unit rename is safe. M5b upgrade rename orphans the level and loses the bonus. Coins are never changed; unknown keys are kept.
- Minimal R5 contract (fields content_version and migrations_applied, ID-based unlock rule, migrations.json shape, refund rule, atomic order, acceptance values) sent to 02. Decisions requested from 01. TP-05 driver sent to 07. Doc §9.6.
- The first driver run aborted (PS5 turns native stderr into an error under `Stop`). Fixed with `Continue` and reran clean.

## v0.14 (~16:26 KST): upgrade effect curve
- User decision recorded: Q2 monetization = 보류 ("수익모델은 보류"). The economy is reviewed as clearable without monetization.
- New probe docs/research/systems/probes/probe_upgrade_effect.gd (real BattleSim setup/deploy/_spawn_enemy/income + `_damage` formula), run at a clean HEAD ea16a8e snapshot without autoloads, exit 0.
- Findings: unit L5 +32%, hero/base +40%. siege atk has 0 effect vs small enemies. Energy regen gives no extra casts for Rally/Barrage alone. Supply (flat) vs worker (per worker) tracks: worker wins at ≥2 workers. The LOW path is slightly ahead of enemy scaling in r03–r07 and slightly behind in r08–r10. L5 creates hit-count breakpoints vs some common enemies. The first r01 play is always at L1, so QA-J2 is a data question.
- 01 request sent with the summary table. Doc §9.5.
- Standby: Save.buy_upgrade not at HEAD; rerun probe_upgrade_transaction when it lands.

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
