# Android build requirements tracker (owner: 02-engine; pipeline scripts: 04-client tools/build/**)
Updated: 2026-10-31 07:30 +09:00. Status values: DONE (with evidence) / PARTIAL / PENDING / BLOCKED.

| # | Requirement | Status | Evidence / note |
|---|---|---|---|
| A1 | Godot 4.7.2-stable editor, official, checksum verified | DONE | SHA-512 match vs official SHA512-SUMS.txt; `--version` = 4.7.2.stable.official.ed1daf0bf |
| A2 | Export templates 4.7.2 | DONE | official .tpz SHA-512 match=True; installed android_debug/release.apk, android_source.zip, windows x86_64 templates into tools/engine/editor_data/export_templates/4.7.2.stable (version.txt = 4.7.2.stable) |
| A3 | `export_presets.cfg` preset "Android" (debug APK, non-Gradle, arm64-v8a + x86_64, immersive, no permissions) | DONE | `--export-debug "Android" build/android/defence-debug.apk` → 59,021,726 B APK in ~32 s, signed with apksigner (build-tools 36.0.0) |
| A4 | Editor settings: android_sdk_path = %LOCALAPPDATA%/Android/Sdk, java_sdk_path = JDK 25.0.2 | DONE | ANDROID_HOME env points to Z:\AndroidAVDs (not an SDK) — ignore it |
| A5 | Debug keystore | DONE (local) | generated with keytool into tools/engine/editor_data/keystores/debug.keystore (standard debug alias; git-ignored, not a release credential) |
| A6 | Release keystore + passwords via env vars `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD` | BLOCKED (user action) | 04 owns; never in source |
| A7 | Android SDK cmdline-tools (sdkmanager/avdmanager) | MISSING | only needed for Gradle/AAB build and AVD creation |
| A8 | Build-tools 35.0.1 (Godot docs) | OK in practice | export used build-tools 36.0.0 apksigner successfully |
| A9 | AAB for Play (Gradle build) | PENDING | needs A7, NDK r28b per docs (27.1 installed), Android build template install |
| A10 | Emulator run | PARTIAL | project-local AVD `build/avd/LaneDefence_Phone` (Android 16 / API 36 google_apis_playstore x86_64, 720×1600, 4 cores, 4 GB, `-gpu host`, headless). App installs, boots to 04 menu, Play → battle r01 renders with 03 atlases (docs/architecture/evidence/android_emu_*.png). PSS 172–174 MB at menu/battle start. With `swiftshader_indirect` GPU the Godot GLES3 canvas shader failed to link ("Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)") → host GPU required for emulator. SystemUI ANR dialogs appear in this headless image (emulator environment, not the app). Emulator = proxy only; NOT a device performance claim |
| A11 | APK loads atlases from imported .ctex (no raw-PNG fallback) | DONE | APK contains `.godot/imported/*.ctex` for all 6 pages + remapped .import; on Android `Atlas.texture_report()` reports `"source":"import"`; pack-only desktop run (`--main-pack`) loaded 6/6 pages without raw PNGs |
| A12 | Bundled Korean font | PENDING | 03/04 (04 R5). Current 04 menu uses a Latin pixel font; Hangul on Android unverified |
| A13 | targetSdk / Play policy level | PENDING | verify in exported manifest (aapt2 dump) |
| A14 | Real low-end device run (fps, frame pacing, thermals, memory) | BLOCKED | no physical device attached |
| A15 | Debug APK size | MEASURED | 59 MB with 2 ABIs (arm64-v8a + x86_64 debug). Release arm64-only expected much smaller; to be measured |
| A16 | Launcher name (user Q4, 2026-10-31 17:19 KST: ko "빵집 기사단", en "Bakery Knights") | DONE (debug APK) | `project.godot` `application/config/name_localized = {"en": "Bakery Knights", "ko": "빵집 기사단"}` (Godot docs: "used by OS tools to translate application name on Android, iOS and macOS") and `export_presets.cfg` `package/name = "Bakery Knights"` (default label). `application/config/name` stays "Lane Defence" on purpose: Godot docs say changing it moves the desktop user:// folder (`app_userdata/<project name>`) when `use_custom_user_dir` is false, which would hide existing PC saves; keeping it is simpler and lossless than a custom dir + migration. Side effect: the desktop window title is still "Lane Defence" (rename later together with a migration if wanted). `package/unique_name` unchanged (`com.soltyspring.lanedefence`, update path intact). Evidence 17:37 KST: `aapt2 dump badging` → `application-label:'Bakery Knights'`, `application-label-en:'Bakery Knights'`, `application-label-ko:'빵집 기사단'`, `package: name='com.soltyspring.lanedefence'`; 06 `tests/services/test_services_android.gd` → `launcher_label=VERIFIED`, 189/0. Not checked on a device launcher |

Reproduce emulator run (02 local):
```powershell
$env:ANDROID_AVD_HOME = "$PWD\build\avd"; $env:ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk"
& "$env:ANDROID_SDK_ROOT\emulator\emulator.exe" -avd LaneDefence_Phone -no-window -no-audio -no-snapshot -no-boot-anim -gpu host -port 5580
$adb = "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe"
& $adb -s emulator-5580 install -r --no-incremental build\android\defence-debug.apk
& $adb -s emulator-5580 shell am start -n com.soltyspring.lanedefence/com.godot.game.GodotAppLauncher
& $adb -s emulator-5580 logcat -d -s godot     # look for "[App] boot ok ... source":"import"
```
Note: another process restarted the shared adb server during testing (daemon restarts seen twice); coordinate adb use with 04/07/08.
