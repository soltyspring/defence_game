# Typography QA (owner: 04-client runtime type/layout; 03 owns font assets)
Updated: 2026-10-31 07:20 +09:00

## Current state (measured)
- Runtime font: Godot `ThemeDB.fallback_font` (no bundled font yet). `UiStyle.font()` switches automatically to `assets/manifest.json` → `fonts.ui` (path string or `{path}`) when 03 adds it.
- Glyph coverage, from `tests/ui/test_ui.gd` → `build/qa/typography_report.json`: Korean UI strings use 131 unique characters; 127 are NOT in the runtime font. They render only because the OS supplies a fallback font. Windows rendering is verified by screenshots. **Android rendering is unverified, and this is an open P1 release risk** (tofu boxes are possible on some devices).
- Fit: every Korean label checked (6 card names, 3 skill names, 10 round names, pause/result/menu buttons, settings labels, 9 toasts, quit dialog) fits its narrowest real slot (640×360, notch insets on both sides, 40-unit targets) without shrinking below 8 px and without ellipsis. English: no label was ellipsized in the same run.
- `TouchButton` auto-fits text: the font size shrinks to a minimum of 8 logical px, then an ellipsis `…` is added. Labels that do not use buttons (toasts, titles) do not auto-fit yet.

## Rules the test enforces
- ko: a truncated label or a fitted size below 8 px fails the test.
- en: ellipsis prints a WARN line (shared with 01 for wording).
- With a bundled font: every UI character must be in that font, or the test fails.

## Not yet verified (do not claim)
- Rendering on a real Android device or the emulator (requires an APK).
- Legibility at physical size on small phones (5.0–5.5″ 720p). 8 logical px at 2× scale is 16 px physical; this has not been looked at on a phone.
- Number alignment in the gold/income readout (proportional digits; values shift as numbers change).
- Contrast measurement (outline 3 px dark is used everywhere; no WCAG ratio was computed).
- Font memory and import cost (08/03).

## Requested
- 03: an OFL Korean+Latin font with a licence file in `assets/fonts/`, plus a manifest `fonts.ui` entry (see 04-client-to-03-art.md).
