# Base damage mechanics for r02–r04 "no hit or a loss" (owner: 02-engine; DESIGN, nothing implemented)
Date: 2026-10-31 18:05 KST. Written during 08's quiet window: static reading + Python arithmetic on current data only. No Godot run. Every "expected" value below is an estimate, UNVERIFIED until the probe in §4 runs after 18:30.
Input: 01 BALANCE_DIAGNOSIS.md "root cause": in r02–r04 an active bot's base ends at 1.00 or 0.00 (a loss). The 0.6–0.9 band needs a mechanic, not a number change.

## 1. Why it is bimodal (current code + data)
- Base defence = one tower: 30 dmg / 1.5 s = 20 dps, single target, range 130 (economy.json `base_tower`; enemy tower × round mult). Tower kill time: e_grunt 5.0 s, e_swarm 1.8 s, e_spitter 3.0 s, e_brute 18 s.
- Grunts at the base deal 10 dps each (no base armor). With n grunts at the base and the tower removing one every 5 s, base time to fall (no help): n=2 75 s, n=4 38 s, n=6 25 s, n=10 15 s.
- So 1–2 attackers barely hurt the base before the tower or new troops clear them (≈ 1.00 left), while ≥ 4 out-damage the tower and freshly deployed troops spawn into the pile (`deploy()` spawns at base x + 22) and die one by one (→ 0.00). There is no stable state in between.
- Code points: attack on base `battle_sim.gd _step_unit` (base_reach, ~594) → `_attack_logic` (618) → `_resolve_attack` melee base branch (`_damage_base(-u.side, atk * _struct_mult(u))`, ~679) / projectile `hit_base` branch in `_step_projectiles`; base HP `_damage_base` (840); tower `_step_towers` (856).

## 2. Options
All are deterministic (no RNG). All change balance outcomes, so selftest balance lines and 08/10 baselines must be re-recorded once. Data keys are proposals for 01 (`economy.base_defense`), default 0 = off, so nothing changes until 01 sets values.
| # | Mechanic | Change points | Expected effect (estimate) | Risk |
|---|---|---|---|---|
| A | **Base push-back**: each hit on the player base knocks the attacker back `push_px` (bosses immune, as for unit knockback) | `_resolve_attack` base branch: after `_damage_base`, set `u.kb = maxf(u.kb, push_px)` for enemy attackers; `_apply_kb` already moves enemies right. Projectiles: none (ranged keep range) | One grunt's base dps × 0.63 at 20 px, × 0.46 at 40 px, × 0.36 at 60 px (walk back at 38 px/s + 1.0 s interval). Spreads the pile so the tower and new troops face fewer at once | Melee only; ranged/siege unaffected; pile still forms if many arrive at once |
| B | **Base damage cap** `dps_cap` HP/s on the player base (sliding 1 s window) | `_damage_base`: keep `b.window_t`, `b.window_dmg`; clamp the applied amount to `dps_cap − window_dmg`; floating text shows the applied amount | Minimum time to destroy a 1500 HP base: 15 HP/s → 100 s, 25 → 60 s, 40 → 38 s. A cascade becomes a long, recoverable drain: ending HP spreads over 0–1 instead of 0 or 1 | Feels "invulnerable" if too low; pressure waves and bosses need it too; hides the cost of a bad push |
| C | **Stagger on base hit**: enemy attackers wait `stagger_s` extra after each base hit | `_attack_logic`: when `hit_base` resolves, `u.atk_cd += stagger_s` | Equivalent to scaling base dps by `interval / (interval + stagger)`: 0.5 s → × 0.67 for grunts | Same as A without the visual push; invisible rule |
| D | **Tower vs piles**: `tower_splash` px (damage all enemies within splash of the target) and/or larger `range` | `_step_towers` → projectile `splash = tower_splash`; existing splash path in `_step_projectiles` does the rest | Splash 30 px vs a stacked pile of 4 grunts: 4× tower output (80 dps vs 20) → piles break before the cascade | Can also make the early game trivial; enemy tower gets the same unless the key is player-only |
| E | **Safe deploy**: new troops spawn behind the base (x − 10) and step in, not into the pile | `deploy()` spawn x | Troops stop dying one by one on arrival; small effect on the band | Changes deploy timing slightly |
Not recommended alone: tuning numbers (01 already showed the cliff), a scripted tutorial hit (01 X11; r01 only).

## 3. Recommendation
B (cap) + A (push-back), both behind data keys, with D as a later knob. B is the only option that turns "0 or 1" into a continuous result by construction; A makes the cap rarely bind in normal play so the base still feels hittable. 01 sets the numbers (start: cap 25 HP/s, push 30 px) and the target band per round.

## 4. Test method (after 18:30, 02)
- New `src/core/diag/base_damage_probe.gd`: r02–r04 (and r05, r10 for regressions) × seeds 1–5 × policies {competent, casual, passive} × parameter grid {off; A 20/40; B 25/40; A30+B25; D 30}. Output: player base ratio at the end, win/loss, time, max attackers at base at once.
- Acceptance proposal for 01: competent bot ends r02–r04 in 01's band (e.g. 0.6–0.9) on ≥ 4/5 seeds; casual bot does not lose more than today; passive player still loses every round (time recorded); r05–r10 competent results unchanged within ±1 win per round.
- Determinism: same seed → same result (selftest runs each seed twice); 08 targeting equivalence unaffected (targeting code untouched).

## 5. Other static findings (fix after 18:30, verified then)
- QA-B017 (pressure waves after "wave 3/3" without a cue): 01's D21 note (01-director-to-02-engine line 52) asks for the existing `counterattack` toast when the first pressure wave spawns; I did not implement that in 22d99ea. Fix: in `BattleSim.setup` record pressure wave times; in `_step_wave_announce` append `["counterattack", {"pressure": true}]` once when the first one arrives (battle.gd already forwards `counterattack` to `Events.toast`). Optional for 04: `HudSnapshot.wave.pressure_next_in`. Test: r01 idle → exactly one counterattack toast at t = 160 s, none earlier.
- Hard-coded old name: `src/gameplay/fallback_ui.gd:54-55` ("LANE DEFENCE" + "working title" line) → use `UiText.t("ui.title")` (same loader as the window title), fallback "Bakery Knights". Only shown when 04's menu scene is missing.
- Desktop window title: implemented but unverified (uncommitted `src/core/app.gd` `_apply_window_title`). `application/config/name` stays "Lane Defence" (save folder).
