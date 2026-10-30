# Decision log (01-director)
Format: ID | date | status (DECIDED by user / DEFAULT reversible / PENDING) | decision | implications.
A DEFAULT is never user approval.

| ID | Date | Status | Decision | Implications |
|---|---|---|---|---|
| D1 | 2026-10-31 | DEFAULT | Theme-neutral role IDs in data; display names via text keys | Q1 answer only changes text/art, not data IDs or code |
| D2 | 2026-10-31 | DEFAULT | Landscape, 640×360 logical reference units | 02 camera/scaling, 03 sprite scale, 04 HUD layout |
| D3 | 2026-10-31 | DEFAULT | Two in-round resources (supply, energy) + gold meta | HUD shows 2 bars + gold on menus |
| D4 | 2026-10-31 | DEFAULT | Workers abstract, invulnerable in MVP | no worker AI/combat needed in P0 |
| D5 | 2026-10-31 | DEFAULT | Hero death = respawn timer, not loss | loss only on base HP 0 |
| D6 | 2026-10-31 | DEFAULT | Deterministic waves + trickle + HP triggers | headless tests reproducible |
| D7 | 2026-10-31 | DEFAULT | Entity caps 30 ally / 40 enemy / 64 projectiles (provisional) | pooling sizes; 02/04 may lower after profiling |
| D8 | 2026-10-31 | DEFAULT | No stamina/energy-gate system | retention via stars/unlocks |
| D9 | 2026-10-31 | DEFAULT | Monetization hooks present but disabled | no SDK work until Q2+ answered |
| D10 | 2026-10-31 | DEFAULT | Follow 02 contract: flat armor, worker cost ×1.3, data split per INTERFACES §2, meta in data/meta.json | design ★ keys requested from 02 |
| D11 | 2026-10-31 | DEFAULT | Human pilots are problem discovery only (5 players, decision rules fixed in advance). No human win-rate targets until a ≥ 35–97 player closed test exists | RELEASE_DESIGN_REVIEW §8, QUALITY_BAR; 07 pilot logistics later |
| D12 | 2026-10-31 | DEFAULT | Persistent currency label "골드" (ui.coins overrides 04 fallback "코인") | 04 UI text; consistent with currency.gold |
| Q1 | 2026-10-31 | PENDING | Theme/characters: A bakery (recommended) / B forest / C lantern | blocks final art, names, title |
