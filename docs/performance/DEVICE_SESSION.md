# One-shot phone session: runbook and pass criteria (prepared 2026-11-01, no phone measured yet)

Owner: 08-performance. **No device result exists.** Everything below was checked only with the fake adb in
`tests/performance/fixtures/device_fake/` (hand-made fixed samples); those numbers are not measurements.
No Godot or emulator was run for this preparation.

## 1. What the person does
1. Charge the phone above 80 %, set the brightness to a fixed middle value, close other apps, turn on developer options and USB
   debugging, and plug it in. Only **one** device may be attached; with 0 or 2+ the script stops and changes nothing.
2. 02's perf APK must exist at `build/android/defence-perf.apk` (P10: own package id `com.soltyspring.lanedefence.perf`,
   debuggable, reads `user://perf_args.txt`, prints `[perf08]` lines; see 08-performance-to-02-engine.md P12).
3. Start it detached (the session is longer than 1 minute; HEAVY_RUN.md):
   ```
   build\heavy\08-device-job.ps1:   & .\tools\perf\device_session.ps1
   & .\coordination\heavy_run_detached.ps1 -Label '08-device' -ScriptFile build\heavy\08-device-job.ps1
   ```
   The 6 scenes take about 6 × (20 s settle + 90–120 s) ≈ 14 min.
4. For the thermal / battery soak, switch to **wireless adb** (`adb tcpip 5555`, `adb connect <ip>`, unplug USB), so the battery is
   not being charged, then queue `device_session.ps1 -Soak` (18 min, r08 caps) as a second detached job.
5. Results: `build/perf/device/<model>_<serial>/<stamp>_session/summary.md` (table + criteria) and per-scene raw files
   (samples.csv, presents_ns.txt, gfxinfo_framestats.txt, meminfo_final.txt, logcat_godot.txt, am_start.txt).

