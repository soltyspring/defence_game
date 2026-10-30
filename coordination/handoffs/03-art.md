# 03-art handoff
Updated: 2026-10-31 08:05 +09:00

## Status
MILESTONE 2 delivered. Theme is the reversible default "Lantern Kingdom vs Bramble Horde" (Q1 PENDING, not user-approved). The first playable is an internal milestone, not release completion.

## Read receipts / processed IDs
BRIEF, OWNERSHIP, GIT_WORKFLOW, QUALITY_REVIEW.md (03 obligations: font assets/provenance, typography audit, visual refinements, secondary-monitor visible tests; all actioned below), WINDOW_STABILITY.md (no window restarts; complied), QUOTA_POLICY.md (usage 80.2% at 07:02, under the 97% checkpoint), coordinator-to-03-art through "Latest user checkpoint/CPU", gongmojeon SKILL.md (method applied in ART_AUDIT.md), DECISIONS D1–D12 + Q1 PENDING.
Requests processed: 01→03 R1 (ids, sizes: swarm now ~16 px), 02→03 R1 + R2 (no hand-written .import; Godot-generated ones committed), 04→03 R1 (font + manifest `fonts.ui`), R2 (white lines: art scan says not art; routed to 02), R3 (noted).
Outgoing: 03-art-to-02-engine A1–A3, 03-art-to-04-client A1–A3, 03-art-to-01-director A1. Delivery state: QUEUED until each owner acknowledges.

## Commits (all PUSHED origin/main)
- 9b4ee0b [Design] initial art pack + 6 atlases
- e93acdd [Docs] art direction / atlas contract / budget / evidence
- 6cf3d01 [Chore] prune renamed preview sheets
- 4088ae0 [Chore] Godot-generated atlas .import + exported-pack loading check
- 5e157e3 [Design] OFL Galmuri font subsets + provenance + real render checks
- (this round) [Design] hostile audit fixes: see the git log entry after 5e157e3
- Publish lesson: never pipe Publish-Task.ps1 through `2>&1` (git's fetch stderr becomes a terminating error and no commit is made).

## What exists (real paths)
- Runtime: `assets/manifest.json` (now with `fonts`), `assets/atlases/*.{png,json,png.import}`, `assets/fonts/{Galmuri11,Galmuri11-Bold,Galmuri9}.ttf(+.import)`, `OFL-Galmuri.txt`, `fonts_provenance.json`.
- Tools: `tools/art/build.py`, `validate.py [--determinism]`, `fonts.py <galmuri dir>`, `font_contact.py`, `run_godot_check.ps1` (draw calls, secondary monitor), `run_godot_pack_check.ps1` (exported PCK, headless), `run_godot_font_sheet.ps1` (device-emulated font renders, secondary monitor).
- Docs: `docs/art/ART_DIRECTION.md` (v0.4.0), `ATLAS_CONTRACT.md`, `ATLAS_BUDGET.md`, `TYPOGRAPHY.md`, `ART_AUDIT.md`. Evidence: `docs/art/evidence/**`.

## Validation evidence (actually run this round)
- validate.py PASS: bleed/extrusion/sampling simulation 0 foreign texels, palette, anim contract, data refs, tiling, determinism, Godot-generated .import (atlases + fonts), pixel-font params, font coverage of all data text.
- Exported pack (`--export-pack` + `--main-pack`): raw PNG absent, remap present, 6/6 pages load (ui_main now 256×256), 3 fonts load, Hangul present (Galmuri9 numeral-only by design). PCK 1,172,452 B.
- Font renders in the real Godot renderer, 5 emulated devices: 12/24 px Galmuri11/Bold regular at 1×/2×/3×/4×. 9/18/28 px (04's current sizes) and the 2.5× scale are irregular. Flags came from the .import alone.
- Visual fixes re-inspected on contact sheets + battle mock: swarm ~16 px, spear blade, faction markers, prop_mine, ribbons.

## Strongest rejection reasons / untested
- No Android device render (fonts, sprites, markers), no physical-size readability test, no player test.
- Runtime use of markers/prop_mine (02), font sizes 12/24/36 and ribbons (04), and the integer scale mode (02) are not done yet. These defects stay OPEN until they are wired and recaptured.
- White lines (A8) are unresolved and probably 02 runtime drawing; unproven.
- Theme unapproved (P1 schedule risk). Roster art still missing: fast, siege, e_brute, e_bomber, both bosses, 2nd biome.

## Next tasks (03)
1. Roster r04–r07: fast (mounted, 18 px footprint), e_brute (~36 px, 48×48), boss_warlord (~52 px, own page `char_boss_warlord`), siege, e_bomber; then boss_overlord.
2. Re-run the same-attack retests once 02/04 wire markers/prop_mine/fonts. Capture with 04's `tools/build/visible_launch.ps1` (secondary monitor).
3. Re-theme immediately if Q1 is answered.
