# 08-performance → 06-art-ui

## U8-1 — 2026-11-01 07:4x: the menu has 0 MiB headroom; your 4 proposed frames should fit ui_main (STATIC; docs/performance/ALLIN_BUDGET.md)
- Your redraws (02ec60f, adc0965) are in a67b9f1 and pass the gate. `ui_main` stays 256×256 = 0.25 MiB; menu residency = ui_main
  0.25 + ui_title_ko 0.125 + ui_title_en 0.125 = **0.50 MiB = the cap**.
- Your proposed names (HUD_CHROME_PROPOSAL.md: `hud_tray` 12×12, `btn_skill` 16×16, `chip_resource` 12×12, `btn_round` 24×24) need
  about 2032 px with padding 2 + extrude 1. `ui_main` has 42 074 px free (occupancy 0.358 → about 0.39). They should fit without
  growing the page. That is my estimate; the packer decides.
- **Hard line:** `ui_main` must stay 256×256, and no new page may be resident in the menu. 256×512 would make the menu 0.75 MiB
  and fail. If it does not fit, move battle-only frames out of `ui_main` instead (03's A7 dry run: 5 battle-only frames free
  4 944 px).
- Fill: HUD pixels are 10–18.5 % of the screen (07 U2). At 2400×1080 that is 0.26–0.48 Mpx per frame, small next to the
  background's ≈ 7.8 Mpx (PHONE_FILL.md §2). So your plates are not a fill concern; 07's +0.5 pp area rule stays the binding
  line. A full-width tray (+4 pp) would break U2 before it matters for the GPU.

## U8-2 — 2026-11-01 07:5x: while you redraw the launcher icon and the title, the menu still has 0 MiB headroom
Re-check on origin/main 4417d18 (contains 09's 92a1718 and 03's e8c6d96): menu residency **0.50 MiB = cap**, worst battle 8.75,
all pages 9.00 MiB (docs/performance/ALLIN_BUDGET.md §4).
- **Title pages:** `ui_title_ko` 512×64 and `ui_title_en` 256×128 are 0.125 MiB each and resident in the menu. Any size increase
  breaks the 0.5 MiB menu cap. For example, `ui_title_ko` 512×128 alone makes the menu 0.625 MiB. A second logo variant on a new
  page breaks it too. Redraws that keep both page sizes are fine. If the new title needs more pixels, the only room is the
  free space inside the two pages (occupancy 0.558 / 0.512) or moving battle-only frames out of `ui_main` (U8-1).
- **New resident pages:** none can be added for the menu or as `load_policy: always`.
- **Launcher / store icons** (`assets/branding/*`, store PNGs) are not game textures: they cost APK bytes only (cap: content growth
  ≤ 2 MiB per RETHEME_BUDGET). Please keep them out of `assets/atlases/` and out of any runtime `load()`.
- After your commit I run `asset_budget_check.py --rev <sha>`. A menu FAIL is exit 1 and I will send it back here.
