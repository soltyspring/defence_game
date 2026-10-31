# 10-research-systems → 01-director (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md. No user question requested now (Q1 pending).
1. Title identity: "궁수키우기" matches several Play apps (table §2: MADPLAY com.ohm1004.Defense "궁수키우기 RPG", JU-OK STUDIO, Kafra, Jong1, plus GameDuo "아처키우기" com.GameDuo.MadArcher). The analysis uses GameDuo as the provisional candidate. If you later confirm a different title with the user, only that row changes.
2. Proposed data file `data/migrations.json` (your ownership): ID renames and retirement refunds (§5.1 example). It is needed before the first post-launch rebalance.
3. Reversible defaults recommended (not user-approved): offline income stays disabled; no PvP in MVP; events ship by app update with low-value rewards; no account system (keeps the Play account-deletion requirement out of scope).
4. Decision needed later from 06's options: whether retention can be measured at all (see 10→06 #2).

## v0.3 (after account change)
5. Resume after the OS kills the app mid-round (09 E3): options are (a) no resume, the round is lost and progress stays safe (current), or (c) seed + command-log checkpoint (needs 02 R9, test TP-15). This is a design decision for you, not a user question now. Recommendation: (a) for MVP, and (c) only if the pilot shows interruption complaints.
6. Cloud/device migration: public complaints in 09's sample (royaldice device migration loss, MadArcher reinstall wiping a paid ad-removal) support two rules: entitlements always come from store restore, and the store text must not promise cross-device progress until L2 exists.

## v0.4 follow-up (~08:20 KST) — STATUS: no reply found yet
#5 (resume policy a/c) and #6 (entitlement and migration wording rules) are still open, and `data/migrations.json` does not exist. 07 reports TP-05 NOT_TESTED because of that file. These are not urgent before the save P1 fix (QA-B004). Please reply in coordination/requests/01-director-to-10-research-systems.md.

## v0.7 content-DB integrity (~08:57 KST)
Probe docs/research/systems/probes/probe_content_integrity.gd. Command, checks and results are in DATA_AND_BACKEND_ANALYSIS.md §9.2.
- Clean HEAD f88ce03: no data-side ERROR owned by you. There are 0 broken unit/skill/hero/text references, 0 duplicate IDs, 0 out-of-range values, and wave and round order are consistent. Your uncommitted working-tree round changes also pass (ERROR 0).
- The single HEAD ERROR (boss_overlord anim_set) belongs to 03's manifest. I sent it to 03.
- INFO (proposal, not a defect): 15 of 21 data files have no `schema_version` (order.json, the 3 skills, the hero, the 10 rounds). Recommendation: add `"schema_version": 1` per file, so the loader and a future `data/migrations.json` can tell content-format versions apart. Repro: run the probe and look for the `CI INFO VERSION` line.
- Suggest running the probe before each data commit. It is read-only and takes seconds.

## v0.8 meta-coin economy flow (~09:05 KST) — numbers for your review, no data edits by 10
Probe: docs/research/systems/probes/probe_economy_flow.gd. Read-only data arithmetic with no simulation, play time or retention.
Run: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_economy_flow.gd --quit-after 600`
Ran at HEAD 07e97ca. Your uncommitted round edits have identical reward blocks and scripted spawns, so the results apply to them too. Full tables are in DATA_AND_BACKEND_ANALYSIS.md §9.3.
Labels: [DATA] = data arithmetic, [RULE] = app.gd reward rule, [ASSUME] = 10's assumption, [INTENT] = ECONOMY.md text.

1. Your upgrade_budgets.json reproduces exactly: 20/20 round×scenario entries match on levels, spent_levels and leftover, with diff 0. Your ECONOMY.md totals also match the data: first clears 3,140, 3★ 780, sinks 6,280, 62.4%, replay = 30.0% of first clear in every round.
2. Max-out needs replays [DATA]: the deficit is 3,140 (LOW) / 2,360 (HIGH), which is 18 / 14 replays of r10 on replay coins alone. With the scripted-kill ceiling [ASSUME], it is 10 / 8.
3. The L5 tier is replay-only on the first-clear path [DATA+RULE]. Your greedy never reaches L5 on any track before r10 (LOW 23 levels, HIGH 27). The last-level costs sum to 2,740.
4. Forced-replay points vs your INTENT checkpoints:
| before | intent | LOW income | HIGH income | result |
|---|---|---|---|---|
| r03 | 240 | 240 | 340 | met / +100 |
| r05 | 660 | 640 | 860 | **LOW short 20 → 1 replay of r04 (66)** / HIGH +200 |
| r10 | 2,500 | 2,540 | 3,200 | met (+40) / +700 |
   Whether a replay is truly forced depends on win/loss without that upgrade, which is your sim's domain. This table only compares coins with your stated intent.
5. Surplus [DATA+ASSUME]: never during r01–r10. Remaining visible upgrade cost always exceeds the income upper bound (HIGH + scripted kills), e.g. 3,526 vs 6,280 before r10. A coin surplus with zero sinks starts only after maxing everything, around 11–18 r10 replays. After that, coins only pile up to the 9,999,999 cap. If you want replay rewards to stay meaningful after max-out, it needs a sink (chapter 2 or cosmetics); that is a design decision for you.
6. Kill coins vs your text [DATA]: ECONOMY.md says "kill gold ≈ 20–60 per round". The scripted spawns alone give 12 (r01) to 138 (r10, boss_overlord 60), and trickle adds more. Your budgets ignore kill coins (stated in the file). Adding the scripted ceiling moves the HIGH state before r10 from 27 levels/90 left to 28 levels/216 left (up_hero 3→4).
7. Early-round grinding is inefficient [DATA]: from zero, hero/supply/energy L5 needs 10 replays of r01; any level costs 1–2 replays of r10.
Requested: confirm or adjust the intent checkpoints, and decide whether the L5 tier is meant to be replay-only and whether a post-max sink is needed. 10 changed no data files.

## v0.9 theme A recheck (~09:12 KST, HEAD 9ca4a43) — STATUS: waiting for your name-label commit
- The coordinator recorded at 09:03 that Q1 is DECIDED by the user = A "빵집 기사단 vs 곰팡이 군단". HEAD docs/design/DECISIONS.md still shows Q1 PENDING; recording it is your step.
- Theme labels are NOT at HEAD yet. data/text/*.json last changed in 67bf9ca, and names are still neutral (보병/Troop, 궁수/Archer, 졸병/Grunt...). Your working tree changes units/heroes/skills/rounds but no text file. So there is nothing theme-related to check yet. The pre-theme baseline at HEAD is ERROR 0, WARN 0, INFO 1 (schema_version).
- New theme-rename checks were added to the probe (WARN, mutation-tested): DUP_NAME (two ids of the same kind with the same ko or en name) and STALE_NAME (a data `name` fallback that differs from the ko text of its `name_key`; the old name would show if the text table fails to load). The probe also prints a `CI NAMES` line with ko/en/fallback for all 26 ids, as a diffable baseline.
- Request: before you commit the theme labels, run
  `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_content_integrity.gd --quit-after 600`
  and expect exit 0 with no DUP_NAME or STALE_NAME lines. If you rename via text keys only, also update or empty each data `name` fallback, otherwise STALE_NAME fires for every renamed id. Please post the SHA in a 01-director-to-10-research-systems.md line; 10 will rerun at HEAD and report the before/after name diff.
