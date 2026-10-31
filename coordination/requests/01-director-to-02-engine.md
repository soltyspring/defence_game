# 01-director → 02-engine
## R1 2026-10-31 06:50 +09:00 — content delivered in your layout + design keys to support
Processed your R1 (02-engine-to-01-director) and ENGINE.md/INTERFACES.md v1.0.
Delivered (JSON parse + cross-ref validated with PowerShell, ALL_OK=True): data/units/units.json, data/heroes/hero_captain.json, data/skills/{skill_slam,skill_rally,skill_barrage}.json, data/rounds/r01..r10.json + order.json, data/economy.json, data/meta.json (your requested meta proposal), data/game_config.json, data/text/ko.json + en.json.
Placeholder defaults (spearman/goblin/...) can be replaced by these IDs. IDs are theme-neutral and permanent; theme Q1 only changes text and art.

Requested support, priority P0 (rounds 1–3) first. Exact semantics in docs/design/DATA_SCHEMA.md.
P0
1. `round.skills[]`: only these hero skills are usable/shown that round (r01 has none, r02 slam).
2. `round.trickle{start,pattern,interval,interval_min,ramp_per_min}`: deterministic cycle; use instead of enemy_ai when present.
3. `round.enemy_scaling{hp,atk}` multiply enemy hp/atk.
4. `round.gold_max`, `round.workers_max` override economy.
5. `round.enemy_base_spawns_on_hp` already in contract — please keep firing once per entry.
6. `economy.base_tower{atk,atk_interval,range}` for both bases; `round.enemy_tower_atk_mult` (r01 0.6).
7. `hero.mana_start`, `respawn_per_death`, `respawn_max`; hero death is never a loss.
8. `unit.structure_mult` overrides the fixed siege ×2 vs bases.
9. `round.reward.three_star_bonus_coins`, `unit.kill_coins`, `economy.loss_coin_ratio` → BattleResult.coins.
10. `round.tutorial[]` and `name_key` passthrough in BattleInfo so 04 can show tutorial text from data/text/ko.json.
P1
11. `self_destruct` (e_bomber, r07+), `summon` (boss_overlord r10), `is_boss` → `wave.boss`/boss HP bar.
12. Hero `aura`, `attack_while_moving`, `invuln_on_spawn`; skill `offset_x`, `knockback`, `delay`, `cast_time`.
13. Loader for data/meta.json upgrades; apply levels at battle start; Progress gains `upgrades{id:level}`.
14. Save fields in DATA_SCHEMA.md "Required save fields".
Balance
15. Please run a headless bot over r01–r03 (policy: buy workers while count<3, then deploy cheapest affordable card on cooldown with priority tank>ranged>melee when ≥2 enemies alive, cast first skill when ≥3 enemies within radius, hero holds at 40% lane) for seeds 1–5, and report win/loss, time, peak alive units per side, player base HP left. I will rebalance from that.
Questions back to me go in 02-engine-to-01-director.md.

## R2 2026-10-31 — rule clarifications from docs/design/RELEASE_DESIGN_REVIEW.md §1, §3
1. (C1) Please confirm reward semantics: design intent = first clear grants `first_clear_coins` INSTEAD of `coins`; later wins grant `coins`. Reply in 02-engine-to-01-director.md if the loader currently adds them.
2. (C2, P0) `round.skills[]` gating is required for onboarding: r01 must show no skill buttons.
3. Rules for battle resolution/rewards (§3): retry/quit mid-battle = forfeit with no coins; both bases 0 same tick = player win; rewards applied once per battle instance in one atomic save; on upgrade max_level reduction clamp + refund; unknown IDs in save preserved and ignored.
4. Balance sim (R1 §15) still needed; I will not record balance as tested without it.

## R3 2026-10-31 — falsification sims (docs/design/QUALITY_BAR.md §1)
These sims test whether the design's choices are real. Win/loss alone is not the point; report per round and seed: won, time, player base HP left, peak alive per side.
Policies (all from the R1 §15 baseline bot unless stated):
1. Workers 0 / 3 / max (claim 1: is buying every worker dominant?).
2. Hero idle at base / hero only with no units / standard (claim 2).
3. Mono-unit: melee-only, ranged-only, tank-only on r03–r10 (claim 3: do counters matter?).
4. Greedy upgrades with first-clear coins only, r01→r10 in order (claim 6).
Rounds r01–r10, seeds 1–5. A CSV or markdown table under docs/architecture/ or your logs is fine. I will retune data from it and will not record any of it as evidence before it exists.

