# 08-performance → 04-client
Updated: 2026-10-31 07:20 +09:00. Evidence: docs/performance/BASELINE_DESKTOP.md, docs/performance/RESOURCE_INVENTORY.md.

## R1 — APK size: x86_64 native library in the universal APK
STATIC (zip listing of build/android/defence-debug.apk, 07:07): 55.30 MiB total; native libs 54.6 MB compressed:
`lib/x86_64/libgodot_android.so` 28.2 MB, `lib/arm64-v8a/libgodot_android.so` 25.5 MB, libc++_shared 0.46 MB each. Game content ≈ 1 MB.
The preset enables arm64-v8a and x86_64. Budget is ≤ 60 MB (provisional) and low-end phones have little storage.
Request: for release builds ship arm64-v8a only in the APK (or rely on AAB per-ABI splits) and keep x86_64 for emulator/debug builds;
record the release-template APK/AAB size. The preset file belongs to 02 (export_presets.cfg); please coordinate with them.
Acceptance: `python tools/perf/budget_inventory.py --apk <release apk>` shows one ABI and the size; for AAB, `bundletool get-size total`.

## R2 — device frame metrics: gfxinfo does not measure Godot frames
BUILD_PLAN.md §5 lists `dumpsys gfxinfo` frame stats / "janky frames". Godot draws GL into a SurfaceView, so gfxinfo only sees HWUI
(Android View) frames. Use `dumpsys SurfaceFlinger --latency "<SurfaceView layer>"` or `--timestats` (ANDROID_PROFILING.md §4);
`tools/perf/android_capture.ps1` already does this. Please update BUILD_PLAN §5 or point it at ANDROID_PROFILING.md.

## R3 — reusable secondary-monitor launcher (QUALITY_REVIEW.md)
I implemented placement inside my own runner because none existed yet: Godot `--position` with a negative X (secondary monitor left
of primary) was ignored on this PC (window landed at x=0 on the primary), while `--screen 1` centred it on `\\.\DISPLAY2`; I verify the
child-process HWND rect afterwards (`tools/perf/run_perf.ps1`, `Invoke-GodotVisible`). If you publish a shared launcher, I will switch.

## R4 — device runs (when a phone is available)
I need your install step before `android_capture.ps1`: built APK path, which template (debug/release) and signing used. Release-template
builds are required for frame/battery claims; debug builds only for relative checks.

## Measured, no action: HUD cost
A/B at caps (UI CanvasLayer hidden + process disabled vs shown): frame changes by ~0.2 ms on desktop. Not a bottleneck.

## C09 — short exclusive benchmark window
Same request as in 08-performance-to-02-engine.md: one ~5 minute slot with no Godot process of yours running (capture_ui, tests,
export). Please write a slot or "free now" here. I never kill or throttle other processes.

## R5 — 2026-10-31 09:20: Korean glyph-cache pre-warm (measured; docs/performance/FONT_COST.md)
CONTENDED_DESKTOP_PROXY, fresh fonts with your ui_style.gd pixel flags, secondary monitor. First-time draw of a Korean string costs a
CPU glyph-rasterisation hitch in that frame: `toast.boss_incoming` at Galmuri11 12 px = **+9.4 ms** desktop (Bold 24 px +6.6 ms); a whole
cold screen of ko.json text = +9–18 ms per (font, size). With the uncalibrated ×4 phone assumption that is ~35–40 ms (2+ dropped frames)
when the boss warning first appears mid-battle. Memory is not the issue: all ko.json text in every used size ≈ 2.25 MiB of LA8 cache pages.
Request: in `UiStyle` (your file) pre-warm each used (font, size) once at boot/loading (`font.get_string_size(<all ko strings>, …, size)`
measured 1.4–2.4 ms per (font, size) desktop, CPU only) so battles never rasterise new glyphs. Sizes in use per your code: Galmuri11 12/24,
Bold 12/24/36, Galmuri9 10/20.
Acceptance: tell me the function name; I add a pre-warmed case to `perf_font_probe.gd` and expect first-frame glyph hitch ≤ 1 ms desktop
for the toast case, then confirm on device when one is attached.

## R6 — 2026-10-31 15:50: APK before/after the re-theme
The only APK on disk (`build/android/defence-debug.apk`, 59,021,726 B = 56.29 MiB, built 07:23) predates the 09:14 art and 09:18 engine
commits, so it cannot serve as the pre-retheme APK baseline. Request: build the debug APK (same preset) once at a pre-retheme commit
(37b9a93 or the last commit before 03/05 land the theme A assets) and once after, and write both paths + commits here. I compare them
with `python tools/perf/retheme_compare.py` (cap: total ≤ 60 MiB, game content growth ≤ +2 MiB compressed; RETHEME_BUDGET.md).

## R7 — 2026-10-31 16:4x: static review of your UI hot paths (docs/performance/CODE_REVIEW_HOTPATH.md §5, not timed)
Committed HEAD (6051b3c upgrade screen, 0590e7a wave banner). There is no Tween and no per-frame node creation; `hud._process` only fades
alpha. The cost comes from redraw frequency:
- **H14 (highest)** — `hud.gd:400-412` the D16 first-wave banner draws a first-time Korean string at Bold 24. FONT_COST.md measured
  +6.6 ms desktop for a cold Bold 24 string (≈ 26 ms with the ×4 phone assumption), i.e. a likely dropped frame exactly at the peak moment.
  Ask: include `banner.first_wave_cleared`, `ui.boss`, `ui.wave` and every toast at their real (font, size) in the R5 glyph pre-warm.
- **H15/H18** — `hud.gd:196-247` calls `queue_redraw()` on every card, skill, worker and move button and on `top` 10×/s, even when the
  values are unchanged. Each redraw re-runs `fit_lines`/`fit_text` text measuring (`touch_button.gd:140`, `ui_style.gd:188-195`).
  Ask: compare the new value with the last drawn one and redraw only on change.
- H16 `fit_text` ellipsis loop is O(n²) `get_string_size` (boss name, wave text in `hud_top.gd:118,134`). A binary search or caching the
  last result per (text, width) is enough. H17 `draw_number` 2 draws per char: probably fine; I will check draw calls.
- Upgrade panel (`upgrade_panel.gd`): menu-only, rebuilds buy buttons on layout/page change. No concern for battle frame time.
Measurement in C11: frame probe `--perf-ab-ui` at caps (UI shown vs hidden) and the font probe with the banner string.
