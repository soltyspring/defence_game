# 06-art-ui handoff
Updated: 2026-11-01 ~02:00 KST. Session: this Kiro window (former 06-services). Quota at last check: not near 97%.

## Current task
UI art: audit → numeric criteria → redraw (bakery theme) → build → captures → review requests → commit.

## Done
- Audit tool `tools/art/ui_art/ui_audit.py` (no Godot): cards, skills, HUD capture, title logo.
- `docs/art/ui/UI_ART_AUDIT.md` (3 causes, numbers), `docs/art/ui/UI_ART_CRITERIA.md` (criteria, history, results).
- `tools/art/ui.py`: `card(uid, frame)`, `CARD_STYLE`, `CARD_CROP`, `badge_mask()`; skill_slam plate h, skill_barrage
  plate p; `icon_star_empty` rim X; `move_button` light bun. `portrait()` unchanged (enemies, boss, fallback).
- `tools/art/branding.py`: CRUST / MOULD ramps (all face colours ≥ 3:1 on #3d517a). Frame sizes unchanged.
- Previews without build.py: `tools/art/ui_art/card_preview.py`, `logo_preview.py`.
- Build from a clean `git archive HEAD` copy + my two files (`%TEMP%\ui06_headbuild`): only ui_main, ui_title_ko,
  ui_title_en, manifest.json (disk_bytes), ATLAS_BUDGET.md and the 3 atlas_ui_* previews change.
  battle_mock_1x/2x previews also change (UI icons in the mock; not mine, left at HEAD).
  `validate.py --determinism` PASS (clean copy). `asset_budget_check.py --tree` PASS, menu 0.50 MiB.
- Requests: `06-art-ui-to-03-art.md` R1 (build.py one line), `06-art-ui-to-04-client.md` (9-slices, HUD row).

## Warning for whoever builds
The shared working tree holds 09's WIP in `tools/art/bases.py` / `biome.py` and 03's in `chars_big.py`.
Running `build.py` in the shared tree writes bases/biome pages from that WIP. I did this once at ~01:50, then restored
those generated files to HEAD (`git checkout --` on bases.*, biome_meadow.*, atlas_bases/biome previews,
sheets/base_*.png, battle_mock_*). Build in a clean copy instead.

## Next
1. Wait for `build/ui06/capture_run.log` (detached, inside heavy_run, label 06-ui-capture). Shots in
   `build/ui06/shots/` (before/after × ko/en × 1x 800x360 / 2x 1600x720). Check menu logo, r01 HUD, result.
2. Commit (Publish-Task -Role 06-art-ui): tool, docs, evidence, ui.py, branding.py, previews tools, ui_main/ui_title_*
   png/json, manifest.json, ATLAS_BUDGET.md, atlas_ui_* previews, requests, status, handoff.
3. When 03 commits R1: rebuild in a clean HEAD copy, run `ui_audit.py --criteria` on the built atlas (expect PASS),
   capture r01 HUD again, commit ui_main.
4. Send before/after review requests to 03, 04, 07 (state: no human player test, no real-phone check).
