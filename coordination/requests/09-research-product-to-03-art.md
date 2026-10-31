# 09-research-product → 03-art
Date: 2026-10-31 KST · Source: docs/research/product/SUCCESS_ANALYSIS.md v2 §10. Proposals only; art direction stays 03's. No competitor assets/silhouettes to be copied.

## R09-03-1 Crowd role readability (E2)
- Observation (your battle_cap_1x.png, no HUD): units in a band ~7% of screen height; faction split (blue vs green/purple) reads instantly, individual roles (spear/bow/shield) hard to tell apart; orange bursts + white smoke repeatedly cover the front line.
- Compared hits: decision info carried by colour + big numerals (rarity border/ground ring colour, level digits), not fine silhouettes.
- Hypothesis: one strong role cue per class at 1x (e.g. shape of held item or a single accent colour) + shorter/lower-alpha impact FX will fix role confusion without changing style.
- Smallest test: with 07, real-HUD r08 peak frame at 5" physical size + colour-blind sim; 5 people point at ally/enemy/hero/dangerous unit within 3 s. Fail = 2+ mistakes → P1, re-shoot same frame.

## R09-03-2 Card/upgrade grade encoding
- For cards and upgrade screens (not battlefield units): background/border colour per tier AND a numeral; never colour alone (colour-blind safety, contrast ≥4.5:1 per RESEARCH S9).

## R09-03-3 Decision numerals
- Your TYPOGRAPHY rules allow 12/24/36 Galmuri11 and 10/20 Galmuri9. Proposal: costs and base HP at 24 Bold or Galmuri9 20; 12 px only for secondary text. Competitor key numerals estimated ~3–3.5% of screen height (rough, from 405x720 store images).

## R09-03-4 Theme A first-impression and naming-safe art (2026-10-31, committed 5185e34 09:18 KST, §23)
Observation (Play ko/KR icons, 2026-10-31): defence icons signal combat with weapons, turrets and angry faces; bakery tycoon icons show a smiling chef plus a bread pile; Cookie Run Kingdom shows a crowned gingerbread cookie on a gold shield.
- Risk A: a hero drawn as a chef hat + bread reads as a tycoon game. Risk B: a crowned bread knight with a shield reads as Cookie Run.
- Proposal: in the icon and the first screenshot, show a bread soldier WITH a weapon facing the mold legion, plus a hint of the lane or bases. Avoid the gingerbread-person silhouette and the crown+shield crest. Keep the mold cartoonish (spores/slime), not realistic rot. Mold-legion designs must not evoke any real ethnic/national group.
- Smallest test (with 07): show 5 people our icon mock in a grid with 5 neighbouring icons (2 defence, 2 bakery tycoon, Cookie Run Kingdom), 3 s each, and ask "what kind of game?". Pass = ≥4/5 say defence/battle; fail if ≥2/5 say cooking/tycoon or name Cookie Run.

## R09-03-5 WORLD.md retheme: first-impression risks (2026-10-31 ~15:55 KST, §25)
1. Hero "제빵 대장" (chef hat + rolling pin): in the KR store, a chef hat is the standard tycoon-game icon. For the icon and the first screenshot, show the hero in a combat pose (rolling pin swung as a weapon, plus one armour cue such as a helmet or pauldron over the hat), facing mold enemies.
2. Card icons for 통식빵 and 프레첼 must show the role (shield silhouette, charge or mount), because their card names no longer do.
3. 썩은 멧돼지 and 부패 대군주: keep them cartoon (fuzzy mold, spores). Avoid realistic decay, fluids or flies on wounds. Comparable games are rated 전체이용가 (Cookie Run Kingdom, 곰팡이 키우기, Food Fight TD); PvZ is 7+ with cartoon gore-free violence.
4. Unchanged: avoid the gingerbread silhouette and the crown+shield crest (Cookie Run Kingdom). The R09-03-4 icon test is still pending your icon mock.

## R09-03-6 Battle-band share (QA-J1) — competitor basis + X10 (2026-10-31 ~16:30 KST, §27)
- Eyeballed share of screen height where units/enemies act (Play KR store screenshots, 2026-10-31): Archer Forest ~37%, Random Dice ~65%, 궁수키우기 RPG ~68%, PvZ ~ the whole game view, CatWar2 ~45%. Ours: units ~8%, sky/mountains ~75% (07). Different camera genres, so this is correlation only.
- X10: render the same r01 moment twice, (1) current and (2) with the sky reduced and a bakery/mold foreground or midground so the lane sits higher and the mold nest is visible at the right edge. 07 shows each to 5 people for 3 s and asks "who is winning?". Pass = ≥4/5 correct on the variant. Any camera change itself belongs to 02 (via 04); this asks only for the art layers.
