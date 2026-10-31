# D29 / 01 R8: player-base defence vs the F0 control (2026-10-31)

Owner: 02-engine. Measured, headless, deterministic. Answers 01-director-to-02-engine R7 + R8.

## What was run
- Data: `data/` at **f01e9d5** (D30 retune + D33: r05 enemy_scaling 1.25, ranged L5 hp 0.18). Probe data hash `0e824716c8f9`
  (sha256 of data/*.json, rounds, units, skills, heroes). Code: HEAD battle_sim.gd + the D29 change (keys default 0).
- Probe: `src/core/diag/base_damage_probe.gd`, 3 shards in parallel 19:41–19:59 KST, private APPDATA
  (`docs/research/systems/probes/isolated_godot.ps1`, real save.json unchanged in all runs). 924 rows, every shard
  `deterministic=true` (first row re-run identical).
  ```
  & docs/research/systems/probes/isolated_godot.ps1 -TimeoutSec 2700 -GodotArgs @('--headless','--path','.','-s',
    'res://src/core/diag/base_damage_probe.gd','--','--out=<abs>.json','--configs=off,f0')   # also b25,a30 / b25a30
  ... '--','--merge=<a>.json,<b>.json,<c>.json','--md=<abs>.md','--out=<abs merged>.json'
  ```
- Configs (in memory; data/economy.json untouched): **OFF** (all keys 0), **F0** (OFF + bot rule below), **B25**
  (`dps_cap` 25), **A30** (`push_px` 30), **B25+A30** (D29 default).
- F0 (09 R09-02-6): after each bot decision, if ≥ 3 live enemies have `x − player_base.x ≤ 60`, the hero walks back
  until it is within 40 px of the base x and holds; when within 60 px it casts `skill_slam` (centre hero.x + 30,
  radius 60). Mana and the 8 s cooldown limit it: median 0–3 slams per battle.
- Policies: competent = `bot_player.gd` skill 2, casual = skill 1, idle = no input. Bot timing noise as 01's
  multi_seed_sim after the D30 fix: first act after U(0,3) s, then every U(0,0.35) s with the real elapsed time.
- Budgets: docs/design/balance/upgrade_budgets.json `none`, `low`, `low2r`. Seeds 1–5 (r05: 1–10); idle 1 seed.
- Columns: peak loss = largest player-base HP loss in any 1 s window, % of base max HP. Max at base = most live enemies
  within 60 px of the base x at one time. Time limit 900 s for bots (engine default), none for idle.
- Files: `base_damage_r8_20261031.json` (all rows). r06–r09 were not run this time (not in R8).

## 01's pre-set rule (R8 §2)
| check | OFF | F0 | B25 | A30 | B25+A30 |
|---|---|---|---|---|---|
| r02/r03/r04 competent LOW end base in 0.60–0.90 (need ≥ 4/5 each) | 0/5, 0/5, 0/5 (all 1.000) | 0/5 ×3 (1.000) | 0/5 ×3 (1.000) | 0/5 ×3 (1.000) | 0/5 ×3 (1.000) |
| idle time to base loss r01 / r02 (need ≤ 300 s) | 268.8 / 277.0 | same as OFF (no bot) | 337.2 / 330.7 | 265.2 / 272.0 | 337.1 / 328.2 |

On this data no enemy reaches the base for competent LOW or LOW+2R in r02–r04 (max at base 0, end 1.000), so no
base-defence option can move that end value; they only act when the base is hit. F0 fails the band and passes idle.
B25+A30, the rule's fallback, fails both checks.

## r02–r04 partial end states (where the base is hit at all)
| case | OFF | F0 | B25 | A30 | B25+A30 |
|---|---|---|---|---|---|
| r03 casual LOW: wins, end min / median | 5/5, 0.481 / 1.000 | 5/5, 0.844 / 1.000 | 5/5, 0.879 / 1.000 | 5/5, 0.455 / 1.000 | 5/5, 0.879 / 1.000 |
| r04 competent none | 5/5, 0.792 / 0.950 | same | 5/5, 0.922 / 0.969 | same as OFF | 5/5, 0.922 / 0.969 |
| r04 casual none | 4/5, 0.000 / 0.720 | 5/5, 0.633 / 0.822 | 5/5, 0.629 / 0.906 | 3/5, 0.000 / 0.720 | 5/5, 0.617 / 0.906 |
| r02 every policy/budget | 5/5, 1.000 | same | same | same | same |

## r05 (block round; D27/D30: none = block, D28: casual LOW ≥ 3/10, casual LOW+2R ≥ 7/10)
| cfg | comp none | casual none | comp LOW | casual LOW | comp LOW+2R | casual LOW+2R | peak loss %/s (max) | end median comp/casual LOW |
|---|---|---|---|---|---|---|---|---|
| OFF | 0/10 | 0/10 | 8/10 | 7/10 | 10/10 | 8/10 | 15.49 | 0.086 / 0.162 |
| F0 | 0/10 | 0/10 | 7/10 | **3/10** | 9/10 | 7/10 | 15.97 | 0.069 / 0.000 |
| B25 | **10/10** | **10/10** | 10/10 | 10/10 | 10/10 | 10/10 | 1.39 | 0.772 / 0.728 |
| A30 | 0/10 | 0/10 | 7/10 | 6/10 | 9/10 | 8/10 | 17.01 | 0.156 / 0.129 |
| B25+A30 | **10/10** | **10/10** | 10/10 | 10/10 | 10/10 | 10/10 | 1.39 | 0.772 / 0.734 |

## r10 (finale; D28: casual LOW+2R ≥ 5/10)
| cfg | comp none | casual none | t median none (s) comp/casual | comp LOW (end median) | casual LOW (end median) | LOW+2R both |
|---|---|---|---|---|---|---|
| OFF | 0/5 | 1/5 | 359.2 / 682.9 | 5/5 (0.555) | 5/5 (0.715) | 5/5 |
| F0 | 0/5 | 0/5 | 331.9 / 369.0 | 5/5 (0.500) | 5/5 (0.722) | 5/5 |
| B25 | 3/5 | 2/5 | **894.6 / 900.0** | 5/5 (0.875) | 5/5 (0.921) | 5/5 |
| A30 | 0/5 | 1/5 | 369.1 / 693.5 | 5/5 (0.565) | 5/5 (0.736) | 5/5 |
| B25+A30 | 4/5 | 3/5 | **892.0 / 899.2** | 5/5 (0.899) | 5/5 (0.918) | 5/5 |

## Idle player: time until the base falls (s); max enemies at the base
| round | OFF (= F0) | B25 | A30 | B25+A30 |
|---|---|---|---|---|
| r01 | 268.8 (9) | 337.2 (19) | 265.2 (11) | 337.1 (25) |
| r02 | 277.0 (15) | 330.7 (15) | 272.0 (19) | 328.2 (19) |
| r03 | 221.0 (5) | **1019.2** (5) | 254.7 (5) | **846.9** (5) |
| r04 | 181.1 (6) | 215.5 (6) | 174.4 (4) | 212.3 (7) |
| r05 | 198.7 (6) | 243.2 (6) | 192.6 (6) | 241.2 (6) |
| r10 | 149.1 (3) | 216.4 (7) | 147.9 (3) | 220.1 (8) |

## Reading (02's view; the decision is 01's)
1. The r02–r04 "1.00 or loss" cliff that D29 was meant to fix is not present on f01e9d5 data for competent LOW: the base
   is never hit. The 0.60–0.90 band is missed on the "too safe" side, which only data (enemy pressure) can change.
2. B (the cap) turns base losses into slow wins or time-outs: r05 none 0/10 → 10/10 (the designed block disappears),
   r10 none battles run to the 900 s limit, idle r03 survives 847–1019 s, and up to 25 enemies stack at the base in r01
   idle while the cap absorbs their hits. These contradict D27/D30 (r05 none = block) and D18 (idle loses ≤ 300 s).
3. A30 alone changes little: r04 casual none 4/5 → 3/5, idle −1…−7 s except r03 +34 s, r05 peak loss up to 17.0 %/s.
4. F0 (hero defends the base) lifts the r03/r04 casual partial states (r03 min 0.48 → 0.84, r04 casual none 4/5 → 5/5)
   but lowers r05 casual LOW 7/10 → 3/10 and r10 casual none 1/5 → 0/5: pulling the hero back costs the front in long
   rounds. F0 needs no engine change.
5. Peak base loss with OFF reaches 15.5 %/s in r05 (the worst second removes about 1/6 of the base). B25 bounds it at
   25 / base max HP (1.39 %/s in r05).
6. Engine recommendation: keep `economy.base_defense` absent or 0 (today's data). The code stays in the engine, disabled.
   With every key 0 the bot results equal HEAD's (earlier clean-snapshot comparison on the pre-D30 data, HEAD vs
   HEAD + this battle_sim.gd: every competent line identical; each D29 branch is guarded by its key > 0, and the
   tower bolt splash stays 0.0). Regressions on this tree: selftest PASS (new dps_cap check), UI integration 48/0,
   07 save/faults/flow 63/0, 08 targeting equivalence 0/30.

## Full table
Generated by the probe's `--merge` mode from the same rows as `base_damage_r8_20261031.json`.

| round | policy | budget | cfg | wins | end min | end median | t median (s) | peak loss %/s max | peak median | max at base | capped HP median | f0 casts median |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| r02 | competent | none | off | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | none | off | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low | off | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low | off | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low2r | off | 5/5 | 1.000 | 1.000 | 117.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low2r | off | 5/5 | 1.000 | 1.000 | 110.9 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | none | off | 5/5 | 1.000 | 1.000 | 234.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | none | off | 5/5 | 1.000 | 1.000 | 159.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | low | off | 5/5 | 1.000 | 1.000 | 212.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low | off | 5/5 | 0.481 | 1.000 | 126.7 | 8.08 | 0.00 | 3 | 0 | 0 |
| r03 | competent | low2r | off | 5/5 | 1.000 | 1.000 | 204.3 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low2r | off | 5/5 | 1.000 | 1.000 | 124.2 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | none | off | 5/5 | 0.792 | 0.950 | 434.9 | 5.25 | 3.52 | 3 | 0 | 0 |
| r04 | casual | none | off | 4/5 | 0.000 | 0.720 | 350.6 | 8.62 | 7.19 | 4 | 0 | 0 |
| r04 | competent | low | off | 5/5 | 1.000 | 1.000 | 220.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low | off | 5/5 | 1.000 | 1.000 | 123.0 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | low2r | off | 5/5 | 1.000 | 1.000 | 122.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low2r | off | 5/5 | 1.000 | 1.000 | 100.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r05 | competent | none | off | 0/10 | 0.000 | 0.000 | 250.4 | 14.10 | 13.61 | 5 | 0 | 0 |
| r05 | casual | none | off | 0/10 | 0.000 | 0.000 | 249.4 | 15.49 | 13.43 | 6 | 0 | 0 |
| r05 | competent | low | off | 8/10 | 0.000 | 0.086 | 361.7 | 12.82 | 11.74 | 5 | 0 | 0 |
| r05 | casual | low | off | 7/10 | 0.000 | 0.162 | 365.1 | 14.52 | 11.74 | 5 | 0 | 0 |
| r05 | competent | low2r | off | 10/10 | 0.014 | 0.449 | 361.4 | 11.17 | 10.76 | 4 | 0 | 0 |
| r05 | casual | low2r | off | 8/10 | 0.000 | 0.358 | 372.5 | 11.57 | 11.17 | 5 | 0 | 0 |
| r10 | competent | none | off | 0/5 | 0.000 | 0.000 | 359.2 | 9.27 | 8.13 | 8 | 0 | 0 |
| r10 | casual | none | off | 1/5 | 0.000 | 0.000 | 682.9 | 13.39 | 7.60 | 10 | 0 | 0 |
| r10 | competent | low | off | 5/5 | 0.452 | 0.555 | 460.0 | 6.14 | 5.95 | 5 | 0 | 0 |
| r10 | casual | low | off | 5/5 | 0.659 | 0.715 | 460.7 | 6.14 | 5.58 | 5 | 0 | 0 |
| r10 | competent | low2r | off | 5/5 | 0.990 | 0.998 | 406.9 | 0.26 | 0.19 | 3 | 0 | 0 |
| r10 | casual | low2r | off | 5/5 | 0.962 | 1.000 | 421.1 | 2.79 | 0.00 | 5 | 0 | 0 |
| r01 | idle | none | off | 0/1 | 0.000 | 0.000 | 268.8 | 6.00 | 6.00 | 9 | 0 | 0 |
| r02 | idle | none | off | 0/1 | 0.000 | 0.000 | 277.0 | 9.90 | 9.90 | 15 | 0 | 0 |
| r03 | idle | none | off | 0/1 | 0.000 | 0.000 | 221.0 | 6.13 | 6.13 | 5 | 0 | 0 |
| r04 | idle | none | off | 0/1 | 0.000 | 0.000 | 181.1 | 6.33 | 6.33 | 6 | 0 | 0 |
| r05 | idle | none | off | 0/1 | 0.000 | 0.000 | 198.7 | 6.53 | 6.53 | 6 | 0 | 0 |
| r10 | idle | none | off | 0/1 | 0.000 | 0.000 | 149.1 | 8.91 | 8.91 | 3 | 0 | 0 |
| r02 | competent | none | f0 | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | none | f0 | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low | f0 | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low | f0 | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low2r | f0 | 5/5 | 1.000 | 1.000 | 117.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low2r | f0 | 5/5 | 1.000 | 1.000 | 110.9 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | none | f0 | 5/5 | 1.000 | 1.000 | 234.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | none | f0 | 5/5 | 1.000 | 1.000 | 159.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | low | f0 | 5/5 | 1.000 | 1.000 | 212.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low | f0 | 5/5 | 0.844 | 1.000 | 126.7 | 6.34 | 0.00 | 3 | 0 | 0 |
| r03 | competent | low2r | f0 | 5/5 | 1.000 | 1.000 | 204.3 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low2r | f0 | 5/5 | 1.000 | 1.000 | 124.2 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | none | f0 | 5/5 | 0.792 | 0.950 | 434.9 | 5.25 | 3.52 | 3 | 0 | 0 |
| r04 | casual | none | f0 | 5/5 | 0.633 | 0.822 | 407.2 | 7.91 | 5.46 | 4 | 0 | 0 |
| r04 | competent | low | f0 | 5/5 | 1.000 | 1.000 | 220.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low | f0 | 5/5 | 1.000 | 1.000 | 123.0 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | low2r | f0 | 5/5 | 1.000 | 1.000 | 122.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low2r | f0 | 5/5 | 1.000 | 1.000 | 100.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r05 | competent | none | f0 | 0/10 | 0.000 | 0.000 | 247.6 | 13.61 | 13.43 | 5 | 0 | 2 |
| r05 | casual | none | f0 | 0/10 | 0.000 | 0.000 | 243.9 | 15.97 | 13.61 | 6 | 0 | 2 |
| r05 | competent | low | f0 | 7/10 | 0.000 | 0.069 | 356.9 | 13.45 | 11.74 | 5 | 0 | 1 |
| r05 | casual | low | f0 | 3/10 | 0.000 | 0.000 | 294.1 | 14.52 | 11.74 | 5 | 0 | 3 |
| r05 | competent | low2r | f0 | 9/10 | 0.000 | 0.414 | 358.3 | 11.17 | 10.76 | 4 | 0 | 0 |
| r05 | casual | low2r | f0 | 7/10 | 0.000 | 0.081 | 366.9 | 11.57 | 11.00 | 5 | 0 | 3 |
| r10 | competent | none | f0 | 0/5 | 0.000 | 0.000 | 331.9 | 10.10 | 9.17 | 9 | 0 | 1 |
| r10 | casual | none | f0 | 0/5 | 0.000 | 0.000 | 369.0 | 13.39 | 7.34 | 10 | 0 | 3 |
| r10 | competent | low | f0 | 5/5 | 0.312 | 0.500 | 460.4 | 6.14 | 5.95 | 5 | 0 | 0 |
| r10 | casual | low | f0 | 5/5 | 0.695 | 0.722 | 452.4 | 6.14 | 5.58 | 5 | 0 | 3 |
| r10 | competent | low2r | f0 | 5/5 | 0.990 | 0.998 | 406.9 | 0.26 | 0.19 | 3 | 0 | 0 |
| r10 | casual | low2r | f0 | 5/5 | 0.904 | 1.000 | 421.1 | 4.43 | 0.00 | 4 | 0 | 0 |
| r02 | competent | none | b25 | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | none | b25 | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low | b25 | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low | b25 | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low2r | b25 | 5/5 | 1.000 | 1.000 | 117.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low2r | b25 | 5/5 | 1.000 | 1.000 | 110.9 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | none | b25 | 5/5 | 1.000 | 1.000 | 234.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | none | b25 | 5/5 | 1.000 | 1.000 | 159.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | low | b25 | 5/5 | 1.000 | 1.000 | 212.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low | b25 | 5/5 | 0.879 | 1.000 | 126.7 | 1.52 | 0.00 | 3 | 0 | 0 |
| r03 | competent | low2r | b25 | 5/5 | 1.000 | 1.000 | 204.3 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low2r | b25 | 5/5 | 1.000 | 1.000 | 124.2 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | none | b25 | 5/5 | 0.922 | 0.969 | 434.9 | 1.56 | 1.56 | 3 | 31 | 0 |
| r04 | casual | none | b25 | 5/5 | 0.629 | 0.906 | 448.8 | 1.56 | 1.56 | 4 | 299 | 0 |
| r04 | competent | low | b25 | 5/5 | 1.000 | 1.000 | 220.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low | b25 | 5/5 | 1.000 | 1.000 | 123.0 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | low2r | b25 | 5/5 | 1.000 | 1.000 | 122.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low2r | b25 | 5/5 | 1.000 | 1.000 | 100.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r05 | competent | none | b25 | 10/10 | 0.145 | 0.305 | 430.1 | 1.39 | 1.39 | 5 | 4271 | 0 |
| r05 | casual | none | b25 | 10/10 | 0.272 | 0.405 | 461.4 | 1.39 | 1.39 | 6 | 2974 | 0 |
| r05 | competent | low | b25 | 10/10 | 0.704 | 0.772 | 363.1 | 1.26 | 1.26 | 5 | 1346 | 0 |
| r05 | casual | low | b25 | 10/10 | 0.654 | 0.728 | 370.2 | 1.26 | 1.26 | 5 | 1122 | 0 |
| r05 | competent | low2r | b25 | 10/10 | 0.783 | 0.817 | 361.4 | 1.16 | 1.16 | 4 | 814 | 0 |
| r05 | casual | low2r | b25 | 10/10 | 0.715 | 0.802 | 373.6 | 1.16 | 1.16 | 5 | 972 | 0 |
| r10 | competent | none | b25 | 3/5 | 0.399 | 0.512 | 894.6 | 1.04 | 1.04 | 8 | 2680 | 0 |
| r10 | casual | none | b25 | 2/5 | 0.379 | 0.555 | 900.0 | 1.04 | 1.04 | 10 | 2669 | 0 |
| r10 | competent | low | b25 | 5/5 | 0.846 | 0.875 | 460.0 | 0.74 | 0.74 | 5 | 1075 | 0 |
| r10 | casual | low | b25 | 5/5 | 0.897 | 0.921 | 460.7 | 0.74 | 0.74 | 5 | 716 | 0 |
| r10 | competent | low2r | b25 | 5/5 | 0.990 | 0.998 | 406.9 | 0.26 | 0.19 | 3 | 0 | 0 |
| r10 | casual | low2r | b25 | 5/5 | 0.983 | 1.000 | 421.1 | 0.74 | 0.00 | 5 | 0 | 0 |
| r01 | idle | none | b25 | 0/1 | 0.000 | 0.000 | 337.2 | 1.67 | 1.67 | 19 | 6780 | 0 |
| r02 | idle | none | b25 | 0/1 | 0.000 | 0.000 | 330.7 | 1.67 | 1.67 | 15 | 4980 | 0 |
| r03 | idle | none | b25 | 0/1 | 0.000 | 0.000 | 1019.2 | 1.67 | 1.67 | 5 | 853 | 0 |
| r04 | idle | none | b25 | 0/1 | 0.000 | 0.000 | 215.5 | 1.56 | 1.56 | 6 | 1120 | 0 |
| r05 | idle | none | b25 | 0/1 | 0.000 | 0.000 | 243.2 | 1.39 | 1.39 | 6 | 5800 | 0 |
| r10 | idle | none | b25 | 0/1 | 0.000 | 0.000 | 216.4 | 1.04 | 1.04 | 7 | 5141 | 0 |
| r02 | competent | none | a30 | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | none | a30 | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low | a30 | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low | a30 | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low2r | a30 | 5/5 | 1.000 | 1.000 | 117.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low2r | a30 | 5/5 | 1.000 | 1.000 | 110.9 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | none | a30 | 5/5 | 1.000 | 1.000 | 234.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | none | a30 | 5/5 | 1.000 | 1.000 | 159.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | low | a30 | 5/5 | 1.000 | 1.000 | 212.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low | a30 | 5/5 | 0.455 | 1.000 | 126.7 | 8.08 | 0.00 | 3 | 0 | 0 |
| r03 | competent | low2r | a30 | 5/5 | 1.000 | 1.000 | 204.3 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low2r | a30 | 5/5 | 1.000 | 1.000 | 124.2 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | none | a30 | 5/5 | 0.792 | 0.950 | 434.9 | 5.25 | 3.52 | 3 | 0 | 0 |
| r04 | casual | none | a30 | 3/5 | 0.000 | 0.720 | 332.4 | 8.84 | 7.19 | 4 | 0 | 0 |
| r04 | competent | low | a30 | 5/5 | 1.000 | 1.000 | 220.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low | a30 | 5/5 | 1.000 | 1.000 | 123.0 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | low2r | a30 | 5/5 | 1.000 | 1.000 | 122.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low2r | a30 | 5/5 | 1.000 | 1.000 | 100.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r05 | competent | none | a30 | 0/10 | 0.000 | 0.000 | 251.1 | 14.24 | 13.09 | 6 | 0 | 0 |
| r05 | casual | none | a30 | 0/10 | 0.000 | 0.000 | 249.6 | 17.01 | 13.61 | 7 | 0 | 0 |
| r05 | competent | low | a30 | 7/10 | 0.000 | 0.156 | 356.4 | 12.18 | 11.74 | 5 | 0 | 0 |
| r05 | casual | low | a30 | 6/10 | 0.000 | 0.129 | 364.9 | 14.52 | 11.74 | 6 | 0 | 0 |
| r05 | competent | low2r | a30 | 9/10 | 0.000 | 0.401 | 360.9 | 11.17 | 10.76 | 5 | 0 | 0 |
| r05 | casual | low2r | a30 | 8/10 | 0.000 | 0.229 | 373.4 | 11.75 | 11.17 | 5 | 0 | 0 |
| r10 | competent | none | a30 | 0/5 | 0.000 | 0.000 | 369.1 | 9.27 | 8.13 | 8 | 0 | 0 |
| r10 | casual | none | a30 | 1/5 | 0.000 | 0.000 | 693.5 | 13.59 | 9.38 | 11 | 0 | 0 |
| r10 | competent | low | a30 | 5/5 | 0.540 | 0.565 | 459.0 | 8.18 | 5.95 | 5 | 0 | 0 |
| r10 | casual | low | a30 | 5/5 | 0.701 | 0.736 | 461.9 | 6.32 | 5.39 | 5 | 0 | 0 |
| r10 | competent | low2r | a30 | 5/5 | 0.990 | 0.998 | 406.9 | 0.26 | 0.19 | 3 | 0 | 0 |
| r10 | casual | low2r | a30 | 5/5 | 0.966 | 1.000 | 421.1 | 2.42 | 0.00 | 5 | 0 | 0 |
| r01 | idle | none | a30 | 0/1 | 0.000 | 0.000 | 265.2 | 7.33 | 7.33 | 11 | 0 | 0 |
| r02 | idle | none | a30 | 0/1 | 0.000 | 0.000 | 272.0 | 8.80 | 8.80 | 19 | 0 | 0 |
| r03 | idle | none | a30 | 0/1 | 0.000 | 0.000 | 254.7 | 5.75 | 5.75 | 5 | 0 | 0 |
| r04 | idle | none | a30 | 0/1 | 0.000 | 0.000 | 174.4 | 4.67 | 4.67 | 4 | 0 | 0 |
| r05 | idle | none | a30 | 0/1 | 0.000 | 0.000 | 192.6 | 5.56 | 5.56 | 6 | 0 | 0 |
| r10 | idle | none | a30 | 0/1 | 0.000 | 0.000 | 147.9 | 8.91 | 8.91 | 3 | 0 | 0 |
| r02 | competent | none | b25a30 | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | none | b25a30 | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low | b25a30 | 5/5 | 1.000 | 1.000 | 171.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low | b25a30 | 5/5 | 1.000 | 1.000 | 116.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | competent | low2r | b25a30 | 5/5 | 1.000 | 1.000 | 117.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r02 | casual | low2r | b25a30 | 5/5 | 1.000 | 1.000 | 110.9 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | none | b25a30 | 5/5 | 1.000 | 1.000 | 234.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | none | b25a30 | 5/5 | 1.000 | 1.000 | 159.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | competent | low | b25a30 | 5/5 | 1.000 | 1.000 | 212.4 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low | b25a30 | 5/5 | 0.879 | 1.000 | 126.7 | 1.52 | 0.00 | 3 | 0 | 0 |
| r03 | competent | low2r | b25a30 | 5/5 | 1.000 | 1.000 | 204.3 | 0.00 | 0.00 | 0 | 0 | 0 |
| r03 | casual | low2r | b25a30 | 5/5 | 1.000 | 1.000 | 124.2 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | none | b25a30 | 5/5 | 0.922 | 0.969 | 434.9 | 1.56 | 1.56 | 3 | 31 | 0 |
| r04 | casual | none | b25a30 | 5/5 | 0.617 | 0.906 | 450.8 | 1.56 | 1.56 | 4 | 299 | 0 |
| r04 | competent | low | b25a30 | 5/5 | 1.000 | 1.000 | 220.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low | b25a30 | 5/5 | 1.000 | 1.000 | 123.0 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | competent | low2r | b25a30 | 5/5 | 1.000 | 1.000 | 122.7 | 0.00 | 0.00 | 0 | 0 | 0 |
| r04 | casual | low2r | b25a30 | 5/5 | 1.000 | 1.000 | 100.1 | 0.00 | 0.00 | 0 | 0 | 0 |
| r05 | competent | none | b25a30 | 10/10 | 0.125 | 0.364 | 416.1 | 1.39 | 1.39 | 6 | 3874 | 0 |
| r05 | casual | none | b25a30 | 10/10 | 0.239 | 0.375 | 444.8 | 1.39 | 1.39 | 7 | 3341 | 0 |
| r05 | competent | low | b25a30 | 10/10 | 0.665 | 0.772 | 357.9 | 1.26 | 1.26 | 5 | 1164 | 0 |
| r05 | casual | low | b25a30 | 10/10 | 0.691 | 0.734 | 371.2 | 1.26 | 1.26 | 6 | 1201 | 0 |
| r05 | competent | low2r | b25a30 | 10/10 | 0.729 | 0.826 | 360.9 | 1.16 | 1.16 | 5 | 919 | 0 |
| r05 | casual | low2r | b25a30 | 10/10 | 0.708 | 0.771 | 375.7 | 1.16 | 1.16 | 5 | 1238 | 0 |
| r10 | competent | none | b25a30 | 4/5 | 0.405 | 0.541 | 892.0 | 1.04 | 1.04 | 8 | 2029 | 0 |
| r10 | casual | none | b25a30 | 3/5 | 0.412 | 0.569 | 899.2 | 1.04 | 1.04 | 11 | 2330 | 0 |
| r10 | competent | low | b25a30 | 5/5 | 0.874 | 0.899 | 459.0 | 0.74 | 0.74 | 5 | 1121 | 0 |
| r10 | casual | low | b25a30 | 5/5 | 0.904 | 0.918 | 461.9 | 0.74 | 0.74 | 5 | 654 | 0 |
| r10 | competent | low2r | b25a30 | 5/5 | 0.990 | 0.998 | 406.9 | 0.26 | 0.19 | 3 | 0 | 0 |
| r10 | casual | low2r | b25a30 | 5/5 | 0.983 | 1.000 | 421.1 | 0.74 | 0.00 | 5 | 0 | 0 |
| r01 | idle | none | b25a30 | 0/1 | 0.000 | 0.000 | 337.1 | 1.67 | 1.67 | 25 | 7535 | 0 |
| r02 | idle | none | b25a30 | 0/1 | 0.000 | 0.000 | 328.2 | 1.67 | 1.67 | 19 | 5990 | 0 |
| r03 | idle | none | b25a30 | 0/1 | 0.000 | 0.000 | 846.9 | 1.67 | 1.67 | 5 | 912 | 0 |
| r04 | idle | none | b25a30 | 0/1 | 0.000 | 0.000 | 212.3 | 1.56 | 1.56 | 7 | 1953 | 0 |
| r05 | idle | none | b25a30 | 0/1 | 0.000 | 0.000 | 241.2 | 1.39 | 1.39 | 6 | 6051 | 0 |
| r10 | idle | none | b25a30 | 0/1 | 0.000 | 0.000 | 220.1 | 1.04 | 1.04 | 8 | 5781 | 0 |