## 2. What the script does (`tools/perf/device_session.ps1`)
- Stops with exit 2 when: 0 or more than 1 device is attached; the device is unauthorised; it is an emulator (unless
  `-AllowEmulator`, labelled EMULATOR); the package is the release id (a player's save could be on the phone); or the perf APK is
  missing. A real device session also needs the heavy-run lock (exit 4 otherwise).
- Device facts: manufacturer, model, SoC (`ro.soc.*`, board, hardware), Android version/SDK, ABI, screen (`wm size`) and the canvas
  scale that follows from it (short side / 360, integer), density, MemTotal (sets the tier), battery level/temperature/voltage/
  power source, `current_now`, thermal status and temperatures.
- Installs the APK (`install -r --no-incremental`). For each scene from `tools/perf/device_scenes.json` (r01, r08 with `--perf-caps`,
  r10; each with zoom off and on), it pushes the args to `/data/local/tmp`, copies them to the app's `files/perf_args.txt`
  via `run-as` and reads them back. "Zoom on" is 02's flag `game/camera/world_zoom_plus_one` via `--world-zoom-plus-one`; the
  expected camera zoom is (k+1)/k for the phone's canvas scale k (4/3 at 1080 high, 3/2 at 720 high). The script then cold-starts
  with `am start -S -W` (TotalTime = cold start) and waits up to 30 s for
  the game's `[perf08] args applied: ...` line. A scene without that confirmation, or whose reported zoom differs from the
  requested one, is **INVALID** and never judged.
- During each scene it polls once per second: SurfaceFlinger `--latency` of the game's SurfaceView. That keeps the last 128
  present times, so a 1 s poll loses nothing up to 120 Hz. Every `-Interval` s (default 5) it also samples meminfo, CPU,
  battery and thermal state. At the end it saves gfxinfo framestats (HWUI layer only; Godot draws into a SurfaceView), meminfo
  -d and the game log.
- Frame metrics: p50/p95/p99 of the present intervals, janky share (interval > 1.5 × refresh period), mean fps and coverage.
  The game lines give draw calls, GPU and render-CPU ms, texture MiB, canvas scale, zoom and units.
- **Blank-screen guards** (2026-11-01): frame counts alone can pass on a blank screen. 10's emulator run showed that Godot keeps
  presenting frames after `SceneShaderGLES3: Program linking failed` / `Fragment shader active uniforms exceed
  GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`. Each scene therefore (a) scans the game log for shader compile/link failures and GL/EGL
  errors (`GLES_SHADER_ERROR`; the normal "Failed to load cached shader, recompiling." warning is ignored), and (b) takes one
  screenshot after settle (`screencap` + `pull`) and counts colours and luma spread on a 1/8 grid. `BLANK_SCREEN` means ≤ 2
  colours or luma std < 2; `NO_SCREENCAP` means the screenshot is missing. Any of the three makes the scene INVALID, so it is
  never judged. Calibration on real emulator frames: the blank SwiftShader frame has 1 colour / std 0, the menu 15–19 colours /
  std 34–35. 10's first-launch frame after the link failure still showed the menu (64 colours), so only the log check catches
  that case.
- Soak windows: only windows covering at least half the window length are compared. A trailing partial window has edge-biased
  fps; the self-test caught this (ratio 1.039 on a constant pattern).
- The soak is one scene for 18 min with 10 s samples. 2-min windows report fps and p95; the soak judges the last window against
  the first, the temperature rise, the thermal status maximum and the battery drop per 30 min (only when not powered).

## 3. Pass criteria, fixed before measuring (`tools/perf/device_criteria.json`)
Tier from MemTotal: ≤ 4.5 GiB low, ≤ 6.5 GiB mid, otherwise high. The tiers come from BUDGETS.md §1 / ENGINE.md §7; the 0.5 GiB
margin over the nominal RAM size is an **assumption**. `-Tier` overrides it. "Battle scenes" = the 6 scenes; the worst valid scene
is judged.

| id | Applies to | Pass line | Basis |
|---|---|---|---|
| frame_p95_low | low tier, battle scenes | frame interval p95 ≤ 36 ms (30 fps mode) | ENGINE.md §7, BUDGETS.md §2, BUILD_PLAN.md §5 |
| frame_p95_mid | mid/high | p95 ≤ 20 ms (60 fps) | same |
| janky_share | all tiers | < 5 % janky frames | BUILD_PLAN.md §5 pass rule ("janky frames < 5 %"); the 1.5 × refresh threshold is 08's definition |
| draw_calls_2x | 720-high phones (canvas scale 2) | game draw calls p95 ≤ 100 | BUDGETS.md §2 (≤ 100, provisional low-end) |
| draw_calls_3x | 1080-high phones (scale 3) | ≤ 100 | same |
| gpu_ms_p95 | low | game GPU ms p95 ≤ 16.6 | **ASSUMPTION** (half of a 30 fps frame) |
| gpu_ms_p95_mid | mid/high | ≤ 8.3 | **ASSUMPTION** (half of a 60 fps frame) |
| pss_low / _mid / _high | all scenes | TOTAL PSS ≤ 250 / 300 / 350 MB | ENGINE.md §7 |
| tex_low / tex_mid | all scenes | game texture memory ≤ 32 / 48 MiB | ENGINE.md §7 |
| cold_start_low / _mid | all scenes | `am start -W` TotalTime ≤ 4000 / 2500 ms | BUDGETS.md §2, BUILD_PLAN.md §5 (TotalTime ends at the first frame, which comes before the first menu frame) |
| soak_thermal_status | soak | thermal status < 3 (no "severe") | BUDGETS.md §2, BUILD_PLAN.md §5 |
| soak_temp_rise | soak | battery temperature rise ≤ 8 °C | **ASSUMPTION** |
| soak_fps_hold | soak | last 2-min window fps ≥ 90 % of the first | **ASSUMPTION** |
| soak_p95_hold | soak | last window p95 ≤ 1.15 × the first | **ASSUMPTION** |
| battery_drain | soak, on battery only | ≤ 8 % per 30 min | BUDGETS.md §2, BUILD_PLAN.md §5; NOT_MEASURED while USB/AC/wireless powered |

Not in the criteria yet, but recorded: CPU %, current (mA, vendor sign convention), HWUI janky %, render-CPU ms. Results are
PASS / FAIL / NOT_MEASURED / NOT_APPLICABLE per criterion. One phone decides one tier only; the release decision needs the
minimum device matrix in ANDROID_PROFILING.md §11.

## 4. Self-test without a phone (2026-11-01 07:52, `tests/performance/test_device_session.ps1`): 41/41 PASS
- Stops with exit 2 and no output folder for 0 devices, 2 devices and an unauthorised device; refuses the emulator and the
  release package; stops when the APK is missing.
- With the fake phone (1080×2400, MemTotal 3.79 GB → low tier, scale 3) the summary reproduces the fixed samples: p50 16.667
  and p95 33.333 ms, janky 0.099 (designed 0.1; the window edges cut the pattern), fps 54.6 (designed 54.5), PSS 181.1 MB,
  cold start 1850 ms, game dc 58, GPU 5/6 ms, HWUI 42 frames / 7.14 %.
- Criteria: frame_p95_low PASS, janky FAIL, PSS PASS, draw calls 3× PASS and 2× NOT_APPLICABLE, mid-tier rows not judged, the
  GPU ASSUMPTION rows tagged, soak rows NOT_MEASURED without a soak.
- A zoom-on scene is INVALID (ZOOM_NOT_APPLIED) while the fake game has no zoom flag, and valid when it has one.
- Soak (4 nominal minutes, 4-s windows for the test): ≥ 2 windows, fps and p95 ratios ≈ 1. The temperature rise follows
  0.5 °C per sample. Battery drain is judged on battery and NOT_MEASURED on USB power.
- Blank-screen guards with REAL emulator samples (`tests/performance/fixtures/android_real/`, copied from 10's evidence and 08's
  2026-10-31 capture): 10's shader-link log → INVALID `GLES_SHADER_ERROR` (10 matching lines) even though its screenshot is not blank;
  10's blank frame → INVALID `BLANK_SCREEN` although 547 frames were presented; the real menu frame → valid. An INVALID scene
  leaves the battle criteria NOT_MEASURED.
- The real adb with no phone attached: `NOT_ONE_DEVICE: 0`, exit 2.
- Not tested: a real phone, real dumpsys formats of other vendors (the parsers follow AOSP output and the emulator run of
  2026-10-31 for SurfaceFlinger), wireless adb, a real perf APK.
