# Typography QA (owner: 04-client runtime type/layout; 03 owns font assets)
Updated: 2026-10-31 08:10 +09:00. Code: 8b24e59 (bundled fonts) + 0333cd3 (grid-safe label fit, visible real-scene capture).

## 1. Runtime fonts (measured)
| Role | File (assets/manifest.json `fonts`) | Sizes used | Source check |
|---|---|---|---|
| Body, buttons, toasts | res://assets/fonts/Galmuri11.ttf | 12, 24 | `UiStyle.font_sources[&"ui"] = bundled:...` |
| Titles, banners, numbers in titles | res://assets/fonts/Galmuri11-Bold.ttf | 12, 24, 36 | bundled |
| Costs, timers, `/cap`, income, army count, version | res://assets/fonts/Galmuri9.ttf (ASCII only) | 10, 20 | bundled; its `fallbacks` = Galmuri11, so non-ASCII never reaches the OS |
- Flags are forced at load by `UiStyle._pixel_flags`: antialiasing NONE, hinting NONE, subpixel DISABLED, no mipmaps or MSDF, `allow_system_fallback=false`. The test asserts these on all three fonts. 03 also fixed the `.import` params (abd327d); 04 does not rely on them.
- No Godot or OS fallback font is used for UI text. A missing glyph would render as visible tofu and fail the test.
- No size off the 12/24/36 (Galmuri11) or 10/20 (Galmuri9) grid is used anywhere in `src/ui`. Text is never shrunk to arbitrary sizes.

## 2. Glyph coverage (tests/ui/test_ui.gd → build/qa/typography_report.json)
- ko: the whole `data/text/ko.json` table plus the UI fallbacks contain 230 unique characters. 0 are missing in Galmuri11 Regular and 0 in Bold.
- en: the same check found 0 missing.
- Numerals font: 0-9 + - / . : % x v present.

## 3. Fit / clipping (narrow and wide layouts)
Slots come from the real layout code (`HudLayout.compute`) at 640×360 with notches on both sides, at 640×360, and at 800×360 with a notch, plus the menu, pause, result and round-tile widths.
- ko: every label checked fits at its grid size with no ellipsis: unit and skill names, 10 round names, buttons, settings labels, 9 toasts, titles, banner. A ko ellipsis fails the test.
- en (expansion check): Latin-only labels that do not fit at Galmuri11 12 drop to Galmuri9 10, which stays on its native grid (`UiStyle.fit_label`). The ellipsis count fell from 15 → 2. The remaining two are "Footman" → "Foo…" and "Catapult" → "Cat…", only in the worst case (640 wide, notches on both sides, 5 cards + 3 skills, card slot 37 px). This is reported to 01 (shorter en names) and is still open.
- Toast and banner strips size themselves to the text and ellipsize beyond the safe width.

## 4. Stable numerals
`UiStyle.draw_number` uses one cell per digit (the widest 0-9 at that size). The test asserts width("111") == width("888") and width("+4.0/s") == width("+9.5/s") for Galmuri9 10 and Galmuri11-Bold 12. In the HUD, current gold is right-aligned in a slot sized to the cap's digit count, so "/400" and the income do not move while gold changes (seen in captures).

## 5. Real-scene visual evidence (secondary monitor only)
Runner: `tools/build/visible_launch.ps1 -Script res://tests/integration/test_ui_integration.gd -UserArgs --shot-dir=...,--tag=...,--tile=N,--locale=ko|en`. This runs the real `scenes/gameplay/main.tscn`, App and BattleSim, and saves frames. The log lists `ui_roots` per shot: `res://src/ui/main_menu.gd`, `round_select.gd`, `hud.gd`, `result.gd`. None are fallback UI.
| Run | Window | Content scale | Integration test | Files (build/qa/real/, git-ignored) |
|---|---|---|---|---|
| ko r01 16:9 | 1280×720 on DISPLAY2 | 2× | 27/27 | ko_16x9_r01_{1_menu..5_result}.png, launch_20261031_074200.json |
| ko r06 20:9 (5 cards, 2 skills) | 1600×720 | 2× | pass | ko_20x9_r06_*.png |
| en r06 16:10 | 1280×800 | 2× | 26/26 | en_16x10_r06_*.png (after fit_label) |
| ko r06 1600×900 | 1600×900 | **2.5× (non-integer)** | pass | ko_2p5x_r06_*.png |
Mock-adapter screens (menu/round select/HUD/pause/result) at 6 shapes were also re-captured through the same launcher; all 6 windows were verified on DISPLAY2. Files: build/qa/screens/.

Pixel regularity (white text pixels in round-tile names, horizontal run widths):
| Render | Runs | Odd-width runs | Verdict |
|---|---|---|---|
| ko_20x9 at 2× | 838 | 0 (0%) | regular 2×2 pixels |
| ko_16x9 at 2× | 140 | 0 (0%) | regular |
| ko_2p5x at 2.5× | 1077 | 887 (82%) | **irregular stems** (runs of 2 and 3 px mixed) |
At non-integer scale, pixel text (and sprites) render unevenly. 04 cannot fix this inside its UI. It needs `display/window/stretch/scale_mode="integer"` (02, already requested by 03 A2c). The layout code was verified for the integer-mode views this creates (800×450, 666×400, 683×384) in the 3000-configuration layout matrix.

## 6. Limits of this evidence (do not over-claim)
- Desktop GL on Windows at 96 dpi only. Nothing has been checked on an Android device or emulator: physical legibility of 12 px Hangul (≈2.1–2.4 mm, 03 estimate), Android font loading, and thermal or text-cache growth are all unchecked.
- Contrast: whole-pixel shadow and dark toast strips are used, but no contrast ratio was measured.
- The OFL credits/licence entry is not yet shown in-game (UI task).
