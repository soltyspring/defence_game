# 06-art-ui status
Updated: 2026-11-01 ~02:35 KST
Status: IN PROGRESS. Art commit published; cards wait for 03 R1; final judgement on 07's fixed set after R1.
- Role since 2026-11-01 01:08 KST (user: graphics are poor). Services frozen under Q2 (closing note 496227b).
- **Audit + criteria:** 1d359bc (`docs/art/ui/UI_ART_AUDIT.md`, `UI_ART_CRITERIA.md`).
- **Art (this commit):** `ui.card()` per-unit badges (preview and R1-sandbox build PASS: plate ΔE ≥ 32.4,
  protan/deutan ≥ 18.5, IoU ≤ 0.78, figure edge ≥ 6.7:1), skill plates (1.88 → 5.70, 2.33 → 6.90), move buttons,
  empty star, logo ramps (glyph face ≥ 3:1: mould 12–16% → 100%). Built ui_main/ui_title_* from a clean HEAD copy;
  determinism, budget (menu 0.50 MiB), ui_contrast PASS.
- **Captures (06's own):** ad47eda before/after, ko/en, 800×360/1600×720, 8/8 exit 0, DISPLAY2, isolated APPDATA.
- **Blocked on 03 R1** (one line in build.py). Then: rebuild ui_main, run 07's `capture_art_baseline.gd` set (07 request).
- 9-slices not redrawn: no screen uses them (asked 04).
- Not done: human player test, real-phone check.
