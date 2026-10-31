# 06-art-ui status
Updated: 2026-11-01 ~02:00 KST
Status: IN PROGRESS (UI art audit + first redraw; captures running).
- Role since 2026-11-01 01:08 KST (user: graphics are poor). Services are frozen under Q2 (closing note 496227b).
- **Audit:** `docs/art/ui/UI_ART_AUDIT.md`. 3 causes with numbers: all 7 cards identical (plate ΔE 0, IoU 1.00);
  plate, card body and figure outline at the same value (1.06:1, figure edge 2.18:1); skill glyphs 1.88 / 2.33:1 and
  the logo's mould line only 12–16% of glyph pixels ≥ 3:1 against the menu sky.
- **Criteria:** `docs/art/ui/UI_ART_CRITERIA.md` (C1–C7, G1–G4).
- **Redraw (tools/art/ui.py, branding.py):** per-unit card badges `ui.card()` (preview PASS), skill plates, empty star,
  move buttons, logo colour ramps (built PASS). 9-slices not redrawn: no screen uses them (asked 04).
- **Blocked on 03 R1:** one line in `build.py` so the built `card_*` use `ui.card()`.
- Not done: human player test, real-phone check.
