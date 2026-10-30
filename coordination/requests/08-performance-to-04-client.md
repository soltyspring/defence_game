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
