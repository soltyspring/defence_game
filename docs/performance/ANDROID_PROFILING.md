# ANDROID_PROFILING.md — phone measurement procedures (owner: 08-performance)
Updated: 2026-10-31. Package `com.soltyspring.lanedefence` (export_presets.cfg). Renderer: Godot 4.7.2 Compatibility (OpenGL ES 3.0).
Status: **procedures written, not yet executed on a phone.** `adb devices -l` listed no device on 2026-10-31 07:00, so no DEVICE
reading exists. The emulator AVDs on this PC belong to other projects and use a software GPU; emulator numbers are not phone evidence.

Automated capture: `.\tools\perf\android_capture.ps1` runs §2–§7 and stores raw output under
`build/perf/device/<model>_<serial>/<stamp>_<label>/` (git-ignored). It exits 2 and writes nothing when no device is attached.
Everything below is the manual equivalent so readings can be reproduced or extended.

## 0. Rules for valid phone evidence
1. Physical phone, USB debugging on, `adb devices -l` shows `device` (not `unauthorized`).
2. Record the build: release-template export for frame/CPU/battery claims. A debug export runs the debug GDScript VM and
   debug engine binary (the current debug APK's arm64 `libgodot_android.so` is 76 MB uncompressed), so debug-build numbers
   are labelled DEBUG BUILD and only used for relative comparisons.
3. Fixed conditions, written into the run label: brightness fixed (`adb shell settings put system screen_brightness_mode 0`,
   `adb shell settings put system screen_brightness 128`), Wi-Fi/Bluetooth state noted, battery 40–90 %, phone at room
   temperature and idle for 10 min before a thermal run, no other apps in recents, battery saver off, refresh-rate setting noted.
4. One scenario per run: `menu_idle`, `r01_normal`, `r06_caps` (both armies at caps), `soak20_caps`. Same seed/round each time.
5. Keep the raw text files. A table without raw output is not evidence. Never extrapolate one tier's result to another.

## 1. Device facts (identify the tier)
```powershell
$A = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $A shell getprop ro.product.manufacturer; & $A shell getprop ro.product.model
& $A shell getprop ro.soc.model; & $A shell getprop ro.board.platform        # SoC
& $A shell getprop ro.build.version.release; & $A shell getprop ro.build.version.sdk
& $A shell cat /proc/meminfo | Select-String MemTotal                       # RAM
& $A shell wm size; & $A shell wm density
& $A shell dumpsys SurfaceFlinger | Select-String 'GLES:'                   # GPU + driver
& $A shell dumpsys display | Select-String 'refreshRate|mode'               # panel refresh
```
Map to docs/performance/BUDGETS.md §1 by RAM + GPU class.

## 2. Install and cold start
```powershell
& $A install -r build\android\defence-debug.apk                              # 04's pipeline builds it
& $A shell cmd package resolve-activity --brief com.soltyspring.lanedefence  # launcher component
& $A shell am start -S -W -n <component from above>                          # -S = force-stop first (cold)
```
Read `TotalTime` (ms to first frame of the activity) and `WaitTime`. Repeat 5 times, report median and max. Warm start: press HOME,
then `am start -W` without `-S`. Godot draws its boot splash first; "time to interactive menu" needs a log marker (requested
from 02: print `[App] menu_ready msec=<Time.get_ticks_msec()>` once) read from `adb logcat -s godot`.
Budget: low ≤ 4 s, mid ≤ 2.5 s cold start to menu.

## 3. Memory (PSS)
```powershell
& $A shell dumpsys meminfo com.soltyspring.lanedefence
```
Read the **App Summary**: `Java Heap`, `Native Heap`, `Code`, `Graphics`, `Private Other`, `System`, `TOTAL PSS`, and the
`GL mtrack` / `EGL mtrack` rows. Godot allocations are in Native Heap; textures and render targets in Graphics/GL mtrack (driver
dependent; some Mali/Adreno drivers report them under "Unknown" or not at all — note which). Sample points:
menu idle → battle start → battle at caps → result screen → back to menu → after 5 consecutive battles (leak check: the menu
value must return to within ~5 % of the first menu value) → after `adb shell am send-trim-memory com.soltyspring.lanedefence RUNNING_LOW`.
Compare Graphics against docs/performance/RESOURCE_INVENTORY.md (atlas pages 5.25 MiB in battle as of 07:20) plus render targets:
a 2400×1080 window costs 2400×1080×4 ≈ 9.9 MiB per colour buffer.
Budget: total PSS low ≤ 250 MB, mid ≤ 300 MB, high ≤ 350 MB.

## 4. Frame pacing
Godot renders into a SurfaceView (GL). `dumpsys gfxinfo` measures HWUI (Android View) frames, so its "Janky frames" line does
not describe the game's GL frames. Use SurfaceFlinger:
```powershell
& $A shell dumpsys SurfaceFlinger --list | Select-String lanedefence          # find "SurfaceView[...]" layer name
& $A shell dumpsys SurfaceFlinger --latency "<exact layer name>"             # last ~128 frames: refresh period, then desired/actual/ready ns
```
Actual-present deltas give frame intervals; count intervals > 1.5× the refresh period as janks. Sample every ~1.5 s to cover a
whole session (android_capture.ps1 does this and dedupes timestamps). Longer windows (Android 10+):
```powershell
& $A shell dumpsys SurfaceFlinger --timestats -clear -enable
# ... play the scenario ...
& $A shell dumpsys SurfaceFlinger --timestats -dump > timestats.txt          # per-layer present-to-present histogram, missed frames
& $A shell dumpsys SurfaceFlinger --timestats -disable
```
System trace for root cause (main thread vs render thread vs GPU waits):
```powershell
& $A shell perfetto -o /data/misc/perfetto-traces/trace.pftrace -t 20s sched freq idle am wm gfx view power
& $A pull /data/misc/perfetto-traces/trace.pftrace build\perf\device\
```
Open in https://ui.perfetto.dev. GPU counters: Arm Performance Studio (Mali) or Snapdragon Profiler (Adreno), optional vendor tools.
In-game numbers: `Perf.snapshot()` (fps, frame_ms_p95, sim_ms, draw_calls, tex_mem) — needs a debug overlay or periodic log line in
debug builds (04/02); without it only SurfaceFlinger data counts.
Budget: low tier 30 fps mode p95 ≤ 36 ms; mid 60 fps p95 ≤ 20 ms; jank < 5 % of frames.

## 5. CPU
```powershell
$pid = (& $A shell pidof com.soltyspring.lanedefence).Trim()
& $A shell top -H -b -n 1 -p $pid                                            # per thread: main ("godot"/"GLThread"), audio, workers
& $A shell dumpsys cpuinfo | Select-String lanedefence
& $A shell "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"       # may be permission-denied on retail phones
```
Native hotspots (debuggable APK): `adb shell simpleperf record -p $pid --duration 10 -g -o /data/local/tmp/perf.data`, then
`adb pull` and `simpleperf report`. GDScript functions appear as VM frames; for per-function GDScript cost use the Godot remote
profiler (`adb reverse tcp:6007 tcp:6007` + editor remote debug) only after coordinating the editor with 02.
Calibration of the desktop ×4 assumption (BUDGETS.md §3): run the same headless workload on device. Needs a perf-only export
preset that includes `tests/performance/*` (the shipping preset excludes `tests/*`) — requested from 02/04.

## 6. Thermal
```powershell
& $A shell dumpsys thermalservice                                            # "Thermal Status: N" + "Current temperatures from HAL"
```
Status: 0 none, 1 light, 2 moderate, 3 severe, 4 critical, 5 emergency, 6 shutdown. Run `soak20_caps` (20 min at caps), sample
every 30 s, record status, CPU/GPU/skin temperatures and fps. Pass: no status ≥ 3 within 15–20 min and fps not dropping > 20 %
between minute 2 and minute 20 (throttling shows as falling fps with rising temperature).

## 7. Battery
USB power makes level drain meaningless. Either:
- **real drain**: `adb tcpip 5555`, `adb connect <phone-ip>:5555`, unplug the cable, run 30 min, read `dumpsys battery` level before/after;
- **attribution only**: `adb shell dumpsys battery unplug` (stats behave as unplugged while the cable still charges), always undo with `adb shell dumpsys battery reset`.
```powershell
& $A shell dumpsys batterystats --reset
# ... 30 min scenario ...
& $A shell dumpsys batterystats com.soltyspring.lanedefence > batterystats.txt   # "Estimated power use (mAh)" for the uid
& $A bugreport build\perf\device\bugreport.zip                                     # optional: Battery Historian
```
Budget: ≤ 8 % per 30 min at 60 fps with fixed brightness (BUILD_PLAN §5). Report %/30 min, mAh estimate, battery temperature.

## 8. Download / install size
```powershell
python tools/perf/budget_inventory.py --apk build\android\defence-debug.apk        # groups + largest entries
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.1.0\aapt2.exe" dump badging build\android\defence-debug.apk | Select-String 'native-code|sdkVersion'
& $A shell pm path com.soltyspring.lanedefence; & $A shell du -sh /data/app/*lanedefence*/   # installed footprint (may need run-as)
```
Measured 2026-10-31 (STATIC, debug APK built by 04 at 07:07): 55.30 MiB, of which native libraries are 54.6 MB compressed
(`x86_64/libgodot_android.so` 28.2 MB, `arm64-v8a/libgodot_android.so` 25.5 MB). Game content is ~1 MB. Play AAB per-ABI
splits and the release template change this; measure the AAB with `bundletool get-size total` once 04 builds one.

## 9. Save / storage latency on device
Desktop: save p50 12–21 ms, p95 16–96 ms depending on machine load (BASELINE_DESKTOP.md). Phone flash latency must be read
in-game: requested from 02 — debug builds log `[Save] write_ms=<n> bytes=<n>` per save. Run: change a setting 20 times, finish
a battle, background the app (lifecycle save), then pull the log with `adb logcat -d -s godot`.

## 10. Lifecycle and low-memory behaviour (with 07)
`adb shell am start` → battle → HOME → `adb shell am kill com.soltyspring.lanedefence` (kills only if backgrounded) → relaunch:
progress must be intact and the battle paused/ended per ENGINE.md §7. Also `adb shell am send-trim-memory ... RUNNING_CRITICAL`
while in battle and observe PSS and stability.

## 11. Minimum device matrix before any release claim
| Tier | Devices needed | Scenarios |
|---|---|---|
| Low | ≥ 1 (prefer 2 GPU vendors: Mali-G52 and Adreno 610 class) | all of §2–§10 |
| Mid | ≥ 1 | §2–§4, §6, §8 |
| High | optional | §4 |
The user must supply the phones; this machine has none attached. Until then every phone budget remains UNMEASURED.
