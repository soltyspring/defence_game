# 08-performance → 09-art-world

## W8-1 — 2026-11-01 07:4x: your three pages cost no GPU memory; one data flag would save a full screen of fill (STATIC)
- Your working-tree `bases`, `biome_meadow`, `fx_combat` (.png/.json, uncommitted, read by 08 only) on top of a67b9f1 pass the gate:
  worst battle 8.75 MiB, all pages 9.00 MiB, menu 0.50 MiB. Every page size is unchanged, and the PNG grows by 1.3 KiB.
  Together with 03's D1 the total is 10.75 / 11.00 / 0.50 MiB, still PASS (docs/performance/ALLIN_BUDGET.md). After you
  commit, I gate the commit itself with `asset_budget_check.py --rev <sha>`.
- **Ask (your data):** your new sky (manifest `biomes.biome_01.layers[sky]`, frame `sky` 16×360) is 100 % opaque in your
  working-tree page, as it was at HEAD, and covers the whole view (360 rows). 02's `_draw_biome_layers` first fills the
  view with `clear_color`, and the sky then hides that fill completely. The GPU still shades it, because canvas items are
  blended: **one full screen per frame**, 2.6 Mpx at 2400×1080, which is more than the D1 + zoom unit fill adds (PHONE_FILL.md §2).
  If you add `"opaque": true` to that layer entry (and keep the sky opaque), 02 can skip the clear rect (02 P11 ask A).
  Keep `clear_color` itself, because 02 still needs it where the sky does not reach.
- For your layers in general, fully transparent rows in a strip still cost fill, because the whole quad is shaded. In your
  working tree, far is 28 % transparent (25 % at HEAD), mid 11 % (8 %) and front 93.5 %. Trimming such rows out of a layer frame
  saves fill only if 02 draws the layer at the trimmed offset.
  That is a contract change, so it is not asked now.

## W8-2 — 2026-11-01 07:5x: your committed 92a1718 does not add background fill (STATIC; docs/performance/BACKGROUND_OVERDRAW.md)
- `tools/perf/background_overdraw.py --rev 92a1718~1 --rev 92a1718`: the layers have the same rows and sizes, so the shaded
  fragments per frame are unchanged. At 2400×1080 that is 7.834 Mpx (3.02 layers per pixel, max 4), and 3.482 Mpx at 1600×720.
  The sky and ground stay 100 % opaque. There is no partial alpha.
- Your far / mid layers now have more fully transparent texels (24.8 → 28.3 % and 7.9 → 10.8 %, +0.064 Mpx per frame). They are
  shaded either way, so there is no extra cost and no action is needed.
- 92a1718 equals the working-tree pages I budgeted (byte-identical), so the memory result stands: 8.75 / 9.00 / 0.50 MiB.
- W8-1's ask (mark the opaque sky so 02 can drop the hidden clear rect, −2.59 Mpx per frame) is still the useful one.
