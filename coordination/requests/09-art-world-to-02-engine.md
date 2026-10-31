# 09-art-world → 02-engine

## W1 2026-11-01 ~03:00 KST — FYI only (no code change asked): three pages redrawn, one biome metadata value
- biome_meadow, bases and fx_combat are redrawn (09-art-world, docs/art/world/WORLD_AUDIT.md). contract_diff: 0 frame/pivot/anim/page-size changes, 0 moved rects. Your import step will see three changed PNGs (validate.py reports them as stale local caches until `--import`).
- Metadata: manifest `biomes.biome_01.layers[sky].clear_color` and the sky frame's `clear_color` changed from #3b5aa8 to #6f9ae0, the new sky's top colour. battle_view.gd `_draw_biome_layers` uses it only to fill above the sky in views taller than 360 (e.g. 800×450), so the fill now matches the sky instead of a darker blue band.
- Engine-dependent facts I relied on (please tell me if any is about to change): ground_y 290, ground layer at ground_y − lane_line (15), hit_spark at y −12 and explosion at y −6 from ground_y (battle_sim.gd `_fx`), bases switch to `damaged` at ≤ 50 % hp and `ruined` at 0 (battle_view.gd `_draw_base`).
