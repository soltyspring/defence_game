# Mobile build plan (owner: 04-client)
Updated: 2026-10-31. Engine per docs/contracts/ENGINE.md: Godot 4.7.2-stable, GDScript, Compatibility (GLES3) renderer.
Status legend: VERIFIED = observed on this machine with the command shown. UNVERIFIED = planned, not yet run. BLOCKED = cannot proceed without the item listed.

## 1. Toolchain audit (this machine, 2026-10-31, run by 04)
| Item | Found | Evidence | Status |
|---|---|---|---|
| Godot editor 4.7.2 | `tools/engine/Godot_v4.7.2-stable_win64(_console).exe` (installed by 02, self-contained `_sc_`) | file listing | VERIFIED present |
| Godot Android export templates | `tools/engine/editor_data/export_templates/4.7.2.stable/` has android_debug.apk, android_release.apk, android_source.zip (seen 07:15) | dir listing | PRESENT; APK export not yet run |
| JDK | Oracle JDK 25.0.2 at `C:\Program Files\Java\jdk-25.0.2` (`java -version`) | `java version "25.0.2" 2026-01-20 LTS` | VERIFIED. Godot docs recommend JDK 17; only matters for Gradle builds (see §4) |
| keytool | `C:\Program Files\Java\jdk-25.0.2\bin\keytool.exe` (not on PATH) | `keytool -help` | VERIFIED |
| Android SDK root | `%LOCALAPPDATA%\Android\Sdk` = `C:\Users\aghose\AppData\Local\Android\Sdk` | dir listing | VERIFIED |
| platform-tools / adb | adb 1.0.41, 36.0.0-13206524 | `adb version` | VERIFIED |
| build-tools | 35.0.0, 36.0.0, 36.1.0 (apksigner, zipalign present) | dir listing | VERIFIED |
| platforms | android-35, android-36, android-36.1, android-CANARY | dir listing | VERIFIED |
| NDK / CMake | NDK 27.1.12297006, CMake 3.22.1 | dir listing | VERIFIED (only needed for native plugins) |
| cmdline-tools (sdkmanager, avdmanager) | missing | `Get-Command sdkmanager` none; no `Sdk\cmdline-tools` | GAP: needed only for Gradle/AAB and licence acceptance; standard APK export does not need it |
| Emulator | `Sdk\emulator\emulator.exe` | `emulator -list-avds` | VERIFIED |
| AVDs | `GoogleTranscribe_Validation_20261029` (android-36 playstore x86_64, 1080×2400 @420 dpi, 3 GB, swiftshader GPU); `Pleos_Validation_20261028` (car image, 2560×1440) | `Z:\AndroidAVDs\*.ini` | Present but belong to other projects. Plan: create our own AVD under a workspace-local `ANDROID_AVD_HOME` (git-ignored) to avoid touching them |
| Debug keystore | `%USERPROFILE%\.android\debug.keystore` exists (standard `androiddebugkey` / `android`) | `Test-Path` | VERIFIED present; used only for debug APK |
| Physical Android device | none attached | `adb devices -l` empty | BLOCKED for real-device perf/thermal evidence until user connects a device with USB debugging |
| Env vars | `ANDROID_HOME=Z:\AndroidAVDs` (points at the AVD folder, not the SDK) | `Get-ChildItem env:` | RISK: build scripts must pass the SDK path explicitly and not trust `ANDROID_HOME` |
| macOS / Xcode | none (Windows host) | — | BLOCKED: iOS export requires a Mac with Xcode; see §6 |
| Free disk | C: 22.9 GB, Z: 351 GB | `Get-PSDrive` | OK |

## 2. Debug APK pipeline (target for first milestone)
Script: `tools/build/build_android_debug.ps1` (04). Steps:
1. Locate Godot console exe, SDK (`%LOCALAPPDATA%\Android\Sdk`), JDK (`C:\Program Files\Java\jdk-25.0.2`) explicitly. Fail with a clear message if any is missing.
2. Check export templates exist for `4.7.2.stable` (android_debug.apk / android_source.zip).
3. Godot editor settings needed for export: `export/android/android_sdk_path`, `export/android/java_sdk_path`, debug keystore path/user/pass. Because the editor is self-contained, these live in `tools/engine/editor_data/editor_settings-4.*.tres` (02-owned). The script passes them via env vars where Godot supports it (`GODOT_ANDROID_KEYSTORE_DEBUG_PATH/USER/PASSWORD`) and requests 02 to set SDK/JDK paths in editor settings.
4. `--headless --path . --import`, then `--headless --path . --export-debug "Android" build/android/defence-debug.apk`.
5. Verify: file exists, size, `apksigner verify --print-certs`, `aapt2 dump badging` (package, versionCode, minSdk/targetSdk, native ABIs) from build-tools 36.1.0.
6. Optional: start our AVD, `adb install -r`, `adb shell am start`, capture `adb logcat` for Godot startup lines and `adb exec-out screencap -p` screenshot to `build/android/evidence/`.
Required export preset (owned by 02 in `export_presets.cfg`, requested in coordination/requests/04-client-to-02-engine.md): name `Android`, ABIs arm64-v8a (+ x86_64 for emulator testing in debug only), min SDK 24 (provisional), target SDK 35+ (Play requirement for new apps in 2025/26 era must be rechecked at release), landscape sensor orientation, immersive mode on, no unnecessary permissions (INTERNET off until ads/IAP are integrated), `gradle_build/use_gradle_build=false` for the debug APK.

