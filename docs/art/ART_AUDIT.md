# ART_AUDIT.md — hostile visual/type review (owner: 03-art)
Round 1 · 2026-10-31. Method adapted from the gongmojeon skill (QUALITY_REVIEW.md): observed problem → source/screen → player impact → severity → owner → fix → acceptance check → recheck evidence. No invented scores, user research or device results. Severity: P1 = release risk, P2 = clear quality defect, P3 = polish. "Fixed" here means fixed in 03's files and re-checked with the same attack. Runtime wiring by other owners is listed separately.

## Strongest reasons to reject the current visuals (before this round)
1. Korean text had no bundled font, so Android could show tofu (04 measured 127/131 UI characters missing from the fallback font).
2. Text sizes and non-integer device scales break the pixel grid (measured, see A2/A3).
3. In crowded melee the two armies merge into one mass. Faction is carried only by hue (docs/art/evidence/battle_cap_zoom4_fractional.png).
4. The theme is unapproved (Q1 PENDING), so all character art may need redrawing. 03 cannot fix this alone.

## Findings
| ID | Observed problem | Evidence | Player impact | Sev | Owner | Fix | Acceptance check | Recheck result | Status |
|---|---|---|---|---|---|---|---|---|---|
| A1 | No bundled Korean font | 04 typography_report (127/131 missing) | Tofu boxes on some phones, unreadable UI | P1 | 03 (asset), 04 (wiring) | Galmuri11/Bold subset with all 11,172 syllables, OFL licence, provenance, manifest `fonts.ui`. validate.py fails on any missing data glyph | Fonts load from an exported PCK, Hangul present, coverage check passes | pack_check.json: 3 fonts loaded, Hangul missing only in numeral-only Galmuri9 (intended). validate PASS | **Fixed (03)**. Android render still untested |
| A2 | UI sizes 9/18/28 px are not multiples of the 12 px font grid | font_contact_1to1.png, font_regularity.json: `irregular=1.0` at every scale except 18 px@2× / 28 px@3× | Uneven stems and shimmer. 9 px Hangul ≈ 1.6–1.8 mm, too small | P2 | 04 | Snap sizes to 12/24/36 (numerals 10/20) | Every text row regular at 2× and 3× | — | Open (requested 04 A2) |
| A3 | Non-integer content scale (1600×900 → 2.5×) | font rows `NON-INT` at 2.5× | Every 1 px outline/font pixel becomes 2 or 3 device px, so the pixel grid looks inconsistent | P2 | 02 | `stretch/scale_mode="integer"` | 2.5× device renders at 2× and text rows are regular | — | Open (requested 02 A2c) |
| A4 | Swarm beetle ~13 px tall vs 01 guidance ~16 px | sheets/e_swarm.png (before), 01 R1 | Hard to target or read among taller infantry | P2 | 03 | Redrew it bigger: 32×24 frame, body 18 px long, ~16 px tall incl. outline, 2 px legs | Height ≥15 px, silhouette distinct from grunt | sheets/e_swarm.png, battle_mock_2x.png: ~16 px tall | **Fixed** |
| A5 | Spear head read as a grey blob at 1× | sheets/melee_basic.png (before) | Spearman role unclear vs other infantry | P3 | 03 | 5 px leaf blade with brass collar and highlight tip | Blade shape identifiable at 1× | sheets/melee_basic.png (after) | **Fixed** |
| A6 | Overlapping melee: allies and enemies merge | evidence/battle_cap_zoom4_fractional.png | Can't tell who is winning the front line | P2 | 03 asset, 02 draw | `fx_combat` frames `marker_ally_{s,m,l}` (blue) and `marker_enemy_{s,m,l}` (red): front-half 1 px ground arcs drawn under each unit after the shadow | Each unit's faction readable at 1× even when sprites overlap | battle_mock_2x.png: blue/red arcs under every unit, restrained (1 px) | Asset fixed. **Runtime open (02)** |
| A7 | Worker destination is a brown placeholder rectangle | 04 capture build/qa/visible/screen_20261031_071349_008s.png (left of keep) | Breaks visual cohesion right next to the hero spawn | P3 | 03 asset, 02 draw | `bases` sprite `prop_mine` (48×32, lantern flicker, ore cart) | Prop drawn instead of rect | sheets/prop_mine.png | Asset fixed. **Runtime open (02)** |
| A8 | Two 1 logical px pale vertical lines in the real game | Reproduced 2026-10-31 07:39 on the secondary monitor: docs/art/evidence/whitelines/real_game_r01_5s_secondary.png (device x 432–433 and 570–571) | Looks like a rendering bug | P2 | 02 | Root cause (analysis.json): `battle_view.gd::_draw_biome_layers` rounds each parallax copy separately with `roundf`; .5 offsets (cam_x 230 × (1−par)) round half away from zero, so copies sit 641 px apart and the sky shows through. Lines match the far (285) and mid (216) seams; ground has none. Not an atlas defect | Same capture has 0 isolated pale columns | — | **Open (02, A4 request)**. Not fixed until a secondary-monitor recapture passes |
| A9 | No victory/defeat banner art | result screen uses text only (04) | Win/loss feedback weak | P3 | 03 asset, 04 use | `ui_main` 9-slices `ribbon_victory` (gold) / `ribbon_defeat` (red), margins 8,4,8,4 | Banner behind ui.victory/ui.defeat text | atlas_ui_main.png | Asset fixed. **Use open (04)** |
| A10 | Theme unapproved | DECISIONS.md Q1 PENDING | Possible full character redraw | P1 (schedule) | 01/user | Kept ids/rig/frames theme-agnostic | — | — | Open |
| A11 | Hit feedback relies on the 2-frame `hit` pose only | sheets/*.png | Damage on small units is easy to miss | P3 | 02 | Recommend a 1-frame white modulate flash on damage + `hit_spark` fx (already in atlas) | — | — | Recommendation |

## Same-attack retests performed this round
- A4/A5/A6: rebuilt (`python tools/art/build.py`), `validate.py` PASS (bleed, palette, contract, determinism unchanged). Re-inspected sheets/e_swarm.png, sheets/melee_basic.png and battle_mock_2x.png.
- A1: `pwsh tools/art/run_godot_pack_check.ps1` (exported PCK) and `pwsh tools/art/run_godot_font_sheet.ps1` (real renderer, 5 emulated devices, window on the secondary monitor).

## Not evidence (do not cite as proof)
Desktop GPU numbers, emulated-device SubViewports, and my own visual judgement are not phone tests or player tests. Android device captures (04/07) and device profiling (08) are required before release.
