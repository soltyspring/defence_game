# Reference research (01-director)
Updated 2026-10-31. Content is paraphrased. We borrow genre conventions only, never names, art, story or text.
**Method limit: no hands-on play of any title and no player interviews were done.** "Observation" means what the primary source itself states (store listing, official docs, developer interview). "Inference" is my reasoning and is labelled as such.

## Sources (all accessed 2026-10-31)
| ID | Source (primary unless noted) | URL |
|---|---|---|
| S1 | Cat War2, Google Play listing (WESTRIVER) | https://play.google.com/store/apps/details?id=com.westriversw.CatWar2&hl=en |
| S2 | The Battle Cats, Google Play listing (PONOS) | https://play.google.com/store/apps/details?id=jp.co.ponos.battlecatsen&hl=en |
| S3 | Stick War: Legacy, Google Play listing (Max Games Studios) | https://play.google.com/store/apps/details?id=com.maxgames.stickwarlegacy&hl=en |
| S4 | Kingdom Rush, Google Play listing (Ironhide) | https://play.google.com/store/apps/details?id=com.ironhidegames.android.kingdomrush&hl=en |
| S5 | Interview with Ironhide co-founder A. Azofra (Kodeco, developer's own statements; interview format) | https://www.kodeco.com/2769-making-a-hit-tower-defense-game-a-top-app-dev-interview |
| S6 | Paladog on Kongregate (fazecat, 2012) | https://kongregate.com/games/fazecat/paladog |
| S6b | Secondary: JayIsGames Paladog review; Paladog fan wiki "Units" | https://jayisgames.com/review/paladog.php , https://paladog.fandom.com/wiki/Units |
| S7 | Nielsen, "Why You Only Need to Test with 5 Users" (NN/g), citing Nielsen & Landauer, INTERCHI'93 | https://www.nngroup.com/articles/why-you-only-need-to-test-with-5-users/ |
| S8 | AdMob policy: ad units offering rewards | https://support.google.com/admob/answer/7313578?hl=en |
| S9 | Android: Make apps more accessible (contrast, touch targets) | https://developer.android.com/guide/topics/ui/accessibility/apps |
| S10 | Android vitals: core vitals and bad-behaviour thresholds | https://developer.android.com/topic/performance/vitals |

## Observations (what the sources state)
- S1: workers are trained to gather resources; troops are deployed to destroy the enemy base; hero units have special abilities; the game also has mini-games and many heroes.
- S2: one tap deploys a unit; a base "cannon" hits nearby enemies; choosing the right squad against "weird enemies" is the core; units level up with XP and items; hundreds of stages in three story modes. The listing says a network connection is needed for reliable access.
- S3: mine gold, build units, control the army in formations or play any single unit directly, destroy the enemy statue. Several difficulty crowns, weekly missions, a zombie survival mode, tournament vs AI, and skins with perks.
- S4: heroes and towers, enemies with their own abilities, boss fights, an in-game encyclopedia of enemies and heroes, achievements, and offline play stressed repeatedly.
- S5: the developers wanted the player busy and involved during battle rather than watching. Mobile porting problems they name are memory and screen aspect ratios.
- S6/S6b (partly secondary): hero moved directly left/right; units auto-walk and cannot be steered; food pays for units, mana for specials, both regenerate.
- S7: with problem-discovery rate L ≈ 31% per user, 5 users reveal about 85% of usability problems. Iterate several small tests rather than one big test. Distinct user groups need 3–4 users each. Quantitative metrics need more users (NN/g suggests about 20).
- S8: rewarded ads require prior disclosure, an affirmative opt-in, skippable or dismissable ads, no misleading incentive text, and delivery of the promised reward. Random rewards need disclosed odds.
- S9: touch targets at least 48×48 dp; text contrast ≥ 4.5:1 below 18 sp (3:1 otherwise).
- S10: core vitals affect Play visibility. Bad-behaviour thresholds include a user-perceived crash rate of 1.09% overall and an ANR rate of 0.47% overall. Games have per-RAM-tier memory thresholds (e.g. 2.25 GB foreground for 4 GB devices). Play uses the last 28 days of data.

## Inferences and resulting design choices
| Inference (labelled) | Design choice | Limit |
|---|---|---|
| The genre's core is unit choice against enemy variety (S2, S3), so counters must actually matter | QUALITY_BAR claim 3 with mono-unit sim test | If the sim shows mono spam wins, the counter design is failing, whatever the docs say |
| Stick War (S3) and Paladog (S6) give direct control; Battle Cats (S2) does not. Direct control is a real differentiator axis | Keep one directly steered hero plus auto units; test that the hero matters but does not carry (claim 2) | Preference for control is not evidenced for our audience |
| Leaders compete on volume (S2 "hundreds of stages", S3 many modes) | Do not compete on volume at launch. Grow content with data-only modes (challenges, endless) and atlas reuse (RELEASE_DESIGN_REVIEW §6) | Low volume may still lose players. Unverified (claim 8) |
| Offline play is a selling point some leaders advertise (S4), and S2 requires a network | Keep the game fully offline-playable. Ads are optional and must never gate play | Whether players value offline is unmeasured |
| An encyclopedia and boss intros help players learn counters (S4) | Enemy desc_key and codex (B21) | Content cost is text only |
| Being "busy" during battle is intended engagement (S5) | Worker, card and skill decisions every 2–4 s (GDD pillar 2) | Busy ≠ meaningful. Claim 1 tests whether choices are real |
| Memory and aspect ratio were the developers' main mobile pain points (S5) | Supports per-biome atlas residency and the 640×360 expand layout (ENGINE.md) | 02/03/08 own the measurements |
| 5-user pilots find common problems, not rates (S7) | RELEASE_DESIGN_REVIEW §8.2 rewritten as problem discovery; rate claims deferred to §8.3 | L = 31% comes from usability studies. Transfer to game difficulty is assumed |
| Ad policy constrains design (S8) | Rewarded placements are opt-in at results or rescue only; disclosure text required; no misleading "support us" copy | Only relevant if Q2 picks ads |
| Platform thresholds are concrete release gates (S9, S10) | 48 dp minimum touch targets (56 preferred) and 4.5:1 contrast in UI requirements; crash/ANR thresholds belong in the 04/08 release checklist | Thresholds can change. Recheck at release |

## Deliberate differences from references
Hero death is not a loss (respawn timer). Deterministic waves, trickle and HP triggers. Star objectives. Role-based data allows a retheme. Original theme options (Q1, unanswered) avoid cats/dogs and a paladin-dog hero.