## 3. Release pipeline (AAB for Play) — UNVERIFIED, design only
- Play Store requires AAB. Godot produces AAB only through Gradle build (`gradle_build/use_gradle_build=true`, `export_format=AAB`). Needs: Android build template installed into `android/` (02 root), cmdline-tools + accepted licences, a JDK Gradle supports (install JDK 17 or 21 locally in tools/; JDK 25 may be too new for the bundled Gradle version — to be tested, not assumed).
- Signing: upload key generated by the user (`keytool -genkeypair -v -keystore <outside repo> -alias upload -keyalg RSA -keysize 2048 -validity 10000`). Path and passwords only via env vars `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Never written to `export_presets.cfg`, never committed (`*.keystore`, `*.jks`, `export_credentials.cfg` are git-ignored). Use Play App Signing so the upload key can be reset.
- Versioning: `version/code` monotonically increasing integer set by the build script from an argument; `version/name` from `project.godot` `config/version`.
- Release script (planned): `tools/build/build_android_release.ps1 -VersionCode N` → refuses to run if env vars are missing, if the working tree has secrets staged, or if templates mismatch.

## 4. Known risks / blockers
| Risk | Impact | Plan |
|---|---|---|
| Export templates not yet installed | No APK possible | 02 installing; script checks and reports |
| SDK/JDK paths not in self-contained editor settings | Export fails with "Android SDK path invalid" | Request 02 to set; script validates |
| JDK 25 vs Godot-recommended JDK 17 | apksigner should work; Gradle (AAB) may fail | Test apksigner first; for AAB install portable JDK 17 into tools/ if needed |
| cmdline-tools missing | No sdkmanager/avdmanager; Gradle licence check may fail | Create AVD manually by config.ini; for AAB, user or 02 installs cmdline-tools (free, no account) |
| Emulator uses SwiftShader software GPU | Frame timing on emulator is not representative | Emulator only for startup/layout/input. Perf evidence must come from a physical device |
| Korean glyphs | Godot default font lacks Hangul; Android system font fallback behaviour must be verified on device | Request 03/01 to bundle an OFL Korean pixel-friendly font (e.g. Galmuri or NeoDunggeunmo, licence to be checked) |

## 5. Device tiers and measurement plan (PROVISIONAL, joint with 02, see ENGINE.md §7)
Budgets are provisional until measured on physical devices. Measurement method:
- In-game: `Perf.snapshot()` sampled once per second into a CSV ring by a QA overlay (04, `src/ui/debug_overlay.gd`, debug builds only).
- Device: `adb shell dumpsys gfxinfo <pkg>` (frame stats), `adb shell dumpsys meminfo <pkg>` (PSS), `adb shell dumpsys battery` + `adb shell dumpsys thermalservice` before/after a 15-minute soak, APK size from `aapt2`/file size.
- Scenario: round with both armies at cap (36/36) + skills spammed, 10-minute soak, 2× speed if implemented.
| Metric | Low tier (2–3 GB, Adreno 610 / Mali-G52) | Mid | Pass rule |
|---|---|---|---|
| Frame time | 30 fps mode: p95 ≤ 36 ms | 60 fps: p95 ≤ 20 ms | gfxinfo janky frames < 5% |
| PSS | ≤ 250 MB | ≤ 300 MB | dumpsys meminfo TOTAL PSS |
| GPU texture residency | ≤ 32 MB | ≤ 48 MB | Perf tex_mem_bytes during battle |
| Cold start to menu | ≤ 4 s | ≤ 2.5 s | logcat timestamp: process start → first menu frame |
| Battery | ≤ 8%/30 min at 60 fps | — | dumpsys battery level delta, screen brightness fixed |
| Thermal | no throttling status ≥ 3 in 15 min | — | dumpsys thermalservice |
| APK size | ≤ 60 MB | — | file size |

## 6. iOS (documented only; BLOCKED on this Windows host)
Godot exports an Xcode project; building/signing requires macOS + Xcode + an Apple Developer account (paid, user action). Steps when a Mac is available: install the same Godot 4.7.2 + templates, create an iOS export preset (bundle id, team id from user's account, landscape only, safe-area respected by the same UI code), export Xcode project, archive in Xcode, TestFlight. Nothing iOS-specific is claimed as tested.

## 6b. Visible tests (secondary monitor only)
`tools/build/visible_launch.ps1` lists monitors with per-monitor DPI awareness and picks a non-primary work area. It starts Godot with `--screen <index>`; a negative `--position` value was observed to open the window on the PRIMARY monitor, so that option is not used. The script then verifies the real HWND with `MonitorFromWindow`, sets only the game window topmost, and can save OS-level screen captures plus JSON evidence to `build/qa/visible/`. With no secondary monitor it exits 3 (BLOCKED) and opens nothing.

## 7. Commands (user-facing summary in Korean in docs/mobile/RUN_AND_BUILD.md once scripts are verified)
```powershell
# UI layout/input tests (headless)
.\tools\build\run_tests.ps1
# Android debug APK (once templates + preset exist)
.\tools\build\build_android_debug.ps1
```
