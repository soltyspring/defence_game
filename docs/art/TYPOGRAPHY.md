# TYPOGRAPHY.md — font selection, licence, rendering rules (owner: 03-art)
Version 1 · 2026-10-31. Runtime text layout belongs to 04, importer and project settings to 02. This file covers the font assets, their provenance, and the rendering rules backed by real Godot renders.

## 1. Candidates compared (sources accessed 2026-10-31)
| Font | Licence | Hangul syllables | Latin/digits | Native grid | Shipped size after subset | Notes |
|---|---|---|---|---|---|---|
| **Galmuri11 / 11 Bold** (v2.40.4, quiple) | SIL OFL 1.1, **no Reserved Font Name** | 11,172 / 11,172 (measured with fontTools) | 95/95 ASCII | 12 px | 1,764,716 B / 1,469,824 B | One family has 7/9/11/14 px sizes, a bold, and mono variants. Subsetting is allowed without renaming. https://github.com/quiple/galmuri |
| Galmuri9 | same | 11,172 | 95/95 | 10 px | 10,288 B (numeral-only subset) | 10 px Hangul ≈ 2.0 mm on a 5–6.5" phone, below our minimum, so this cut is shipped for numbers/Latin only |
| Galmuri14 | same | 11,172 | 95/95 | 15 px | not shipped | Rendered cleanly, but a 15 px grid does not match the 12 px UI grid. Galmuri11 at 24 px covers headings |
| NeoDunggeunmo v1.601 | SIL OFL 1.1 **with Reserved Font Names** "NeoDunggeunmo"/"Neo둥근모" | 11,172 | 95/95 | 16 px | 651,044 B (full) | Good, but any subset is a Modified Version and must be renamed. Its 16 px grid is large for a 360 px-tall view. https://github.com/neodgm/neodgm |
| Fusion Pixel KR | OFL 1.1, assembled from several upstream fonts | yes | yes | 8/10/12 px | — | Mixed upstream provenance makes the licence audit harder. Not chosen. https://github.com/TakWolf/fusion-pixel-font |
Observation vs inference: the coverage and sizes above were measured on the downloaded files. "Readable on phone" is only an estimate from geometry: a 360 px-tall reference view on a 62–71 mm landscape screen height gives 0.17–0.20 mm per reference px. It has not been tested by users or on a device.

**Decision (03, reversible):** Galmuri11 Regular + Galmuri11 Bold for all Korean/Latin text, plus a numeral-only Galmuri9. Reasons: complete Hangul coverage, no RFN (subsetting without renaming), one consistent family, and a 12 px grid that matches the 640×360 UI.

## 2. Shipped files (assets/fonts/)
| File | Bytes | Glyphs | Contents |
|---|---|---|---|
| Galmuri11.ttf | 1,764,716 | 11,630 | ASCII, Latin-1, punctuation, arrows, UI symbols ★☆♥●■▲▶◀※·…×, CJK punctuation, compatibility jamo, **all 11,172 syllables**, fullwidth forms |
| Galmuri11-Bold.ttf | 1,469,824 | 11,571 | same ranges |
| Galmuri9.ttf | 10,288 | 105 | ASCII + ★☆♥×·…%‰▶◀▲ only (no Hangul, by design) |
| OFL-Galmuri.txt | — | — | upstream licence text, copied verbatim (the OFL requires it to ship with the fonts) |
| fonts_provenance.json | — | — | source URL, zip SHA-256 `C8B3D986…E60E7`, per-file source/output SHA-256, glyph counts |
Rebuild: download the release zip, extract it, then run `python tools/art/fonts.py <extracted dir>`. The output is deterministic (timestamps are not recalculated). CJK ideographs and kana were dropped because the ko/en text does not use them. Before subsetting, the four outline TTFs totalled 17.8 MB.
Measured deflate-9 sizes (a proxy for APK zip): Galmuri11 312 KB, Bold 281 KB. Exported test PCK containing atlases + 3 fonts: **1,168,676 B** (docs/art/evidence/pack_check.json).

