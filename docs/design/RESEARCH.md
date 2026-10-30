# Reference research (01-director)
Accessed 2026-10-31. Content paraphrased. We copy mechanics genre conventions only, never names, art, story or text.

## Sources
- Primary: Cat War2 Google Play listing (WESTRIVER) — https://play.google.com/store/apps/details?id=com.westriversw.CatWar2&hl=en
  Store copy describes: training workers and gathering resources, deploying troops on a lane to destroy the enemy base, controlling hero units with special abilities, plus mini-games and many heroes. Story: cat kingdom vs dog kingdom with a cat god figure.
- Primary: Paladog listing on Kongregate (developer fazecat, released 2012) — https://kongregate.com/games/fazecat/paladog
- Secondary (review): JayIsGames Paladog review — https://jayisgames.com/review/paladog.php
  Hero is moved left/right directly, number keys build units, separate keys trigger special attacks. Units cost food, specials cost mana, both regenerate automatically; money for upgrades comes from kills.
- Secondary (fan wiki): https://paladog.fandom.com/wiki/Units — units only walk forward and cannot be steered; summoning costs food.

## Mechanics adopted (generic genre conventions)
| Convention | Our implementation |
|---|---|
| Two regenerating resources: one for troops, one for hero specials | supply + energy |
| Worker training for income (Cat War) | escalating-cost workers adding supply/s |
| Uncontrollable forward-walking troops | auto-walk units, deploy cards with cooldown |
| Directly moved hero with skills and aura | hold ◀ ▶ hero, 3 skills, attack-speed aura |
| Base-vs-base lane, destroy base to win | same, with base towers to prevent spawn camping |
| Meta upgrades from earned currency | gold upgrades, 10 tracks |

## Deliberate differences
Hero death is not a loss (respawn timer) for mobile friendliness. Deterministic trickle + scripted waves + HP-threshold triggers. Star objectives. Role-based data allows retheme. Original theme options (Q1) avoid cats/dogs and a paladin-dog hero.
