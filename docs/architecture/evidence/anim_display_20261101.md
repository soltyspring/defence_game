# Animation display: deaths fade too early (QA-B025), hit / cast never drawn (QA-O006) — 2026-11-01

Owner: 02-engine. Rules: 07 docs/verification/ART_BASELINE.md §5 (A4, A6, A6b are 02 + 03; A1, A1c, A2, A3, A5 are 03).

## Pass conditions, written before the change
| ID | Engine part (02) | Pass condition for this change | How it is checked |
|---|---|---|---|
| A6 | the fade must not hide death frames | every death frame of every unit id is drawn at alpha 1, from the first to the last frame; the fade starts only after the last frame (then 0.3 s on the last frame) | headless probe `src/core/diag/anim_display_probe.gd`: share of death frame-time drawn at alpha ≥ 0.99, per unit id = 100 % |
| A6b | same | ≥ 60 % of death frames readable — with alpha 1 for all frames this depends only on the art (03, A5); the engine part is "100 % of death frames drawn at alpha 1" | same probe; 07 `art_compare.ps1` rows A6/A6b after 07 updates its fade model to `BattleView.death_alpha()` |
| A4 | the hit reaction is drawn | the 2-frame `hit` animation is drawn after a hit (once, re-armed after 0.6 s, not while the unit's attack animation is playing); the 0.12 s red flash stays (A4 ΔE ≥ 15 already PASS) | probe: hit frames drawn > 0 for every unit id that took damage, in real r06 / r08 battles |
| QA-O006 | the hero `cast` animation is drawn | the hero's 6-frame `cast` animation plays on every successful skill cast | probe: cast frames drawn = casts × cast length |
| — | no gameplay change | bot outcomes identical: the selftest round times stay r01 101.8 … r10 851.6 s, 07 sim suite unchanged | selftest + 07 `--only=sim,flow` in a clean snapshot |
| — | hero death visible | the hero's death animation is drawn (before: the hero was not drawn at all while respawning, so its death was never seen) | probe: hero death frames drawn after a hero death |

Not judged by tools: whether the deaths "feel" right (human test, ART_BASELINE §5 last row).

## Engine rules (values 03 needs; sent in 02-engine-to-03-art.md)
- Corpse time `BattleSim.DEATH_TIME` = 1.5 s (was 0.7 s). Alpha = 1 while the death animation plays, then the last frame holds and fades
  linearly over `BattleView.DEATH_FADE` = 0.3 s. A death animation longer than 1.2 s is cut by the fade (today's longest: boss_overlord 1.143 s).
- Hit: `hit` plays once from frame 0 after a damaging hit, at most once per `BattleSim.HIT_REARM` = 0.6 s, and not while the unit's
  attack animation is still playing. Today every `hit` is 2 frames at 10 fps = 0.2 s; keep it ≤ 0.6 s.
- Cast: the hero's `cast` plays once per successful skill cast, over walk / idle / attack / hit. Today 6 frames at 12 fps = 0.5 s.
- Priority per frame: death > cast (hero) > attack (while its frames play) > hit > attack hold > walk / idle.
- Gameplay timers are unchanged: corpses were already ignored by targeting, caps and counts; only the visual corpse time changes.
