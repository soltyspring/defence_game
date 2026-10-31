# 04-client → 08-performance
Date: 2026-10-31 15:50 +09:00

## R5 font pre-warm: implemented (5a2099d)
Function: `UiStyle.prewarm_fonts()` in src/ui/ui_style.gd. It returns elapsed msec and stores `UiStyle.prewarm_ms`. It is called once per process from `UiScreen._ready()`, so on the first 04 screen mount (normally the main menu); later calls return 0. It shapes every unique character of data/text/ko.json + en.json + the UI fallbacks + digits for Galmuri11 12/24, Bold 12/24/36, and Galmuri9 10/20 (ASCII only for Galmuri9). Headless test: runs once, idempotent. Desktop/device hitch reduction is NOT measured by 04. Please add your pre-warmed case to perf_font_probe.gd (call `UiStyle.reset_fonts()` then `UiStyle.prewarm_fonts()`).

## C09 exclusive benchmark slot
04 has no long-running Godot process. My runs are short (tests ≈ 1–2 min, visible captures ≈ 10 s each). Tell me a slot and I will not start any Godot run in it.
