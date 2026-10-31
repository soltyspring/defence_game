# 06-art-ui handoff
Updated: 2026-11-01 ~02:35 KST. Session: this Kiro window (former 06-services). Quota: not near 97% at last check.
Processed: coordinator 01:08 (role), 07-qa-to-06-art-ui (02:17, use 07's fixed set).

## Current task
UI art: audit → criteria → redraw → build → captures → review requests → commit. Waiting on 03 R1 for the cards.

## Done
- 1d359bc: audit tool `tools/art/ui_art/ui_audit.py`, `docs/art/ui/UI_ART_AUDIT.md`, `UI_ART_CRITERIA.md`, before evidence,
  requests to 03 (R1) and 04.
- 700692d (pushed origin/main): `tools/art/ui.py` (`card()`, `CARD_STYLE`, `CARD_CROP`, `badge_mask()`, skill plates,
  `icon_star_empty`, `move_button`), `tools/art/branding.py` (CRUST/MOULD ramps), `tools/art/ui_contrast.py` (card background
  read for shaped badges, worst pair), previews `card_preview.py`, `logo_preview.py`, capture runner `ui_capture.ps1`,
  `capture_compare.py`; rebuilt `ui_main`, `ui_title_ko`, `ui_title_en`, `manifest.json`, `ATLAS_BUDGET.md`, atlas_ui_* previews.
- Pages built in a clean `git archive HEAD` copy (`%TEMP%\ui06_headbuild`) + my files. Changed vs HEAD: only my 3 pages,
  manifest disk_bytes, budget lines, my previews; battle_mock_1x/2x previews also change (UI icons) and were NOT committed (03's).
- R1 sandbox `%TEMP%\ui06_r1` (copy's build.py patched): ui_audit PASS, determinism PASS, ui_contrast PASS; only card_* differ.
- Captures: `build/ui06/shots` (git-ignored), sheets `docs/art/evidence/ui_art/cmp_{ko,en}_1x.png`.
- A second run (`ui_capture.ps1 -Capture narrow -Scales 2x`, 07's capture_narrow.gd r08, label fit) was queued detached
  at ~02:20 (log `build/ui06/capture_narrow.log`).

## Warning for whoever builds
The shared tree holds 09's WIP in `tools/art/bases.py` / `biome.py` and 03's in `chars_big.py`. `build.py` in the shared tree writes
bases/biome pages from that WIP. I did that once (~01:50) and restored those generated files to HEAD. Build in a clean copy.

## Next
1. When 03 commits R1: clean HEAD copy build → copy ui_main png/json (+ manifest/budget/preview if changed) → `ui_audit.py --criteria`
   on the built atlas (expect PASS) → commit.
2. Run 07's set on that SHA (ART_BASELINE.md §4, all four tags), `art_metrics.py`, compare with art-baseline-ad47eda; report U1/U2/U3/G3.
3. Read `capture_narrow.log` / shots `*_narrow_*` and the report's truncated flags (label fit).
4. Review requests to 03, 04, 07 with before/after (state: no human player test, no real-phone check).
