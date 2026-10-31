# FONT_COST.md — Galmuri glyph-cache memory and first-use hitch (owner: 08-performance)
Updated: 2026-10-31 09:20 +09:00. Evidence class: **CONTENDED_DESKTOP_PROXY** (Godot 4.7.2 debug editor binary, i7-9700K,
RTX 2070 SUPER, Compatibility renderer, 1280×720 window on the secondary monitor `\\.\DISPLAY2`, vsync off, 6 other Godot
processes running). **No phone measurement exists.** Run: `build/perf/20261031-091015/font.json` (3 reps, medians), git 70b7409
(working tree; the probe loads only `assets/fonts/*` and `data/text/ko.json`).

## Method (tests/performance/perf_font_probe.gd, via `.\tools\perf\run_perf.ps1 -Font -SkipBench`)
Each case loads a **fresh** FontFile (`CACHE_MODE_IGNORE`, cold glyph cache) with the same pixel flags `src/ui/ui_style.gd`
applies (no AA, no hinting, no subpixel, no MSDF, no mipmaps, no system fallback), then measures:
- `shape cold` — first `get_string_size()` (shaping + CPU rasterisation into the cache); `warm` — same call again;
- `first frame` — frame time of the first frame that draws a Label with that text on another fresh font (rasterise + texture upload);
- `warm-label frame` — first frame of a NEW Label with the same text on the now-warm font (layout/draw without glyph work);
- `glyph hitch` = first frame − warm-label frame (the cost attributable to cold glyphs);
- cache pages/bytes read exactly from `FontFile.get_texture_image()` after drawing.
Baseline: idle frame median before each case (0.04–0.39 ms). Sizes: allowed 12/24/36 (Galmuri11/Bold), 10/20 (Galmuri9);
18 px is a forbidden-size control. Texts: `ko_all` = every string in data/text/ko.json (1 153 chars, 251 distinct) at once
(worst case: a whole UI drawn on a cold font); `ko_toast` = `toast.boss_incoming` (a real first-time mid-battle string);
`ko_title` = `ui.title` + `ui.victory` at 36 px bold; `ko_stress_1000` = 1 000 distinct syllables (page-growth upper bound).

## Results (medians of 3 reps)
| Font / size / text | shape cold ms | first frame ms | warm-label ms | **glyph hitch ms** | cache pages | cache bytes |
|---|---|---|---|---|---|---|
| Galmuri11 12 ko_toast | 0.12 | 10.14 | 1.39 | **9.36** | 1 × 256² | 128 KiB |
| Galmuri11-Bold 24 ko_toast | 0.13 | 7.95 | 1.39 | **6.56** | 1 × 256² | 128 KiB |
| Galmuri11-Bold 36 ko_title | 0.15 | 5.23 | 1.39 | **3.84** | 1 × 512² | 512 KiB |
| Galmuri11 12 ko_all | 1.69 | 15.62 | 4.61 | **11.02** | 1 | 128 KiB |
| Galmuri11 24 ko_all | 1.89 | 12.26 | 1.39 | **10.87** | 3 | 384 KiB |
| Galmuri11 36 ko_all | 2.44 | 21.71 | 3.33 | **18.37** | 2 × 512² | 1 MiB |
| Galmuri11 18 ko_all (forbidden) | 1.87 | 12.76 | 1.88 | 11.20 | 2 | 256 KiB |
| Galmuri11-Bold 12 ko_all | 1.37 | 13.30 | 4.52 | **8.80** | 1 | 128 KiB |
| Galmuri11-Bold 24 ko_all | 1.67 | 8.47 | 1.39 | **7.09** | 3 | 384 KiB |
| Galmuri11-Bold 36 ko_all | 2.13 | 19.45 | 5.56 | **14.10** | 2 × 512² | 1 MiB |
| Galmuri11 12 ascii | 0.19 | 3.91 | 1.39 | 2.52 | 1 | 128 KiB |
| Galmuri11-Bold 12 ascii | 0.16 | 2.95 | 1.39 | 1.56 | 1 | 128 KiB |
| Galmuri9 10 / 20 ascii | 0.20 / 0.17 | 1.10 / 1.39 | 1.00 / 1.39 | 0.20 / 0.00 | 1 | 128 KiB |
| Galmuri11 12 ko_stress_1000 | 4.39 | 39.10 | 3.33 | 35.76 | 4 | 512 KiB |
| Galmuri11 24 ko_stress_1000 | 6.18 | 38.13 | 3.37 | 34.74 | 12 | 1.5 MiB |
Font file load (`ResourceLoader.load` of the imported fontdata): 4.5–5.6 ms for Galmuri11/Bold, 1.7 ms for Galmuri9.
Repeatability: an earlier contended run (07:41) gave the same cache bytes exactly and hitches within ±5 ms.

## Findings
1. **Cache pages are LA8 (Image format 1, 2 bytes/pixel), not L8**: a 256×256 page is 128 KiB, a 512×512 page (36 px) 512 KiB.
   docs/art/TYPOGRAPHY.md §4 says "256×256 L8 = 64 KiB", which undercounts by 2×.
2. **Glyph-cache memory for the shipped size set is small**: drawing every ko.json string in every used size
   (Galmuri11 12/24, Bold 12/24/36, Galmuri9 10/20) costs at most 128+384+128+384+1024+128+128 KiB ≈ **2.25 MiB**, against a low-tier
   texture budget of 32 MiB. 36 px is half of that (two 512² pages per font). Content growth: 1 000 distinct syllables at 24 px → 12 pages
   (1.5 MiB) for one size, so a larger script stays in the low single MiB per size.
3. **Cold first use is a visible hitch**: a single first-time Korean toast at 12 px costs ~9 ms extra on this desktop. Rasterisation runs
   on the CPU (FreeType) in the frame that first draws the string. With the uncalibrated ×4 desktop→phone assumption that is ~35–40 ms on a
   mid phone (2+ dropped frames at 60 fps) at exactly the moment it matters (boss warning mid-battle). A whole cold screen (`ko_all`) is
   9–18 ms desktop per size.
4. **Forbidden 18 px costs an extra cache set** (2 pages, 256 KiB) and the same hitch, confirming 03/04's integer-size rule also saves memory.
5. Galmuri9 numerals (ASCII only) are negligible (≤ 0.2 ms, 128 KiB per size).

## Requests (see coordination/requests/08-performance-to-04-client.md R5, -to-03-art.md A3 reply)
- 04: pre-warm the glyph cache at boot/loading for the sizes actually used, e.g. call `font.get_string_size(all_ko_strings, …, size)`
  per (font, size) once, or draw them once off-screen, before the first battle. Cost measured above: shape cold 1.4–2.4 ms per (font, size)
  on desktop, ~5 sizes → < 15 ms desktop at a loading screen instead of mid-battle hitches. Acceptance: re-run `-Font` with a "pre-warmed"
  case (I will add it when the API is chosen) and the HUD toast first-frame hitch ≤ 1 ms desktop.
- 03: correct the 64 KiB figure to 128 KiB per 256² LA8 page in TYPOGRAPHY.md §4. A pre-baked bitmap font is not needed for memory;
  only consider it if device pre-warm cost is too high.

## Not measured / limits
- Phone CPU rasterisation time and GPU upload (GLES3 driver) — device run needed (ANDROID_PROFILING.md).
- Fonts inside the real HUD with 04's shadow pass (draws twice) — the probe uses plain Labels.
- Memory of the font files themselves in RAM (~1.7 + 1.4 MB per 03) was not separately measured (static memory deltas are noisy).