## 3. Rendering rules (all measured, docs/art/evidence/fonts/)
Method: `pwsh tools/art/run_godot_font_sheet.ps1` renders the shipped fonts with Godot 4.7.2 (Compatibility renderer, GL 3.3) into SubViewports. Each SubViewport emulates a device: device-sized target, 2D override of the reference view, stretch on. The window is on the secondary monitor. `tools/art/font_contact.py` then measures every text row at 1:1 device pixels. A row passes only if every font pixel became an equal integer square (`irregular=0`).
| Device emulated | Scale | Galmuri11 12/24 px | Galmuri11 9/18/28 px (04's current sizes) |
|---|---|---|---|
| 640×360 | 1× | regular | **irregular** (9: 0.75 px blocks; 18: 1.5; 28: 2.33) |
| 1280×720 | 2× | regular | 9 and 28 irregular, 18 regular |
| 2400×1080 | 3× | regular | 9 and 18 irregular |
| 1600×900 | **2.5×** | **12 px irregular**, 24 regular | all irregular |
| 2560×1600 | 4× (width-limited) | regular | 28 irregular |
Rules derived from this:
1. **Font sizes must be integer multiples of the native grid:** Galmuri11/Bold use 12, 24 or 36 px only, and Galmuri9 uses 10 or 20 px (numerals only). Never 9/18/28.
2. **Minimum Hangul size is 12 px** (≈ 2.1–2.4 mm on 5–6.5" phones, estimated; device check pending with 04/07).
3. **Non-integer content scale breaks pixel text** (2.5× → irregular 12 px rows) and sprites alike. Recommendation to 02: `display/window/stretch/scale_mode="integer"` with aspect `expand`, so a 1600×900 device renders at 2× with an 800×450 view.
4. Font flags: `antialiasing=NONE`, `hinting=NONE`, `subpixel_positioning=DISABLED`, `multichannel_signed_distance_field=false`, `generate_mipmaps=false`, `allow_system_fallback=false`. System fallback would mix in non-pixel glyphs instead of failing visibly. **These flags are now in the committed `assets/fonts/*.ttf.import`.** 02 generated those files and 03 edited only the `[params]` values. validate.py fails if any flag regresses. A render that loads the fonts with only the import params (no code overrides, `--import-flags-only`) gave regular rows at 1×/2×/3×/4× (font_report.json `flags_from_import`).
5. Use outline/shadow only in whole pixels (`outline_size` 0 or a multiple of the scale). For contrast on the battlefield, draw text on the `panel_dark` 9-slice or with a 1 px dark shadow offset (1,1).
6. Do not use all-caps Latin for body text or ornamental fonts. Bold is for numbers, titles and buttons.

## 4. Memory and cost (measured in the same run)
Dynamic glyph cache: one 256×256 single-channel (format 1 = L8) texture per (font, size) for the sample strings, i.e. 64 KiB each. The sheet used 9 size caches = 0.56 MiB. Each extra font size adds at least one cache page, which is one more reason to restrict sizes to 12/24/36. Long Korean sessions may grow a size cache to more pages; 08 should profile this on device. The font files themselves load into memory (~1.7 MB + 1.4 MB RAM).

## 5. Fallback strategy
- Primary Galmuri11 (Regular/Bold) covers all of Hangul, so there is no fallback for Korean.
- `validate.py` fails the art build if any character in `data/**/*.json` is missing from Galmuri11/Bold, so text cannot ship with tofu.
- No system-font fallback: missing glyphs show up in QA as visible boxes instead of silently switching style.
- Latin/digits are in the same files, so mixed strings ("웨이브 3/10", "+12.5/s") share one baseline.

## 6. Evidence files
`docs/art/evidence/fonts/d*_*.png` (raw device renders), `font_contact_1to1.png` (1:1 crops, labelled OK / irr / NON-INT), `font_regularity.json`, `font_report.json` (glyph caches), `../pack_check.json` (fonts load from an exported PCK; `missing_probe` shows the intended absence of 漢, and of Hangul in Galmuri9).
Untested: real phones, text expansion with final copy, line-break/ellipsis inside 04's actual widgets. These belong to 04/07 with the secondary-monitor launcher plus devices.
