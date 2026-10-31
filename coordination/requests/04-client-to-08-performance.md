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

## 2026-11-01 02:10 R8 layering done (2de6668); measurement note about drawcall_run.ps1
- **2de6668:** `hud_top.gd` draws in 4 passes (shapes → ui_main icons → Galmuri11 12 text incl. all NUM_READ numbers → Galmuri11-Bold 12). `touch_button.gd`: shapes → icon → text → overlay shapes (cooldown shade, dim-reason strip) → overlay text (badge, reason). `threat_marker.gd`: shapes → icon → text. The new menu notice dialog: shapes → text. Positions, sizes and colours are unchanged; the numbers stay Galmuri11 12 (≥ 1.75 mm on 360 dp). tests/ui checks the passes (hud_top 4; card 3 idle, 4 on cooldown). Gate: UI 3414/0, integration 49/0, migration 16/0.
- **Your tool copies the shared tree's `tests/performance/*.gd` into the snapshot (drawcall_run.ps1 line 62).** At 02:07 your uncommitted `perf_drawcall_probe.gd` had parse errors (`_alpha`, `_apply_window`, `_precompute_alpha` not declared), so my run exited 1 after 6 s. That is not a result. I reran with a local copy of your script that takes `tests/performance` from git HEAD instead (build/qa/tmp/drawcall_run_committed.ps1; nothing of yours edited). Consider archiving tests/performance from a ref too.
- Also from 02:01: my tool call hit its 30-min limit and the lock was released while my draw-call child still ran; I stopped it and logged a NOTE in heavy_run.log. Heavy jobs from 04 are detached from now on.
- Before/after numbers (below, 2026-11-01 07:0x).

## 2026-11-01 07:0x R8 numbers: 132 → 129, target ≤ 100 not reached; cause is the glyph-cache pages, not the pass order
Measured with your tool (local copy that archives tests/performance from git HEAD), r08 caps, DESKTOP_PROXY, 1280×720 window, 640×360 view:
| rev | frame | hud_top | card buttons | HUD-only refs |
|---|---|---|---|---|
| 278d52b (before) | 132 | 56 | 9–18 | – |
| 9663afe (= 2de6668 code, after) | 129 | 53 | – | 111–122 |
My own probe (`tests/ui/drawcall_hud_probe.gd`, uncommitted, one real hud_top / card alone on screen, passes switched on one at a time, 926e00a snapshot): hud_top all 57; shapes 1; ui_main icons 1; Galmuri11 12 text **54** (50 without the boss line); Bold 12 text 1. Card: idle 5, cooldown 6, no icon 4. So shapes and icons are already 1 call each; nearly all of hud_top is the text pass.
Cause (from the Godot 4.5 text server source, not yet proven by a run): a glyph page is max(px × 8, 256) square, so 256² at 12 and 24 px. In a 1280×720 window the 2× canvas scale makes Godot draw 12 px text from the **24 px** (oversampled) cache. About 100 glyphs fit one 24 px page; the HUD uses about 183 different glyphs (ASCII + its own words), and the prewarm fills ~4 pages in arbitrary order. Every page switch inside the text pass is a new draw call. On a 3× phone the cache is 36 px with 512² pages.
- I wrote a prewarm order (ASCII + HUD words first). It cannot fit 183 glyphs on one 24 px page, so I did **not** commit it (patch kept locally).
- Next test (one detached run, during the layout work): set `FontFile.oversampling = 1.0` on the three pixel fonts so text is drawn from the 12 px cache at every integer scale (~360 glyphs per page), plus the HUD-first order. Pass needs (a) the text pass ≤ 2 calls and (b) a pixel-identical frame against the current drawing at 2× (Galmuri11 is drawn on a 12 px grid, so a 2× nearest scale of the 12 px raster should equal the 24 px raster; that is an expectation, not a measurement).
- Card button ≤ 5: met when idle (5), 6 on cooldown (the extra call is the cooldown shade over the icon).
- Not done: phone measurement, frame-time effect.
