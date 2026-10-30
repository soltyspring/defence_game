# 01-director handoff — CHECKPOINT for account change
Updated: 2026-10-31 +09:00. The user stopped all project work for an account change. No new work after this file.
Session ID: not visible to this agent (Kiro does not show it in-session). Model claude-opus-5.5. The accepted effort level is unverified.

## User decisions
None. Q1 (theme) is still unanswered and is the only open question. Options: A 빵집 기사단 (recommended) / B 도토리 숲 수비대 / C 등불 수호자. All D1–D12 are DEFAULT, not user-approved. Q2 has not been asked.

## Current task when stopped
Balance diagnosis of 02's R2 report (bot loses r04–r10), per the coordinator C07 note.

## Findings with evidence (engine runs, 02's unmodified battle_sim.gd + bot_player.gd)
1. 02's "r03–r09 cards/skills [null]" report is STALE or an artifact. A byte-exact Python check of committed r01–r10 at e42f809 and HEAD shows explicit lists and no nulls. Nothing was rewritten.
2. The armor doc conflict is already resolved: IMPLEMENTATION_BRIEF §4 says flat since commit e42f809, and grep finds no 100/(100+armor) formula. 02's caps note (30/40) is stale: game_config.json has 36/36/64/48/24.
3. Spawn double counting: the engine runs BOTH `trickle` AND `enemy_ai` (random AI with income). I intended trickle to replace the AI. Observed spawns were 1.3–1.8× the designed waves + trickle (02 report stats_11 vs computed schedule).
4. Paired sim (docs/design/balance/paired_sim_2026-10-31.json, 120 runs, configs A baseline / B upgrades LOW / C AI off / D AI off + LOW, seeds 11/22/33): r01–r03 win in all configs; r04–r10 lose in all configs. Disabling the AI and adding upgrades alone does NOT fix r04+.
5. Probe and confirm runs (probe_sim / confirm_sim json, D + scaling variants, 3 seeds): with enemy_scaling = 1.0, r04, r06, r08 and r09 become wins; r05, r07 and r10 still lose. Half scaling only rescues r06 and r08. Forcing max workers did not help. Seeds give identical results when the AI is off, so the sim is deterministic and 3 seeds add no variance.
6. Analytic power ratio (enemy strength/s vs a 3-worker melee economy at LOW upgrades): 0.44 → 0.77 at r04, then 1.3–1.9 for r06–r10. The jump at r04 and r06 is large. It is an estimate only.
7. The bot never buys more than 3 workers (bot_player wants 5, but its reserve logic stalls) and has no upgrades in 02's selftest. The bot policy is not representative of the intended progression; reported to 02 below.
8. Upgrade budgets (docs/design/balance/upgrade_budgets.json): greedy cheapest-first with first-clear coins gives LOW 0/1/4/6/9/12/15/18/21/23 levels before r01…r10.

## Files
Completed (committed in this checkpoint if the helper succeeds; see Git): docs/design/balance/upgrade_budgets.json, paired_sim.gd.txt, paired_sim_2026-10-31.json, probe_sim.gd.txt, probe_sim_2026-10-31.json, confirm_sim.gd.txt, confirm_sim_2026-10-31.json, this handoff.
**UNFINISHED / WIP, NOT committed:**
- data/rounds/r01..r10.json: `enemy_ai` disabled (pool [], income 0; old pool/income kept as disabled_*). UNVERIFIED: the engine verification run was interrupted before reporting. **WARNING: this change is in the shared working tree, so any 02/07 engine run now loads it.** If unwanted, the owner (01) must restore it from HEAD after login.
- docs/design/balance/verify_files.gd.txt (the verification script; it never completed).
- The r*.json notes cite docs/design/BALANCE_DIAGNOSIS.md, which does NOT exist yet.
- A Godot process from the interrupted verify run may still be running. I did not touch it.

## Validation
Done: locale regression after these edits: keys ko 109 / en 109, placeholders and coverage ALL_OK=True. Paired, probe and confirm engine runs exit 0.
Not done: engine load and passive-must-lose check of the edited rounds; any balance retune; 02/07 paired test request; BALANCE_DIAGNOSIS.md.

## Exact next steps after login
1. Rerun: `copy docs\design\balance\verify_files.gd.txt $env:TEMP\verify_files.gd`, then `tools\engine\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s $env:TEMP\verify_files.gd -- $env:TEMP\verify_out.json`. Require: no content warnings and passive_all_lose=true. If it fails, restore data/rounds from HEAD.
2. Write docs/design/BALANCE_DIAGNOSIS.md (findings 1–8).
3. Send paired scenarios to 02/07: same seed and upgrade levels, AI on/off, scaling 1.0/0.5/data, bot with workers fixed at 3/5/max. Ask 02 to make trickle replace enemy_ai when present (contract) and to fix the bot's worker stall.
4. Retune only on evidence: enemy_scaling first (r04, r06, r08, r09), then r05/r07/r10 specifically (boss and bomber). Rerun the confirm configs.
5. Commit/push each piece via Publish-Task.ps1 without output redirection.

## Git
Earlier: e42f809, ec657bc, abdb664, 4cd16ee, f8823ac, e07b7a3, 3e7025e, all PUSHED origin/main.
This checkpoint: see the line appended below.
- Checkpoint commit 0130c21f7499d7bac92e51d2a1ff505774298be8 "[Docs] 계정 변경 전 밸런스 진단 체크포인트와 시뮬레이션 근거 저장" (8 files) → PUSHED origin/main. The first attempt failed the helper's diff check (blank line at EOF) and left those 8 own files staged. I unstaged only those files with `git restore --staged`, which leaves the working tree untouched, fixed the EOF and re-published. The index was empty afterwards.
- NOT committed (WIP, unverified): data/rounds/r01..r10.json (enemy_ai disabled), docs/design/balance/verify_files.gd.txt. Left for the coordinator checkpoint branch.
- This final handoff line itself is uncommitted. Status: STOPPED, waiting for the user's new-account login.
