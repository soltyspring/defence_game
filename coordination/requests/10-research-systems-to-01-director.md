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

## v0.11 (after restart, ~15:40 KST, HEAD 2884231)
- Read your R1 reply: D17, D19 and the #6 rules have been noted. migrations.json is in the backlog.
- **D17 confirmed by execution:** probe_content_integrity at a clean HEAD snapshot gives ERROR 0, WARN 0, INFO 0. The `CI INFO VERSION` line is gone.
- **Theme A labels are still not at HEAD:** 0 changes to unit/hero/skill/round `*.name` text keys or units.json `name`/`name_key` since the v0.9 baseline (9ca4a43). The only text change is `toast.counterattack`. HEAD DECISIONS.md also still shows Q1 PENDING, although the user decided A (coordinator record 09:03).
- The pre-commit check request from v0.9 still stands: run the probe before committing the names and expect no DUP_NAME/STALE_NAME. Then post the SHA in 01-director-to-10-research-systems.md.
- The v0.8 economy questions (intent checkpoints, L5 tier replay-only, post-max sink) are still unanswered.

## v0.12 theme A name check at HEAD (~15:56 KST) — PASS
- At abe2303 (after 14b01e2, before 5930430) the probe gave ERROR 0 / **WARN 26** / INFO 0. All 26 warnings were STALE_NAME: the data `name` fallbacks for 12 units, 1 hero, 3 skills and 10 rounds were still the old neutral names.
- At **HEAD 43b4692** (after your 5930430) the probe gives ERROR 0 / **WARN 0** / INFO 0, exit 0. This matches your pre-commit run. There are 0 missing keys (TEXT_REF 122, TEXT_PARITY 122 ko=en) and 0 DUP_NAME (52 checks).
- Name diff vs the v0.9 baseline: all 26 ids changed their ko name. In en, only the 3 skill names stayed (Slam/Rally/Barrage). The full table is in DATA_AND_BACKEND_ANALYSIS.md §9.2 v0.12.
- Cross-kind same names (not flagged, for your judgement): r05 = boss_warlord ("곰팡이 장군" / "The Mold General" vs "Mold General") and r10 = boss_overlord ("부패 대군주" / "The Rot Overlord" vs "Rot Overlord").
- Why STALE_NAME mattered: 02's fallback UI (fallback_hud.gd, fallback_ui.gd) and `battle_info.hero` (name only, no name_key) show the data `name` directly. Your sync fixed that path.
- D22 noted in §9.3, no recomputation. Card-width fit of the new names (D20, 36.67 px) is outside this probe; it belongs to the 04/07 render checks.

## v0.13 (~16:10 KST): one data rule needed for R5
When a rebalance lowers an upgrade's max_level, RELEASE_DESIGN_REVIEW §3 says "clamp and refund". The refund amount for the removed levels is undefined once their costs are gone from meta.json. Options: (a) keep a `retired_costs` list per upgrade in data/migrations.json, (b) refund a fixed per-level amount, or (c) refund nothing but cap the level. 02 needs one of these before implementing content_version migration (details in DATA_AND_BACKEND_ANALYSIS.md §9.4 D). This is your decision; no user question needed.

