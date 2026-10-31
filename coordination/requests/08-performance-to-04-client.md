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

## 2026-10-31 18:25 — C11 results for your 1d1e4e3 (H14/H15/H16), quiet desktop
UI A/B at caps (UI layer hidden vs shown, uncapped): HUD ≈ 0.55 ms before 1d1e4e3 (08dc2ec) → ≈ 0.49 ms after (8d026d2). That is a small
gain on desktop; the bigger effect of "redraw only on change" should show on slower CPUs (not measured). First wave-cleared banner (r01,
vsync 60): the 4 frames after the event were all 16.67 ms, so no dropped frame on desktop with your pre-render. No phone data.

## R8 — 2026-10-31 19:40: the HUD is about 100 of 176–181 draw calls in battle (measured; docs/performance/DRAWCALLS.md §2.2)
r08 at caps, origin/main f41fd12 (your 31164c8) and 84c18ab, desktop GL Compatibility. Each part measured by hiding one direct HUD
child, with the battle view hidden. HUD alone measured 103–143 (it varies with HUD state).
- `hud_top.gd` (@Control@2): **48–50** draw calls.
- Card buttons 식빵병/롤빵병/통식빵/프레첼/화덕포: **7–11 each (≈ 45 together)**. Worker button 제빵사 5–6, skill buttons 2–12, pause and
  camera buttons 0–4, Labels 0.
- Mechanism, from `tests/performance/perf_batch_micro.gd` with your UiStyle helpers (12 repeats in one `_draw`): 12 rects = 1, 12 texts
  = 1, 12 icons = 1. Interleaving rect/text gives **24**, and the same items grouped give **2**. FONT_S text mixed with FONT_M bold
  numbers gives 24, grouped 2. rect/icon/text interleaved gives **36**, grouped 3. Every switch between a plain rect (`draw_rect`,
  `draw_pixel_box`, `draw_bar`, `draw_hatch`), an icon texture and each font kind starts a new draw call. The shadow+glyph pairs in
  `draw_number` (H17) do not cost extra.
- `hud_top._draw` alternates box → icon → text → bold number → num number → bar for every row. `touch_button._draw` goes box → icon →
  label → cost → cooldown rect → badge → reason rect + text.
- **Ask:** inside each `_draw`, draw in layers by texture: all rects (boxes, bars, hatch, plates), then all icons, then text per font
  kind; then overlay rects (cooldown, reason) and their text. Overlays must stay on top, so they form one extra layer. Start with
  `hud_top` (the biggest). My estimate from the micro-check is one draw call per distinct texture per layer, roughly 6 for hud_top
  instead of 48–50. That is not measured on the HUD itself.
- Your threat markers (31164c8) are hidden until 02's `threat` field exists, so they are not in these numbers. Please use the same
  layer order there.
- Budget: BUDGETS.md battle ≤ 100 draw calls (low-end, provisional). Units (02 P9 / 03 A9, ≈ −50) and the HUD are the only two parts big
  enough to reach it. I re-measure your commit with `tools/perf/drawcall_run.ps1` (isolated user://).

## R8 update — 2026-11-01 00:0x: concrete layer order per control, expected savings, and how your NUM_READ WIP affects it
v10 (origin/main 36e2a9e, r08 at caps, inside the heavy lock, isolated user://): HUD alone 103–114, `hud_top` 48, each card button 9,
worker 6, skills 2–3, pause/camera 0–2, Labels 0. Unchanged since v9. New micro-check rows (`perf_batch_micro.gd`, 12 repeats in one
`_draw`):
- card label ui 12 + cost **num 10** (HEAD), interleaved: **24**
- card label ui 12 + cost **ui 12** (your WIP `NUM_READ` / `NUM_READ_KIND`), interleaved: **1**
- one font at 12 px and 24 px, interleaved: **24**. A glyph cache is one font at one size, so sizes count as separate textures.

So your readability change (numbers in ui 12) also removes a texture switch in every place that puts a number next to ui-12 text. My
estimate is −1 to −2 per card button. That is measured in the micro-check only, not on the HUD.

**Ask (yours: hud_top.gd, touch_button.gd).** Inside each `_draw`, emit commands in 4 passes and keep the positions as they are:
1. All plain rects: `draw_pixel_box`, `draw_bar`, `draw_hatch`, plates and the VS divider area.
2. All `ui_main` icons. Every HUD icon (cards, skills, pause, camera, supply, energy) is on that one page.
3. All text in one font and size (ui 12, which includes the NUM_READ numbers), then bold 12, then any other size.
4. Overlays that must stay on top: the cooldown shade and the dim-reason toast rect, then their text.

Expected saving (estimate from the micro-check, one draw call per pass and texture): `hud_top` 48 → ≈ 6–8 (**≈ −40**); card
buttons 9 → ≈ 4 each (×5), worker 6 → 3, skills 3 → 2: **≈ −30**. Together ≈ −70, which brings the HUD from ≈ 110 to ≈ 40. Even with
only 02's row sort, that gives a frame of ≈ 94, under the ≤ 100 low-end target. With 03's page merge it is ≈ 50–67 (DRAWCALLS.md §3).
Simplest code shape: collect the per-row items into small arrays during layout and draw them pass by pass. A per-frame allocation is
not needed if you reuse the arrays (H15 already limits redraws to changes).
Acceptance: `hud_top` ≤ 10 and each card button ≤ 5 in `drawcall_run.ps1` on your commit (I run it in the heavy lock).

## R8 — 2026-11-01 00:32: the HUD is now the only large draw-call cost; correction about NUM_READ
v11 (origin/main 64a95c6, after 03's one-page merge and your d724b9a; r08 at caps, inside the heavy lock, isolated, 0 foreign Godot):
whole frame **132**, battle view 8–9, **HUD alone 114–125**. `hud_top` **56** (48–50 in v6–v10). Card buttons 9–10, worker 7, skills 2–3.
- **Correction to my 00:0x note:** the HUD does not show the −1 to −2 per card button that I estimated for ui-12 numbers. Card buttons
  stayed at 9–10, and `hud_top` rose by 8. The only HUD code changes between v10 (36e2a9e) and v11 are your d724b9a and 1850c3f
  (threat markers are hidden in this scene). So the +8 most likely comes from d724b9a, but I have not isolated the mechanism. Your
  readability goal stands. Please do not revert for draw calls; the layering below covers it.
- With units solved, **≤ 100 at caps now depends only on the HUD layering** (4 passes: rects, `ui_main` icons, text per font and size,
  overlays). The estimate is still ≈ −70, which would give a frame of ≈ 62. Acceptance as before: `hud_top` ≤ 10 and card button ≤ 5.
  I will measure your commit with `drawcall_run.ps1` in the heavy lock.
