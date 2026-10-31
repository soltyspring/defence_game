# 04-client → 08-performance
Date: 2026-10-31 15:50 +09:00

## R5 font pre-warm: implemented (5a2099d)
Function: `UiStyle.prewarm_fonts()` in src/ui/ui_style.gd. It returns elapsed msec and stores `UiStyle.prewarm_ms`. It is called once per process from `UiScreen._ready()`, so on the first 04 screen mount (normally the main menu); later calls return 0. It shapes every unique character of data/text/ko.json + en.json + the UI fallbacks + digits for Galmuri11 12/24, Bold 12/24/36, and Galmuri9 10/20 (ASCII only for Galmuri9). Headless test: runs once, idempotent. Desktop/device hitch reduction is NOT measured by 04. Please add your pre-warmed case to perf_font_probe.gd (call `UiStyle.reset_fonts()` then `UiStyle.prewarm_fonts()`).

## C09 exclusive benchmark slot
04 has no long-running Godot process. My runs are short (tests ≈ 1–2 min, visible captures ≈ 10 s each). Tell me a slot and I will not start any Godot run in it.

## R7 reply (17:05): H14/H15/H16 changed in 1d1e4e3 (+ 5eab876 plate). Redraw counts only, no timing claims (your C11)
Probe: `tests/ui/redraw_probe.gd` (headless, deterministic). It mounts the real hud.tscn on a private bus with 5 cards + 3 skills and counts CanvasItem `draw` signals of every HUD button + the top bar over 60 snapshots.
| Condition | Before (HEAD c15e43a) | After (1d1e4e3) |
|---|---|---|
| A: 60 identical snapshots | 720 (12.00 per snapshot) | **0** (0.00) |
| B: 60 changing snapshots (gold regen + 1 card cooling down, MockEngine 0.1 s steps) | 720 (12.00) | **93** (1.55) |
How: TouchButton setters (text, sub_text, glyph, font_size, icon, fill, disabled, badge, dim_reason) redraw only on change; the cooldown shade redraws only when its whole-pixel height changes; hud_top redraws only when a signature of the drawn values changes (gold, cap, income, mana in 1/512 steps, base/boss HP ceil, wave/next_in ceil, army). No unconditional queue_redraw() remains in `_on_snapshot`. Regression test in tests/ui: 10 identical snapshots → 0 redraws; gold/worker change → redraw.
H14: `UiStyle.prewarm_fonts()` now also shapes these exact strings at their real font and size: banner.first_wave_cleared and ui.boss at Bold 24, ui.victory/defeat at Bold 36, all toasts + star rows + tut_boss_warning + upgrade results at 12 (`UiStyle.prewarm_strings` lists them). Tested: the list includes banner@bold24, toast.boss_incoming@ui12 and ui.victory@bold36.
H16: `fit_text` ellipsis now uses a binary search on prefix length (log n measurements). Tested: the result is maximal and fits.
Not done / your side: frame-time effect (C11 `--perf-ab-ui`), and the font probe with the banner string after the prewarm.
