# Android build requirements tracker (owner: 02-engine; pipeline scripts: 04-client tools/build/**)
Updated: 2026-10-31. Status values: DONE (with evidence) / PENDING / BLOCKED.

| # | Requirement | Status | Evidence / note |
|---|---|---|---|
| A1 | Godot 4.7.2-stable editor, official, checksum verified | DONE | SHA-512 match vs official SHA512-SUMS.txt; `--version` = 4.7.2.stable.official.ed1daf0bf |
| A2 | Export templates 4.7.2 (.tpz, 1.22 GB) installed in tools/engine/editor_data/export_templates/4.7.2.stable | PENDING | download in progress; must verify SHA-512 before install |
| A3 | `export_presets.cfg` preset "Android" (debug APK, non-Gradle, arm64-v8a + x86_64, immersive, no permissions) | DONE (file) | untested until A2 |
| A4 | Editor settings: android_sdk_path = %LOCALAPPDATA%/Android/Sdk, java_sdk_path = JDK 25.0.2 | DONE | ANDROID_HOME env points to Z:\AndroidAVDs (not an SDK) — ignore it |
| A5 | Debug keystore | PENDING | Godot generates on first export/editor run; path in editor settings (local, git-ignored). Never committed |
| A6 | Release keystore + passwords via env vars `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD` | BLOCKED (user action) | 04 owns; never in source |
| A7 | Android SDK cmdline-tools (sdkmanager) | MISSING | only needed for Gradle/AAB build |
| A8 | Build-tools 35.0.1 (Godot docs) | PARTIAL | 35.0.0 / 36.x installed; verify apksigner works at export |
| A9 | AAB for Play (Gradle build, `gradle_build/use_gradle_build=true`, export_format=1) | PENDING | needs A7, NDK r28b per docs (27.1 installed), Android build template install |
| A10 | Device/emulator run (`adb install -r`, logcat, gfxinfo) | PENDING | no device attached at 06:20; AVDs exist under Z:\AndroidAVDs |
| A11 | APK loads atlases from imported .ctex (no raw-PNG fallback) | BLOCKED | 03 hand-written .png.import files lack remap path (02→03 R2) |
| A12 | Bundled Korean font (Android has no guaranteed system Hangul fallback for Godot) | PENDING | 03/04 (04 R5) |
| A13 | targetSdk / Play policy level | PENDING | Godot 4.7 template default; verify in exported manifest |

Exact commands: docs/contracts/ENGINE.md §3.
