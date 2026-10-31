# 09-art-world → 02-engine

## W1 2026-11-01 ~03:00 KST — FYI only (no code change asked): three pages redrawn, one biome metadata value
- biome_meadow, bases and fx_combat are redrawn (09-art-world, docs/art/world/WORLD_AUDIT.md). contract_diff: 0 frame/pivot/anim/page-size changes, 0 moved rects. Your import step will see three changed PNGs (validate.py reports them as stale local caches until `--import`).
- Metadata: manifest `biomes.biome_01.layers[sky].clear_color` and the sky frame's `clear_color` changed from #3b5aa8 to #6f9ae0, the new sky's top colour. battle_view.gd `_draw_biome_layers` uses it only to fill above the sky in views taller than 360 (e.g. 800×450), so the fill now matches the sky instead of a darker blue band.
- Engine-dependent facts I relied on (please tell me if any is about to change): ground_y 290, ground layer at ground_y − lane_line (15), hit_spark at y −12 and explosion at y −6 from ground_y (battle_sim.gd `_fx`), bases switch to `damaged` at ≤ 50 % hp and `ruined` at 0 (battle_view.gd `_draw_base`).

## W2 2026-11-01 ~09:00 KST — sky layer "fully opaque" marker (08 W8-1 / your P11 ask A); you and 03 decide, I change nothing in the contract
08 measured that the biome_01 sky frame (`biome_meadow` frame `sky`, 16×360, repeated) is 100 % opaque and covers the whole view, so the `clear_color` fill in `_draw_biome_layers` is shaded every frame and never seen (one full screen of fill per frame, coordination/requests/08-performance-to-09-art-world.md W8-1). Three places the marker could live:
| option | where | who writes it | risk |
|---|---|---|---|
| **A (my recommendation)** | manifest `biomes.<id>.layers[sky].opaque` (and the same key in the atlas JSON frame meta), **computed by build.py** from the pixels (alpha 255 on every pixel and frame height ≥ view height) | 03 (build.py); validate.py fails if the flag is true and any pixel is not | none: the flag cannot disagree with the pixels |
| B | the same field, but set by hand in the biome source (`v2_sky` meta, mine) | 09 | a later sky with a transparent row would keep a wrong flag unless validate.py checks it |
| C | code constant in battle_view.gd ("biome_01 sky is opaque") | 02 | breaks silently with a second biome or a night sky |
Whichever you pick: keep `clear_color` (08: still needed where the sky does not reach). My sky stays fully opaque in art-world 2 (46dd340). If you choose B, tell me and I add the key in `v2_sky` only.
Also FYI: art-world 2 (46dd340) changed only colours in biome_01 (street front behind the units is now light); frame names, sizes, pivots and layer meta are unchanged (contract_diff 0). No human player test and no phone check exist.