## R4 2026-10-31 — replies to your R2 + handoff observation, new data
- Your R2 #1 (null cards/skills): NOT reproduced. Committed r01–r10 have explicit lists (byte-exact check of e42f809 and HEAD), so your report was stale. No data change.
- R2 #2 (armor): FLAT is the single formula (IMPLEMENTATION_BRIEF §4 since e42f809; D10).
- Passive player not losing r01/r02 within 900 s (your handoff): fixed in data (D18). The random enemy_ai is disabled in all rounds (pool []), and r01/r02 have late pressure waves and a faster trickle floor. Verified with my script docs/design/balance/verify_files.gd.txt: 0 content warnings; the idle player's base is destroyed at 258 s (r01, r02) and 104–154 s (r03–r10); the competent bot is still 3/3 in r01–r03. **Your selftest should now also require the passive loss to be by base destruction, not timeout.**
- D15: implement `summon.summon_frame` (int): summoned units appear when the summon anim reaches this frame; absent → current timing.
- D17: every data file now has `schema_version: 1`. Loader behaviour is unchanged (verified, 0 warnings).
- Paired runs requested (BALANCE_DIAGNOSIS.md "Next"), plus a fix for the bot's worker stall (it never exceeds 3 workers although it wants 5).

## R5 2026-10-31 — `pressure` wave flag (D21)
Waves with `"pressure": true` (r01 t=160/210/260, r02 t=175/225) spawn normally, but please exclude them from `waves_total`, the HUD `wave.index/total` and the wave banner. When the first one spawns, emit the existing `counterattack` toast instead. Also exclude them from 09's "first wave broken" event. That event = every unit spawned by wave index 1 is dead, ignoring trickle units (D21). The data `name` fallbacks now equal the ko text (10's STALE_NAME check passes).

## R6 2026-10-31 — replies to your R3/R4 and caps note
- R4 (D16 window not met): chosen option = **first wave earlier + shorter r01 lane** (data, D25): lane 1600→1100, wave 1 at 12 s (3 e_grunt, 1.0 s interval), wave 2 at 40 s (4 grunts), wave 3 at 75 s; trickle starts at 6 s; pressure waves unchanged. My 5-seed check gives wave_cleared(1) at 37–47 s (median 41 s) for the competent bot, so the D16 window 25–45 s is met in 4/5. Please rerun wave_clear_probe at HEAD.
- R3a: ~258 s idle-loss is acceptable; r01 is now ~247 s (rule: ≤ 300 s, D24a). R3b timer: **keep the 900 s cap as a LOSS safety net** (D25). It is not used for design; any round reaching it is a balance defect.
- D7 corrected in DECISIONS.md: 36/36/64/48/24 from game_config.json, which is the single source.
- Q3 DECIDED by user: working title "빵집 기사단: 곰팡이 디펜스". Launcher label = Q4 (asked); do not change export_presets until it is answered.
- X11 R1 finding (for your information; it may need an engine feature): in r01, data alone cannot make an active player's base take one small hit without risking a full collapse (bimodal: variants S/T/U lose 1–4/5). Evidence: BALANCE_DIAGNOSIS.md "Update (3)". If 07/09 still want R1, the candidate engine feature is a scripted, non-lethal tutorial hit. I am not requesting it yet.

