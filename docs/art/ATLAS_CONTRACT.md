# ATLAS_CONTRACT.md — sprite sheets, residency, import (owner: 03-art)
Version 1 · 2026-10-31. This file implements ENGINE.md §8 and INTERFACES.md §5 (owned by 02). Measured numbers are in the generated docs/art/ATLAS_BUDGET.md.

## 1. Pages and grouping (no monolithic atlas)
| Page | Contents | Load policy (Atlas.acquire/release) |
|---|---|---|
| `ui_main` 256×128 | HUD/menu icons, cards, skill icons, 9-slices, bars, digits | `always` (menu + battle) |
| `char_player` 512×512 | hero_captain, worker, melee_basic, ranged_basic, tank | `battle` |
| `char_enemy` 512×256 | e_grunt, e_swarm, e_spitter (faction "bramble") | `battle_roster`. Later bosses get their own `char_boss_<id>` page so they are only resident in boss rounds |
| `char_player_adv` 512×256 | fast, siege | `battle_roster` (r04+/r06+ only) |
| `char_enemy_adv` 512×256 | e_brute, e_bomber | `battle_roster` (r04+/r07+ only) |
| `char_boss_warlord` 512×512 | boss_warlord | `battle_roster` (boss rounds only) |
| `char_boss_overlord` 1024×512 | boss_overlord + `portrait_boss_overlord` (portrait kept here so ui_main stays byte-identical) | `battle_roster` (r10 only) |
| `bases` 512×512 | base_player, base_enemy × idle/damaged/ruined | `battle` |
| `fx_combat` 512×256 | projectiles, impacts, skill FX, shadows, coin | `battle` |
| `biome_meadow` 1024×512 | sky/far/mid/ground/front layers | `per_round` (data biome `biome_01` / `meadow`) |
Future biomes add `biome_<id>` pages, with only one resident at a time. If char pages grow past 1024×1024, they split by roster (`char_player_2`, etc.) and are never merged into one page.

## 2. Packing rules (enforced by tools/art/atlas.py, checked by validate.py)
- MaxRects (best-short-side-fit), deterministic order. Page = smallest power-of-two that fits. Preferred max is 1024 and the hard max is 2048.
- Each region gets **1 px edge extrusion** (duplicated border texels) and then **2 px fully transparent gap** before the next region and the page border.
- Identical frames are deduplicated: many frame names can point to one rect, e.g. repeated idle frames and the `die`→`death` alias.
- **Layout locks** (`tools/art/layout_lock/<page>.json`, keyed by **frame name** since art 0.7.0): an existing frame keeps its exact rect on rebuild even when its pixels are redrawn. New regions fill free space, and the page only grows, never shrinks. If the locks cannot be honoured, build.py prints a WARNING and repacks; a re-import is then mandatory. Reason: 04 R4. A stale local `.godot` import showed old pixels at new rects (reproduced: 95/103 ui_main frames wrong; after `--import` 0/103; docs/art/evidence/ui_import/).
- Frames are untrimmed fixed-size cells per anim_set, which keeps the pivot constant across frames. Trimming is not worth it at this size (all pages total 5 MiB).
- PNGs are 8-bit indexed with tRNS. They decode to exact RGBA, are the smallest download, and contain no timestamps, so builds are reproducible.

## 3. Texture bleeding: how it is prevented and verified
validate.py (run after every build) checks the files on disk:
1. Rect+extrude stays inside the page, and no two different rects overlap.
2. The extrusion ring equals edge replication of the frame.
3. **Every texel outside all rect+extrude areas has alpha 0.**
4. Sampling simulation: each frame is sampled with nearest **and** bilinear at sub-texel offsets of ±0.49/±0.25 px. The test counts reads that fall outside the frame's own rect+extrude area. The current result is 0 foreign texels on all pages.
5. Palette compliance, the anim contract and data cross-references.
Runtime requirements on 02/04: nearest filter, mipmaps off, integer scale, `snap_2d_transforms_to_pixel=true` (already in project.godot). AtlasTexture `region` = the `x,y,w,h` from the JSON (excluding extrusion). Never put atlas regions into a texture with repeat enabled. The biome layers repeat by drawing copies (Parallax2D `repeat_size`), not by texture wrap.

## 4. Import settings (Godot 4.7)
03 does **not** write `.png.import` files. Hand-written ones lack Godot's `uid` and `[remap] path`, which made loads fail (02 R2). 02 sets `[importer_defaults] texture` in project.godot: `compress/mode=0` (Lossless), `mipmaps/generate=false`, `process/fix_alpha_border=true`. The default canvas filter is Nearest. After 02 runs `--import`, 03 commits the Godot-generated `assets/atlases/*.png.import`. validate.py errors if an `.import` lacks `uid`/remap path or the lossless/no-mip keys. The isolated check project (tools/art/godot_check) uses the same importer defaults.

