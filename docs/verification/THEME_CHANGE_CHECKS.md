# Theme change checks — Q1 = A "빵집 기사단 vs 곰팡이 군단" (owner: 07-qa)
Created 2026-10-31 09:15 +09:00. The decision reached 07 through the coordinator. At this time `docs/design/DECISIONS.md` on disk still lists Q1 as PENDING; 01 must record the literal answer there (request sent). These checks do not depend on the exact names and start failing the moment renamed text or recoloured art breaks a rule.

Run: `.\tools\qa\run_acceptance.ps1 -Head -Only theme,data,assets,flow` (clean committed HEAD only). Desktop headless; not device certification.

| Risk | Check (suite) | Rule | Status at HEAD 5426645 (run 20261031-091441) |
|---|---|---|---|
| Text keys missing after rename | TH-TEXT-KO / TH-TEXT-EN (theme), DATA-07/08/09/12 (data) | every card/skill/round/hero/enemy name key exists in ko and en, not empty, not equal to its key or id; placeholder parity | PASS (current names) |
| Engine/UI keys without text | DATA-13/14, FLOW-04B | every `ui.*`/`toast.*` key used in src exists in both locales; HUD never shows a raw id | DATA-13/14 FAIL: 5 `toast.*` keys missing in data/text (QA-B008); FLOW-04B PASS (HUD no longer shows the raw id) |
| Name length → clipping in HUD | TH-FIT-HUD-KO / -EN | every *drawn* card/skill label fits `button width − 6` with the bundled UI font at 12 px, for each round's own card/skill count, at 640×360 with 34 px notches on both sides. Icon-only buttons (icon + cost on a button < 54 px, TouchButton.show_name rule) are listed in evidence, not measured | KO PASS · EN FAIL: r08–r10 cards "Troop/Archer/Shield/Raider" 37–42 px > 36.7 px |
| Name length → round-select tiles | TH-FIT-ROUND-KO / -EN | round names fit the 5-column tile at the same safe area (83 px) | KO PASS · EN FAIL: 7 of 10 names ellipsised |
| Ally vs enemy colour confusion | TH-COL-NORMAL / PROTAN / DEUTAN / TRITAN | closest ally/enemy pair of mean sprite colours (walk frame 0, opaque pixels) differs by ΔE76 ≥ 2.3 (one just-noticeable difference) after Machado 2009 full-severity simulation | NORMAL, TRITAN PASS · PROTAN FAIL ΔE 1.18, DEUTAN FAIL ΔE 2.24 (archer `ranged_basic` vs `boss_warlord`) |
| Old screenshots used as a visual baseline | runner `stale_baselines.txt` | committed `docs/**/*.png` older than the newest commit touching `assets/atlases`, `assets/fonts` or `data/text` | 40 of 69 committed images predate baseline d6cf7df (list: runs/head-5426645-stale-baselines.txt). After the theme art lands, every visual verdict must use a new HEAD capture |
| Theme art not resolving | ART-03..08 (assets) | P0 characters, projectiles, fx, biome, icons and bases resolve to atlas frames | PASS (current art) |

## Limits of these checks
- Mean-colour ΔE is a proxy. It ignores silhouettes, the friend/enemy marker 03 added, facing (enemies are mirrored) and outlines. A FAIL means "colour alone does not separate this pair"; a PASS does not prove readability. Human review of real frames, including a CVD simulation of a full battle frame, is still required (secondary monitor only).
- Fit checks use the committed layout code and font metrics; they do not render. Visual tofu (missing Hangul glyphs) is not detected here.
- 36.7 px is the narrowest card label width the committed HudLayout produces (5 cards + worker + 3 skills, notch insets 34+34); D13 already names this slot.