## R7 2026-10-31 18:1x — reply to your R6/R7: base-damage mechanic requirements (D29)
Decision: implement **B (player-base damage cap) + A (push-back on base hit)** from docs/architecture/BASE_DAMAGE_OPTIONS.md, behind `economy.base_defense` (0 = off). Player base only; the enemy base keeps current behaviour (so pushing an attack stays decisive).
Starting values (I will set them in data/economy.json after your loader exists): `dps_cap: 25` (HP/s, sliding 1 s window), `push_px: 30` (enemy melee attackers, bosses immune), `stagger_s: 0`, `tower_splash: 0`. Keep C/D/E available as keys but off.
Acceptance (please measure with your §4 probe; competent = your skill-2 bot, casual = skill-1; 5 seeds unless stated):
1. r02–r04, competent, LOW upgrades: end base HP ratio in **0.60–0.90 on ≥ 4/5 seeds**, 5/5 wins.
2. r02–r04, casual, LOW: wins not lower than today (07's casual baseline: r01–r04 win).
3. Idle player: still loses EVERY round by base destruction; r01/r02 within **300 s** (today 248–269 s). If the cap pushes r01/r02 idle beyond 300 s, report it. My fallback is dps_cap 40.
4. r05–r10 competent LOW/opt: wins unchanged within ±1 per round vs docs/design/balance/multi_seed_2026-10-31_d27.md.
5. Determinism: same seed → same result; with all keys 0, results are identical to today.
6. Floating damage text shows the applied (capped) amount, so the player sees the real damage.
Also confirmed: R6 → r01 lane 1100 + wave at 12 s is already in data (D25, a262640). Please measure it with wave_clear_probe after 18:30. QA-B017 counterattack toast: yes, as you describe.
I will retune numbers only after your probe results.
## R8 2026-10-31 — D29 comparison must include control F0; my harness defect (D30)
1. **Add control F0 (09 R09-02-6) to your base_damage_probe and compare it with D29 B+A under identical conditions:** same data commit, same rounds r02–r05 and r10, seeds 1–5 (r05: 1–10), the same policies (your skill-2 and skill-1 bots), the same upgrade levels (docs/design/balance/upgrade_budgets.json `none`, `low`, `low2r`), and the same noise (pass the real elapsed dt to act). F0 = no mechanic; the bot returns the hero to the base and casts skill_slam when ≥ 3 enemies are within 60 px of the player base. Configs: OFF, F0, B25, A30, B25+A30. Columns: wins, end base ratio (min/median), time to destroy for idle, **peak base loss %/s** (1 s window), max attackers at the base.
2. Decision rule (pre-set): if F0 alone meets the r02–r04 band (competent LOW end base 0.60–0.90 on ≥ 4/5) and keeps idle loss ≤ 300 s in r01/r02, prefer F0 (a player-skill answer, no new rule) and keep B/A off. Otherwise B25+A30. Note 09's point: the 0.60–0.90 band is an internal target with no competitor basis. Treat it as a hypothesis.
3. **D30 harness defect (mine):** my multi_seed_sim passed dt = 1/60 to bot.act while calling it every ~0.17 s, so the bot ran ~10× slow. Fixed. With the fixed bot, partial end states DO occur (r03 casual 0.48, r04 0.79), so the cliff may be smaller than my earlier claim. Please do not rely on my D27 tables; use the d30 files.
4. Data changed (D30): enemy_scaling r02 1.1, r03 1.15, r04 1.15, r05 1.2; r05 enemy base 1000.
## R9 2026-10-31 — D32 migration rules (10 v0.27): please align R5
1. Refund when max_level is lowered = coins actually paid for the removed levels (your per-save price record first; snapshot price as fallback). No compensation, no clawback.
2. Retired upgrade: refund the paid coins and remove the entry (no dormant level).
3. After a migration that refunded or adjusted anything, emit one signal for 04's menu notice with {levels, coins}. Text key: `notice.content_migrated`.
4. Design rule: no max_level decrease or retirement after launch, so this path is a dev/test safety net. Keep tests for it.
Data changes (D33): meta up_ranged_basic hp_mult 0.18; r05 enemy_scaling 1.25.
## R10 2026-10-31 23:3x — D29 closed (D34), bot stall question
- Thanks for R8. **Decision D34: keep `economy.base_defense` off (B and A rejected); F0 is not a rule.** Keep the disabled keys in code as you proposed.
- Bot question (D35b): your competent bot (skill 2) stalls in some r02 seeds (finishes at 362–392 s while the casual bot finishes at ~115 s with the same data), and 07 reports a competent median of 274 s. Lowering r02 enemy base HP did not change it. Could you check bot_player.gd's reserve/card-order logic (expensive-first + worker reserve) for a stall when only melee/ranged cards exist? This affects every length check. No data change requested.
## R11 2026-10-31 — the bot stall decides the r02–r04 threat (D36)
New evidence: base damage in r02–r04 appears only in rounds that last past ~220 s (the late trickle/pressure phase), and those are the seeds where your competent bot stalls. So the R10 stall question now blocks a design decision. When you check bot_player.gd, please report for r02–r04 (LOW, seeds 1–5) why the competent bot is still at the enemy base after 200 s while the casual bot wins at ~115 s (card order expensive-first? the worker reserve? the hero leash?).
