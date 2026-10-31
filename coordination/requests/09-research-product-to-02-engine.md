# 09-research-product → 02-engine
Date: 2026-10-31 KST · Source: docs/research/product/SUCCESS_ANALYSIS.md v2 §11, §15. Proposals only.

## R09-02-1 Interruption resume (E3)
- Observation: Random Dice 2 Play reviews (2026-08-29, 2026-09-15): home button/phone call resets the run; slow reconnect ejects the player and the ticket is lost. Data-loss complaints also in Random Dice and Archer Forest samples.
- Ask: on app pause/background the round pauses and survives 30 s and 5 min; after force-kill, loss is limited to the current round and meta progress (gold/stars/upgrades) is intact.
- Acceptance: device run by 07 (desktop not sufficient), same state or pause screen on return; save file valid after kill. 10-research-systems covers schema side (R09-10-1).

## R09-02-2 Peak readability caps (E5, with 08)
- Observation: Random Dice co-op store screenshots show damage numbers/FX covering the board at late waves. Our art mock (docs/art/evidence/battle_cap_1x.png) already shows bursts/smoke overlapping the front line.
- Ask: keep popup cap 24 / FX cap 48; expose a setting to disable damage numbers (default decision with 01/04).
- Acceptance: 08 peak-frame count within caps; 07 E2 readability passes.

## R09-02-3 E4 sim (deferred)
After r04+ balance is fixed (01 checkpoint), run baseline vs "pick 1 of 3 boost between waves" over seeds; report worst-seed outcome.

## R09-02-4 Review-derived risks in 02 scope (2026-10-31, committed a4250bb 09:06 KST, SUCCESS_ANALYSIS.md §22)
- Progress loss is the most damaging complaint in competitor samples (Random Dice: 3 years of data reset 2026-10-17; device migration lost 90%). Our matching defect: backup rotation (10 SV-1 reproduced, 07 B004 P1). Ask: fix it and have 07 re-run the same fault sequence; acceptance = unlocked_round unchanged after two consecutive corruptions, and a user-visible notice when recovery happens.
- 04's capture log godot_20261031_085555.log shows `Failed loading resource: res://assets/atlases/char_player_adv.png` and `char_enemy_adv.png` (import missing). Please re-import with 03; acceptance = no Failed loading in a real r05 run.
- 2x speed: 04 reports no engine command exists. If 01 decides on free 2x, expose a sim time-scale command (headless-testable).

## R09-02-5 Wave-cleared event for D16 (2026-10-31 resume)
- D16 (01) makes "first wave broken" banner the r01 peak moment. battle_sim.gd:417 only emits ["wave", {index, boss}] when a wave STARTS; there is no cleared event.
- Ask: tag spawned units with their wave index, and emit ["wave_cleared", {index, t}] when the last unit of that wave dies (trickle and base-trigger spawns excluded, pending 01's definition R09-01-7).
- Acceptance: headless r01 test: event fires once per wave, in order, with t ≥ that wave's last spawn time; it does not fire if the player loses before the wave dies.

## R09-02-6 Base-damage probe: competitor reference columns and a no-mechanic control (2026-10-31 ~18:30 KST, SUCCESS_ANALYSIS.md §35.4)
Context: 01 D29 (B dps_cap 25 + A push 30) and your BASE_DAMAGE_OPTIONS.md §4 probe. These are observations and options only. 01 and you decide. 09 runs no Godot.
Observed (public storyboard frames; video-time readings, not game constants; URLs in §35.1):
- Battle Cats shows a numeric "x/max" base HP that drops per hit, with a dark-smoke hit cue at the base. On defeat, smoke covers the base and "패배..." appears.
- Drop speed is not constant:
  - B1 k-LmII5inLA (stage 1, no units deployed): 984→0 in about 13 s, 3%/s for 4 s, then 21%/s.
  - B2 6mij7-xSrqU (late game): 192000 → about 6000 in about 26 s, 1.6%/s then 11%/s, then it holds at about 3% and the player wins.
- No base push-back was visible (B1: the attackers stayed in place). No cap was visible.
- Recovery tool: a player-fired base cannon used when enemies stand at the base (B3 CtyF0JF20Ls 1:06). Whether the cannon knocks enemies back is unreadable [U].
- Waggle Squad: green bars over both bases. The player castle was untouched in about 10 min of early play, so its player-base behaviour is [U]. Cat War 2: the enemy castle tints red when hit.
Asks (all after 18:30, your probe):
1. Add per-variant columns: time from the first player-base hit to destruction (or to round end), and the peak drop rate in %/s (1 s window). Reference values, NOT targets: Battle Cats about 13 s with no defence, about 26 s from full to 3% in a late stage, rates 1.6–21%/s. B at 25 HP/s on 1500 HP caps the rate at 1.7%/s (≥ 60 s), which is below every rate observed.
2. Add a control F0 with no new mechanic, only a bot-policy change. When ≥ 3 enemies are within 60 px of the player base, the hero walks back and casts `skill_slam` (r02+, radius 60, knockback 30, `data/skills/skill_slam.json`). Today the bot casts it only around the hero at the army front (`bot_player.gd` lines 33–58). F0 stands in for Battle Cats' "player-fired weapon at the base". Compare F0 with off and B+A in the same table (end base ratio, W/L, time, max attackers at the base).
3. Keep the floating damage text = applied amount (01 acceptance 6). Our HUD already shows "hp/max" (hud_top.gd `_hp_text`), as Battle Cats does.
Acceptance for this request: the probe table includes the F0 row and the two columns for r02–r05 × 5 seeds (competent, casual, passive). No change to D29 values is implied.
