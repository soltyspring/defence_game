# All pending art together: texture memory and APK size (STATIC, 2026-11-01 07:27, commit a67b9f1)

Owner: 08-performance. Made with `tools/perf/allin_static_budget.ps1`. No Godot was run: the script uses `git archive`, the Python
art build in a copy, and file reads. The working-tree `assets/atlases` hashes were identical before and after.

## 1. Scenarios
- **head**: a67b9f1 as committed. It already contains 03's one-page `char_player` and 06's HUD frames (02ec60f, adc0965).
- **world**: head + 09-art-world's redrawn `bases`, `biome_meadow`, `fx_combat`, copied from the **working tree**. These are 09's
  uncommitted files; all six (.png/.json) differ from the commit. 08 did not commit them.
- **d1**: head + 03's `ART_DRAFT32=D1FULL` build in the copy (A19, 32 px roster).
- **allin**: the d1 build with 09's three pages copied over.
- Not built: 06's four proposed frame names (`hud_tray` 12×12, `btn_skill` 16×16, `chip_resource` 12×12, `btn_round` 24×24).
  Statically they need 2032 px with padding 2 + extrude 1. `ui_main` (256×256, occupancy 0.358) has 42 074 px free, so they fit:
  occupancy would rise to about 0.39 and the page stays 256×256 (an estimate; the packer decides).

## 2. Result (atlas pages only; project import = lossless RGBA8, no mipmaps, ENGINE.md §8)
| Scenario | Gate | char_player | Worst battle | All pages | Menu | Atlas PNG | Atlas JSON (LF bytes) | APK delta vs head |
|---|---|---|---|---|---|---|---|---|
| head | PASS | 1024×512 | 8.75 MiB | 9.00 MiB | 0.50 MiB | 86.2 KiB | 100.7 KiB | 0 |
| world | PASS | 1024×512 | 8.75 | 9.00 | 0.50 | 87.5 | 100.7 | +1.3 KiB |
| d1 | PASS | 1024×1024 | 10.75 | 11.00 | 0.50 | 100.4 | 100.7 | +14.2 KiB |
| **allin** | **PASS** | 1024×1024 | **10.75** | **11.00** | **0.50** | 101.7 | 100.7 | **+15.5 KiB** |
| cap (RETHEME_BUDGET) | | side ≤ 1024 | ≤ 12 | ≤ 14 | ≤ 0.5 | | | content growth ≤ 2 MiB |

- 09's pages keep every page size, so they cost no GPU memory. Only 03's D1 doubles `char_player`, which adds 2.0 MiB.
- Margins after allin: worst battle 1.25 MiB, all pages 3.0 MiB, **menu 0 MiB**. The menu is exactly at its cap
  (ui_main 0.25 + ui_title_ko 0.125 + ui_title_en 0.125). Any new always-resident or menu page fails.
- APK: the exported `.ctex` is a lossless re-encode, not the PNG. Imported copies from 2026-11-01: `char_player` PNG 30 955 → ctex
  36 110 B (base) and 45 651 → 50 276 B (D1); `ui_main` 5 543 → 4 646 B. So the ctex delta for D1 (+13.8 KiB) is close to the PNG
  delta (+14.4 KiB). The all-in APK growth is about **+15 KiB**, all from PNG; the atlas JSON content is unchanged (331 frames in
  `char_player`, 104 in `ui_main`). JSON bytes are counted without CR, because this machine's `git archive` adds CRLF (core.autocrlf).
  That is far below the 2 MiB content-growth cap. The APK is dominated by the engine library (06: ≈ 25.9 of 30.4 MB download).

## 3. What-if import modes (allin)
| Import mode | Worst / all / menu MiB | Over a cap? |
|---|---|---|
| lossless RGBA8, no mipmaps (current) | 10.75 / 11.00 / 0.50 | no |
| lossless + mipmaps (×4/3) | 14.33 / 14.67 / 0.67 | **over all three** |
| VRAM compressed ETC2 / ASTC 4×4 (8 bpp, ×1/4) | 2.69 / 2.75 / 0.13 | no |
| compressed + mipmaps | 3.58 / 3.67 / 0.17 | no |
- **Mipmaps must stay off.** With them, even head is at 11.67 / 12.00 / 0.67 MiB, so its menu is already over the cap. The game
  uses integer scaling and nearest filtering, so mipmaps add nothing visible.
- VRAM compression would cut memory by 4×. ENGINE.md §8 rejects it for pixel art (ETC2/ASTC smear pixels), and nothing is near
  the GPU cap, so 08 does not propose it.
- Atlas pages are only part of texture memory: font glyph caches (≤ 2.25 MiB, FONT_COST.md), engine defaults and the phone's
  window buffers come on top. The phone session's `tex_mib` from the game monitor is the real total (DEVICE_SESSION.md).