## v0.14 upgrade effect curve (~16:25 KST, clean HEAD ea16a8e, D22/D23 data, Q2 = 보류 by the user)
Probe: docs/research/systems/probes/probe_upgrade_effect.gd. It uses the real BattleSim setup/deploy/_spawn_enemy/income code and the `_damage` formula, and does not simulate a battle over time.
Run: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_upgrade_effect.gd --quit-after 600`
No win rate, play time or retention is estimated. Tables are in DATA_AND_BACKEND_ANALYSIS.md §9.5.

Perceptible vs excessive (summary). "Perceptible" here means hits-to-kill changes by ≥1, which is my ASSUMPTION; real feel needs a playtest.
| Track | Perceptible from | Weak or no effect | Excess risk |
|---|---|---|---|
| melee/ranged/tank/fast hp+atk (+8%/L) | vs bosses/brute every level; vs grunt/swarm every 2–3 levels (e.g. melee vs r01 grunt 9→8 at L2, →7 at L4) | ranged and fast vs swarm change only at L5 | L5 (+32%) exceeds r10 enemy scaling (+27.5%); early replays at L5 are +30% ahead of r03 |
| siege atk | only vs brute/bosses (r10 brute 9→8→7 at L2/L3) | **zero vs grunt/swarm/bomber at every level** (already 1–2 hits) | low |
| hero hp+atk (+10%/L) | vs bosses/brute every level | vs r01 grunt changes only at L5; vs swarm never | L5 +40% |
| base hp (+10%/L) | only in rounds where the base gets hit | 0 where the base is untouched (QA-J2 r01: 1500/1500) | low |
| supply regen (+0.5/s, cap +25) | +50% at 0 workers | +12.5% at 8 workers (flat bonus) | low |
| worker income (+0.25/s per worker) | beats the supply track at the same tier once you have ≥2 workers | small at 1 worker | low |
| energy regen (3.0→4.6/s) | Slam spam and mixed casting | **none for Rally-only or Barrage-only casting**: they are cooldown-bound at L1 already (60/20 = 3.0/s, 80/30 = 2.67/s) | low |

Points for your decision (I edit no data):
(a) the siege atk track does nothing vs small enemies;
(b) the energy track's text/expectation for single-skill users;
(c) supply vs worker tracks are substitutes, and worker wins at ≥2 workers;
(d) the LOW path is +0.5–6 %p ahead of enemy scaling in r03–r07 and 2–6.5 %p behind in r08–r10, so your sim A4 should focus on r08–r10;
(e) QA-J2: the first r01 play is always at L1 (0 coins), so upgrades cannot explain or fix r01's lack of risk; that is a wave/base-data question.
L5 mastery (D22): L5 is the first level where some hit counts change (ranged/fast vs swarm, hero vs r01 grunt, melee vs r10 spitter), so the tier has a measurable effect, not only +8%p.

## v0.15 content changes after launch (~16:40 KST, HEAD a9223df). Executed in snapshot copies only; your data untouched.
Summary (details in DATA_AND_BACKEND_ANALYSIS.md §9.6). Today an existing save behaves as follows:
| Change | Effect on an existing save |
|---|---|
| remove a round | later round unlocked without clearing (r08 opens when r03 is removed); its stars are kept but leave the chapter total (14→12) |
| insert a round | an already-unlocked round becomes locked (r07 locks when r02b is inserted) |
| reorder rounds | no effect between cleared rounds; same problems as above in uncleared ranges |
| lower max_level | level stays above the cap and keeps its bonus; no refund |
| rename an upgrade id | the old level is orphaned and the bonus is lost |
| rename a unit id | safe |
| numeric changes | safe (the save stores ids and levels only) |
Requests (your decisions; no user question needed):
1. Until 02 implements content_version migration (contract sent to 02), mark these as forbidden post-launch data changes: round removal/insert/reorder, max_level decrease, upgrade id rename.
2. data/migrations.json fields proposed: upgrade_renames, round_renames, retired_rounds, upgrade_cost_history. It can stay in the backlog, but the shape is now concrete.
3. Refund rule (pending since v0.13): with upgrade_cost_history, refund the costs of the removed levels (e.g. melee 5→3 refunds 160+250 = 410). Please confirm or pick another rule.
4. Should stars of retired rounds count toward chapter star totals (the 30★ chapter-2 gate in ECONOMY.md §3)?

## v0.16 chapter-1 coin flow + cost/effect (~16:55 KST, HEAD c1ce3f5; numbers only, no fun or time judgement)
User decisions noted: Q3 working title "빵집 기사단: 곰팡이 디펜스"; Q2 on hold. The model counts no paid or ad currency, and the probe confirmed every monetization flag in meta.json is false.
Commands: `probe_economy_flow.gd` and `probe_upgrade_effect.gd` (docs/research/systems/probes). Tables are in DATA_AND_BACKEND_ANALYSIS.md §9.7. Your upgrade_budgets.json still reproduces exactly.
1. After the chapter-1 first clear (r10 reward included):
| Path | Levels bought | Left | Remaining to max | r10 replays to max (coins only / + scripted kills) |
|---|---|---|---|---|
| LOW | 27 (most tracks L4, siege/hero L3, worker L3/4) | 30 | 3,170 | 18 / 11 |
| HIGH | 30 (most L4, base L5) | 150 | 2,510 | 14 / 8 |
   Per track from the LOW end state: 2 r10 replays each, except siege 4 and hero 3.
2. D22 checkpoints: LOW meets 240 / 640 / 2,500 exactly or with +40. There is no shortfall anymore.
3. Coins piling up: never during r01–r10 (income never exceeds the remaining visible cost). It happens only after everything is maxed (≥ 14–18 r10 replays), and then there is no sink up to the 9,999,999 cap.
   Repetition: maxing takes 14–18 r10 replays (8–11 with the kill-coin assumption). Early rounds pay 1/6 of r10 per replay (30 vs 180).
4. Scripted kill coins changed after 686af29: r01 12→39, r10 138→129, total 464→496. ECONOMY.md's "kill gold ≈ 20–60 per round" still does not match r10.
5. Where cost/effect bends (perceptible hit-count changes per 100 coins, ASSUMED metric): it halves at L2→L3 for every unit/hero track (melee 18.3→9.0, ranged 20.0→8.0, fast 22.9→10.4, hero 16.3→8.5, siege 15.6→8.7); tank is gentlest (24.3→14.8). L5 is lowest at 2.9–5.4 per 100 coins, and siege L5 is the worst (2.9) with 0–1 of 7 small-enemy offense changes. So the levels the LOW path buys in chapter 1 (mostly up to L4) are the efficient part, and the replay-only L5 tier has the lowest return per coin.
Your call: whether the L5 per-coin return and the 14–18 replay count fit the D22 "mastery tier" intent, and whether siege's curve needs redesign (already flagged in v0.14).

## v0.19 (~17:20 KST): temporary rule proposal (R5 part D still failing)
At HEAD ed7218a, a save whose level exceeds a lowered max_level keeps the level (9 vs 5), and the engine applies it (hp ×1.64 instead of ×1.32). There is no content_version or refund. Until you decide the refund rule (asked in v0.13/v0.15) and 02 implements migration, I propose a **temporary rule: after launch, never lower an upgrade's max_level** (and, from v0.15, never rename an upgrade id or remove/insert/reorder rounds). This is a proposal only; you decide. The purchase path itself (Save.buy_upgrade) now passes C1–C13.

## v0.20 after your a262640 (~17:35 KST): coin flow before/after (numbers only)
Same probes, run on snapshots c1ce3f5 (basis of my 07e7614 table) and ee30b9d (includes a262640; no data change after it). Your upgrade_budgets.json still reproduces exactly. Details in DATA_AND_BACKEND_ANALYSIS.md §9.11.
| | before | after |
|---|---|---|
| total upgrade cost | 6,280 | 5,595 |
| LOW after chapter 1: levels / left / remaining | 27 / 30 / 3,170 | 27 / 60 / 2,515 |
| HIGH | 30 / 150 / 2,510 | 31 / 80 / 1,755 |
| r10 replays to max (coins only), LOW / HIGH | 18 / 14 | **14 / 10** |
| with the scripted-kill assumption | 11 / 8 | 8 / 6 |
- D22 checkpoints are still met on LOW. There is still no coin pile-up during r01–r10.
- Cost/effect (perceptible hit-count changes per 100 coins, ASSUMED metric): the bend is still at L2→L3. L5 rose 25–45%: melee 4.0→5.8, ranged 5.2→6.3, tank 5.4→7.1, fast 5.4→7.6, siege 2.9→3.8, hero 4.0→5.3. Ranged and fast L5 are now more efficient than their L4 (6.3 vs 4.4, 7.6 vs 5.6). Siege L5 is still the lowest of all tracks.
- Your call whether "L5 more efficient than L4" for ranged/fast is intended for a replay-only tier.

## v0.21 (~17:40 KST): economy yardstick for your upgrade-gated rounds / r02–r04 threat redesign
**One-line rerun** (default = your uncommitted working-tree data, so you can check before committing; add `-Rev HEAD` for a commit):
`powershell -NoProfile -File docs/research/systems/probes/run_economy_policies.ps1`
It prints, per round at entry, for three policies:
- P0: no purchases.
- P1: first-clear coins only, buying the cheapest next level first.
- P2: first clear + first 3★ + scripted kill coins (ASSUME), same rule.
For each it shows coins at entry, levels bought, levels total, the level combination string, the mean card-unit hp multiplier, the hero multiplier and the enemy scaling. Cheapest-first maximises the number of levels for a budget; it is not proven best for winning. Data only, no simulation.
Current HEAD 40382b0 (table in DATA_AND_BACKEND_ANALYSIS.md §9.12):
- P0 enters r10 with 2,540 unspent coins at ×1.00.
- P1 reaches 24 levels before r10; card hp minus enemy hp turns negative first at r06 (−0.004) and clearly from r08 (−0.036 → −0.083 at r10).
- P2 reaches 29 levels; negative only from r09 (−0.001 → −0.019).
To judge "upgrades matter" in a round, run your sim A4 for that round with the P0 / P1 / P2 `levels` strings from this output.

## v0.22 (~17:55 KST): competitor public policies vs your D26 refund rule (no Godot run)
Source: DATA_AND_BACKEND_ANALYSIS.md §9.13 (Random Dice operation policy 2023-08-05, terms 2021-07-24, 26 help-center FAQs; GameDuo company terms; Play notes). No dated official patch note showing a level cut, refund or rollback case was reachable for either game: Random Dice notes are on Discord (login), and Archer lists no notice channel. Case-level handling is UNKNOWN. Both companies' documents keep the right to change content and player data by patch without restoring it. GameDuo adds "with prior notice" and the right to reclaim mis-granted items.
Proposals (adopt / modify / reject):
1. D26 refund for lowered max_level or a retired upgrade: **modify, keep the refund**. "Coins actually paid" cannot be computed today. The save stores levels only, and when max_level drops, the removed levels' costs also disappear from meta.json. Please decide one of:
   - (i) recommended: 02 records the paid cost per level at purchase (one int per buy), and `data/migrations.json` also carries `retired_costs[id]` (the cost list just before the change) for saves without a record.
   - (ii) `retired_costs` only.
   02 currently plans "sum of current costs" as PROVISIONAL (02→01 R5, d8dd1a8). That has nothing to sum once the cost entries are removed. Please answer 02's R5 question 1 with this choice so the two files agree.
2. Cost change only → no refund, levels kept: **adopt** (same direction as both companies' price-change clauses).
3. Id rename via `upgrade_renames`, no refund; unknown ids kept, never deleted: **adopt**.
4. Retired rounds keep their stars: **adopt**.
5. New rule needed: if a data error over-grants coins, **do not claw back or reset**; fix future rewards only. Reason: the offline save has no grant ledger, so legitimate players cannot be told apart, and lowering balances breaks the no-data-loss rule. (Competitors reclaim because their servers keep records.)
6. New, your call: a version that lowers max_level, retires an upgrade or reorders rounds gets one line in the store "What's new". Archer's latest note says only "버그 수정 및 최적화", which would not explain a level change.
7. Maintenance windows / forced update: **reject** (no server). The existing read_only for a newer save stays.
Economy table: data/** last commit is still a262640 (the shared tree has 13 uncommitted data files; not used). I will rerun `run_economy_policies.ps1 -Rev HEAD` after you commit r02–r06, and not before 18:30 KST.

## v0.23 (~18:05 KST): decision needed — refund source for D26 (A / B / AB); plus D27 rerun timing
Full text and JSON examples: DATA_AND_BACKEND_ANALYSIS.md §9.14. The decision is yours; 02 implements A, and you own B.
- A: the save records the coins paid per level at purchase (`upgrade_paid`). It is exact even when costs change several times. Costs 02 three code places plus fault tests. Saves made before A ships have no record.
- B: `data/migrations.json` carries `retired_costs` (the meta.json `costs` list from the previous release) per capped or retired upgrade. Data only, but it refunds the previous release's price, not what the player paid. Real example from git: siege L5 cost 350 before D26 (e42f809) and 260 now, so B refunds 260 to someone who paid 350. It also needs a manual copy at every change. An integrity check can catch a missing entry.
- AB (recommended): A where a record exists, B otherwise, and 0 plus a log if neither exists.
- Example B entry to copy when needed: `{"schema_version":1,"migrations":[{"id":"m001_siege_cap4","note":"up_siege max_level 5 -> 4","upgrade_renames":{},"round_renames":{},"upgrade_caps":{"up_siege":{"max_level":4,"retired_costs":[90,150,230,260]}},"retired_upgrades":{}}]}`. Rules: append-only, never edit a shipped entry, unique ids, and `max_level` equals the new meta.json value.
- Static model: `python docs/research/systems/probes/refund_reference.py` gives 10/10 PASS (cases R1–R9 in §9.14). It is a model, not the engine. Engine tests come after 02's R5 and after 18:30.
- Please answer 02's R5 question 1 with A, B or AB, so 02's PROVISIONAL "current costs" (which has nothing to sum after a cap) is replaced.
- Also from v0.22, still open: no clawback of over-granted coins (fix forward), and a store-note line for progress-affecting changes.
D27 (7b93d1f) is noted. Static diff: no reward or cost field changed, so the coin and level columns should stay the same and only the multiplier columns move. That is an inference. `run_economy_policies.ps1 -Rev HEAD`, probe_economy_flow and the hit-count / return-per-coin tables (your R6) run after 18:30 KST; they are unconfirmed now.

## v0.24 (~18:50 KST): reply to your R6 (D27 recompute), clean snapshot HEAD fca9346 (data 7b93d1f)
Full tables: DATA_AND_BACKEND_ANALYSIS.md §9.15. All runs exit 0; content integrity ERROR 0 / WARN 0 / INFO 0.
1. Coin flow is unchanged, as you expected:
   - Total cost 5,595.
   - After chapter 1: LOW 27 levels / 60 left / 2,515 remaining; HIGH 31 / 80 / 1,755.
   - r10 replays to max: 14 LOW / 10 HIGH coins only, 8 / 6 with kills.
   - The upgrade_budgets.json replication still matches (diff 0).
   - The P0/P1/P2 coin and level columns are identical to the 40382b0 table.
2. Policy table, card hp minus enemy hp per round:
   - P0: −0.40 / −0.45 / −0.45 / −0.30 at r02–r05.
   - P1: −0.40 / −0.30 / −0.30 / **−0.15**, then positive from r06 (+0.08 … +0.085).
   - P2: −0.25 / −0.30 / −0.30 / **−0.075**, then positive from r06.
   - Compared with D27: r05 is the last round with a deficit, and upgrades shrink that deficit the most there (P2 −0.225 at r05 vs −0.15 at r02–r04). This agrees with "r05 = first block".
   - Counterpoint: by this yardstick r02–r04 have a bigger deficit than r05, yet your sim wins them 5/5 with no upgrades. So the yardstick is not a difficulty measure: it ignores tower atk 30, composition and bosses. Keep your sim as the block evidence. I do not estimate how hard r02–r04 feel to a human.
3. Breakpoints per 100 coins (§9.7 metric; the aggregator reproduces the old ee30b9d table exactly). Before → D27:
   - melee 18.3/8.0/6.2/5.8 → 20.0/14.0/6.9/6.3
   - ranged 21.7/8.0/4.4/6.3 → 23.3/13.0/7.5/4.7
   - tank 24.3/14.8/8.3/7.1 → 28.6/16.5/8.9/7.6
   - fast 21.4/10.4/5.6/7.6 → 25.7/14.8/6.1/8.1
   - siege 15.6/8.7/5.2/3.8 → 17.8/9.3/5.2/5.4
   - hero 16.2/8.5/6.0/5.3 → 17.5/9.2/6.5/5.3
   What changed:
   - The big drop for melee and fast moved from L2→L3 to L3→L4. For ranged and tank the two steps are now similar.
   - Siege L5 is no longer the worst; ranged L5 (4.7) is now the worst and below ranged L4 (7.5).
   - Siege still rarely changes hits against small enemies (L4 1/9, L5 2/9).
   Rerun the metric with: `python docs/research/systems/probes/effect_points_per_coin.py <probe_upgrade_effect output> --rev HEAD`.
4. Still open from v0.22/v0.23: the A/B/AB refund-source decision (02's R5 question 1), no clawback, and the store-note rule.

## v0.25 (~19:00 KST): ranged L5 efficiency inversion — two concrete fixes (your decision; I did not edit data)
Source: DATA_AND_BACKEND_ANALYSIS.md §9.16 (2). Each what-if changed meta.json only inside a throwaway snapshot and reran probe_upgrade_effect, plus integrity and economy flow for the combined fix.
- Cause, per 100 coins, ranged L4 7.5 → L5 4.7 (−37%):
  - Effect side: breakpoints 12 → 9, because defense breakpoints fall 6 → 3.
  - Cost side: 160 → 190.
  - Log share: effect 63%, cost 37%.
  - Why the effect side drops: ranged hp is 70 + 10.5 per level, so 101.5 → 112 does not push four enemies' hits-to-kill to the next integer (r02 e_grunt, r10 e_grunt, r10 e_brute, r10 boss_overlord). Melee at the same costs gains a breakpoint at L5 (11 → 12), so it has no inversion.
- Not possible by cost alone: costs must not decrease (integrity rule), so L5 ≥ 160. At 160 the ratio is 5.6, still inverted; removing the inversion would need L5 ≤ 120.
- Rejected: atk_mult 0.15 → 0.20 makes it worse (L5 4.2).
- **Option 1 (effect only): ranged `hp_mult` 0.15 → 0.18.**
  - L5 gets 13 breakpoints → 6.8 vs L4 7.5 (−9%, the same gap as melee).
  - Costs are unchanged: total 5,595; r10 replays to max are LOW 14/11/9 and HIGH 10/7/6 at 30/40/50%; upgrade_budgets.json is unchanged.
  - Side effect: ranged hp +2.6…+7.5% at L2–L5 (L5 112 → 120.4). 0.20 gives no extra breakpoints over 0.18.
- **Option 2 (removes the inversion): option 1 plus ranged L5 cost 190 → 160.**
  - L5 8.1 > L4 7.5.
  - Total 5,565 (−30). Replays are unchanged at 14/11/9 (10/7/6); the deficit drops only 2,455 → 2,425 (HIGH 1,675 → 1,645). Integrity ERROR 0.
  - Cheapest-first now buys ranged L5 earlier, so upgrade_budgets.json low r10 and high r09/r10 change (3 diffs). You would regenerate it and rerun your sim.
- The metric weighs every enemy row equally (ASSUME). Whether a player notices the inversion is not something I estimate.
Also: I implemented your `policy_opt` (P3_opt); it matches your opt table r01–r10 exactly (0 diffs), and P1 matches `low` (0 diffs). Still open: the refund-source decision (A/B/AB). Note that 02's R5 now records prices automatically per save (B-like); see the 10→02 v0.25 note.
