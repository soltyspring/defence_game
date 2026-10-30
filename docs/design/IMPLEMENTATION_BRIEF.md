# Implementation brief (01-director) — PROVISIONAL v0.1
Updated: 2026-10-31 06:30 +09:00. Owner: 01-director. Theme is NOT decided (Q1 pending). Every value here is a reversible default unless marked DECIDED in docs/design/DECISIONS.md.

## 1. One-line pitch
Single-lane, base-vs-base pixel defence for phones (landscape). Train workers for income, deploy auto-walking troops, directly steer one hero with skills, destroy the enemy base before yours falls. Short rounds (2–5 min), upgrades between rounds.

## 2. Core loop
In-round (seconds): supply ticks up → buy worker (more income) OR deploy unit → units auto-walk right and fight → hero moves left/right, auto-attacks, casts skills with energy → kill enemies (small supply bounty) → push and destroy enemy base.
Between rounds (minutes): earn gold + stars → spend gold on unit/hero/economy upgrades → unlock next round → new unit/skill/enemy introduced every 1–2 rounds.
Long term: chapters of 10 rounds per biome, star goals, replay rewards, later modes (see ROADMAP.md).

## 3. Layout and controls (04 UI, 02 gameplay)
- Landscape. Logical reference viewport 640×360; all gameplay distances/speeds in data are reference pixels (px, px/s). Lane length per round in rounds.json (1600–2200 px ≈ 2.5–3.5 screens). Player base at x=0 (left), enemy base at x=lane_length (right). Ground line single y; units do not collide, they stack with small random x/y jitter for readability.
- Camera follows hero horizontally; optional drag-to-pan returns to hero after 2 s idle.
- HUD: top-left supply (current/cap, +rate/s) and energy; top-center both base HP bars; top-right pause and 1×/2× speed (2× can be backlog).
- Bottom-left: hold-to-move ◀ ▶ hero buttons (≥ 56 dp touch targets). Bottom-center: worker button + up to 5 unit deploy cards (icon, cost, cooldown sweep, disabled when unaffordable). Bottom-right: up to 3 skill buttons (energy cost, cooldown).
- Results screen: win/loss, stars (1–3), gold earned, Retry / Next / Upgrades.

## 4. Rules (authoritative numbers live in data/*.json)
- Resources in-round: supply (deploy units, buy workers), energy (hero skills). Both regenerate per second, both capped. Meta currency: gold (persistent).
- Worker: abstract income. Each worker adds 1.5 supply/s; cost 40 × 1.3^n; capped per round (`max_workers`). Workers are drawn shuttling behind the player base (visual only, invulnerable in MVP).
- Units: move right at `speed`; stop when nearest enemy (unit/hero/base) is within `range`; attack every `attack_interval` s. Ranged units fire pooled projectiles (or hitscan if 02 prefers; keep visual travel). `splash_radius` > 0 deals full damage to all enemies within radius of target.
- Damage formula (flat armor, per engine contract): `dmg = max(1, atk − armor) × (target is base ? structure_mult : 1)`.
- Targeting: nearest opposing entity ahead in lane (units/hero first, base only if no unit within range). Enemies use the same rules moving left.
- Bases: HP from round; each base has a defensive tower (`tower` block in game_config) to stop spawn-camping.
- Hero: one per run (`hero_captain`). Hold-to-move, auto-attacks in range when stopped OR moving. On death: respawn at player base after `respawn_base + respawn_per_death × deaths` s (capped). Hero death is NOT a loss. Passive aura buffs nearby allies.
- Skills: cost energy + cooldown. MVP: `skill_slam` (frontal AoE + knockback), `skill_rally` (ally buff), `skill_barrage` (delayed AoE ahead).
- Win: enemy base HP ≤ 0. Loss: player base HP ≤ 0. No timer loss. Retry restarts round from scratch.
- Enemy spawning: scripted `waves` at time t, plus `trickle` cycling a deterministic pattern with an interval that ramps down to a floor, plus `base_triggers` that fire once when enemy base HP drops below a ratio. Deterministic order (seedable jitter only) so headless tests are reproducible.
- Stars: 1 = win, 2 = win with player base HP ≥ `stars.base_hp_ratio`, 3 = also clear time ≤ `stars.par_time_sec`.
- Unlocks: entity has `unlock_round`; available in a round when `unlock_round ≤ round.index`. Round N+1 unlocks when N is won.

## 5. MVP content (provisional, role-based IDs so retheming never breaks data)
Allies: worker, melee_basic, ranged_basic, tank, fast, siege. Hero: hero_captain. Skills: skill_slam, skill_rally, skill_barrage.
Enemies: e_grunt, e_swarm, e_spitter, e_brute, e_bomber, boss_warlord (R5), boss_overlord (R10, summons).
Display names come from data/text/ko.json and en.json keys only; IDs are permanent.

## 6. Priority
P0 = rounds 1–3 fully playable (melee/ranged/tank, worker, hero, slam, grunt/swarm/spitter, win/loss/retry, save progress). P1 = rounds 4–10 + upgrades screen. P2 = retention/monetization hooks (see ECONOMY.md, BACKLOG.md).

## 7. Performance-relevant gameplay caps (PROVISIONAL, aligned to ENGINE.md §7)
36 units per side, 64 projectiles, 24 damage popups, 48 FX. When the ally cap is reached the deploy card shows "army full" and does not charge. Enemy spawns over cap wait (queue), not dropped.

## 8. Files (layout per docs/contracts/INTERFACES.md §2)
- data/units/units.json, data/heroes/hero_captain.json, data/skills/*.json, data/rounds/r01..r10.json + order.json, data/economy.json, data/meta.json, data/game_config.json, data/text/ko.json + en.json
- Schema: docs/design/DATA_SCHEMA.md. Design: GDD.md, ROUNDS.md, ECONOMY.md. Planning: ROADMAP.md, BACKLOG.md, PROGRESS.md, DECISIONS.md, RESEARCH.md, RELEASE_READINESS_DESIGN.md.
Change policy: 01 edits data. Need a field? Write coordination/requests/<you>-to-01-director.md. `schema_version` bumps on breaking changes.