### Compression recommendation (03 decision, reversible)
- **Keep all pixel-art pages Lossless (RGBA8 in VRAM).** ETC2 and ASTC 4×4 work on 4×4 blocks with a few endpoint colours. They shift palette colours and smear 1 px outlines, which visibly breaks pixel art. The total GPU cost of all pages is only ~5.1 MiB, far under the provisional low-tier 32 MiB budget (ENGINE.md §7), so compression saves nothing that matters.
- Re-evaluate only if (a) a single biome page goes above 2048×1024 or (b) measured texture residency exceeds the tier budget. In that case the order is: biome far/mid layers → ASTC 4×4 (with visual sign-off), then ETC2 fallback. Characters, UI and FX stay lossless.
- `project.godot` has `import_etc2_astc=true`. That only matters for VRAM-compressed textures, and none of ours are.

## 5. Memory (GPU) and storage
- GPU bytes = w × h × 4 (RGBA8, no mipmaps: mipmaps would add +33% and are useless with integer-scaled nearest sampling).
- Currently measured: menu residency 0.12 MiB (`ui_main`), battle residency 5.12 MiB (all six pages). Disk is ~42 KiB of PNG. Exported PCK size must be measured by 04 (UNTESTED).
- Device limits: GLES3 guarantees a `GL_MAX_TEXTURE_SIZE` ≥ 2048. Our hard max is 2048 and the current max is 1024, so every target device is covered. Non-power-of-two is fine on GLES3, but pages are power-of-two anyway.

## 6. Batching (draw calls)
- Godot's Compatibility renderer batches consecutive canvas items that share a texture and material. In a y-sorted lane, units of both factions interleave, so the expected worst case is roughly one batch break per texture switch along the draw order. The bounded upper estimate at the entity caps (30 + 40 units, 64 projectiles, 32 FX) is ~170 draw calls plus HUD.
- To reduce switches: units of one faction share one page, and shadows/projectiles/FX share `fx_combat`. 02 can draw shadows in a separate layer below units (one batch).
- **Evidence status:** see §7. On desktop the worst case measured 13 draw calls. Desktop numbers are only a proxy, and device profiling (owned by 02/04) is still needed before release.

## 7. Evidence log
| Check | Status | Evidence |
|---|---|---|
| Atlas files written, contract schema | TESTED (desktop) | `python tools/art/validate.py` → PASS |
| No bleed / extrusion / gap | TESTED (simulation) | validate.py checks 3–4: 0 foreign texels |
| Deterministic rebuild | TESTED | `validate.py --determinism` → identical page bytes |
| Godot 4.7.2 import of pages | TESTED (desktop, isolated copy) | `pwsh tools/art/run_godot_check.ps1` imports a throwaway copy with the same importer defaults. All 6 pages load and sizes match. Imported `.ctex` total 47,352 bytes (docs/art/evidence/godot_ctex_sizes.txt). The window runs on the secondary monitor (screen 1, non-primary; godot_check.json `window_screen`) |
| Draw calls at entity caps | TESTED (desktop proxy only) | Synthetic worst case: 71 units (y-sorted, both factions interleaved) + 64 projectiles + 32 FX + 5 parallax layers + 2 bases = 218 objects → **13 draw calls** (min=median=max over 120 frames). Compatibility renderer, GL 3.3, RTX 2070 SUPER (docs/art/evidence/godot_check.json) |
| Texture memory in engine | TESTED (desktop) | `RENDER_TEXTURE_MEM_USED` = 14.57 MB for the whole process. This includes Godot's own render targets and default textures. Our pages account for 5.37 MB (5.12 MiB), computed exactly |
| Bleeding in the real renderer | TESTED (desktop) | Captures at 1× and at 4× zoom with all sprites offset by (+0.37, +0.61) px contain **0 non-palette pixels** (only palette colours or palette + one shadow blend), so no filter blending and no neighbour texels (docs/art/evidence/capture_palette_check.txt, battle_cap_*.png) |
| Stale-import guard | TESTED (desktop, isolated) | `pwsh tools/art/run_godot_ui_check.ps1`: GPU readback + rendered contact sheet vs source PNG + json for all 9 pages; validate.py reports local cache md5 mismatch |
| Draw calls / memory / frame time on Android devices | UNTESTED | Needs 02/04 device profiling (low/mid tier) |
