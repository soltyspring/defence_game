# Google Play technical requirements vs our Android export (owner: 06-services)
Version: 1 (2026-10-31 ~17:40 KST). **Static study: no Godot, editor or emulator was run** (coordinator quiet window 18:00–18:30 for 08; this work used only file reads, `zipalign -c` and a byte-level read of ELF headers inside the existing APK). **No real device test and no Play Console upload were done.** Q2 stays deferred (no ad or billing SDK), and nothing was published.

Inputs read:
- `export_presets.cfg` (02's file, read only)
- Godot 4.7.2-stable source and docs
- the existing debug APK `build/qa/apk_head/defence-debug.apk` (built 09:03 by 04 from 07e97ca; SHA-256 09AF2E47…A6DE). Its export settings match HEAD except the font include filter.

## 1. Requirements (official sources, checked 2026-10-31)
| ID | Requirement (paraphrased) | Since / deadline | Source |
|---|---|---|---|
| P1 | New apps and app updates must target Android 16 (API 36) or higher; extension to 2026-11-01 can be requested | 2026-08-31 | https://support.google.com/googleplay/android-developer/answer/11926878 |
| P2 | Apps with native code must include 64-bit libraries; for each 32-bit ABI shipped, the matching 64-bit ABI is required (armeabi-v7a → arm64-v8a, x86 → x86_64) | in force | https://developer.android.com/google/play/requirements/64-bit ; https://support.google.com/googleplay/android-developer/answer/17492799 (Technical Requirements) |
| P3 | Apps with native code must support devices with 16 KB memory page sizes (apps targeting Android 15+, on 64-bit devices) | Google Play blog: new apps and updates from **2025-11-01**. The Android page fetched today adds that from **2027-02-01** updates without 16 KB support cannot be released. Treated here as **required now for a new app** | https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html ; https://developer.android.com/guide/practices/page-sizes ; https://support.google.com/googleplay/android-developer/answer/17492799 |
| P3a | 16 KB, part 1: every `.so` LOAD segment aligned to ≥ 2**14 (0x4000) | with P3 | page-sizes doc, "Check ELF alignment" |
| P3b | 16 KB, part 2: GNU_RELRO end must not leave writable data inside a read-only 16 KB page. The modulo rule applies only when RELRO shares a LOAD segment with later writable data; RELRO in its own LOAD segment is compliant | with P3 | page-sizes doc, "Check the RELRO security flag" |
| P3c | 16 KB, part 3: uncompressed `.so` files must be 16 KB zip-aligned (`zipalign -c -P 16`); bundles should show `PAGE_ALIGNMENT_16K` (`bundletool dump config`); AGP ≥ 8.5.1 does this | with P3 | page-sizes doc, "Update the packaging of your shared libraries" |
| P4 | New apps must be published as an Android App Bundle (AAB), with Play App Signing | 2021-08 | https://support.google.com/googleplay/android-developer/answer/9844279 ; https://developer.android.com/guide/app-bundle |
Content was rephrased for compliance with licensing restrictions.

## 2. What our export has (read 2026-10-31)
| Item | Value | Where read |
|---|---|---|
| Engine | Godot 4.7.2-stable | tools/engine binary name; APK meta-data `org.godotengine.library.version=4.7.2.stable` |
| Gradle build | `gradle_build/use_gradle_build=false` (prebuilt template); `gradle_build/export_format=0` (APK) | export_presets.cfg |
| target / min SDK in preset | `gradle_build/target_sdk=""`, `gradle_build/min_sdk=""` (empty = Godot defaults; these options are used only by a Gradle build, per the Godot class reference) | export_presets.cfg; https://docs.godotengine.org/en/stable/classes/class_editorexportplatformandroid.html |
| Godot 4.7.2 defaults | targetSdk 36, minSdk 24, compileSdk 36; Gradle template AGP 8.6.1, NDK 29.0.14206865 | https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/config.gradle |
| target / min SDK in the APK | targetSdkVersion 36, minSdkVersion 24 | aapt2 dump xmltree (SAVE_BACKUP_POLICY.md §1) |
| Architectures in preset | arm64-v8a **true**, x86_64 **true**, armeabi-v7a false, x86 false | export_presets.cfg |
| Native libs in the APK | lib/arm64-v8a/{libgodot_android.so, libc++_shared.so}, lib/x86_64/{same}; no 32-bit folders | zip listing |
| `.so` storage | compressed (`extractNativeLibs=true` in the manifest) | zip entries, APK manifest |
| `gradle_build/compress_native_libraries` | false (affects only a Gradle build; Godot's doc recommends false for Play) | export_presets.cfg; Godot class reference |
| ELF LOAD alignment (all 4 `.so`) | every LOAD segment `p_align = 0x4000` | 06 read the ELF64 program headers from the APK bytes (same fields `llvm-readelf -Wl` prints; NDK readelf not installed here) |
| GNU_RELRO (all 4 `.so`) | RELRO starts and ends exactly with its own writable LOAD segment; the next writable LOAD starts after the 16 KB round-up (e.g. arm64 libc++: RELRO end 0x153000, next LOAD 0x156B88 ≥ 0x154000). The modulo rule's remainder is non-zero for 3 of the 4 files, but by the page-sizes doc that case is compliant | same ELF read |
| zipalign 16 KB | `zipalign -v -c -P 16 4` → "Verification successful" (the 4 `.so` are compressed, so "OK - compressed") | build-tools 36.1.0 |

## 3. Verdict per requirement
| ID | Verdict | Why | Evidence level |
|---|---|---|---|
| P1 target API 36 | **PASS** (debug APK) | targetSdk 36 = Godot 4.7.2 default | measured on the debug APK; release AAB not built |
| P2 64-bit | **PASS** | no 32-bit ABI shipped; arm64-v8a present (x86_64 too) | preset + APK listing |
| P3a ELF LOAD 16 KB | **PASS** (debug APK) | all LOAD segments 0x4000 | 06's header read of the APK; not cross-checked with llvm-readelf or Play Console |
| P3b RELRO | **PASS** (debug APK), by the doc's "own LOAD segment" rule | no writable bytes between RELRO end and the next 16 KB boundary | same; an inference from the doc's rule, not a device run |
| P3c zip alignment | **PASS for this APK; UNKNOWN for the release AAB** | this APK keeps `.so` compressed. A Gradle AAB with `compress_native_libraries=false` stores them uncompressed, and those must be 16 KB zip-aligned. AGP 8.6.1 ≥ 8.5.1 should do this. **Inference, not measured**: confirm `PAGE_ALIGNMENT_16K` with bundletool | Godot config.gradle + page-sizes doc |
| P4 AAB | **FAIL (not set up)** | the preset exports an APK from the prebuilt template; an AAB needs Godot's Gradle build (`use_gradle_build=true`, `export_format=1`). Same blocker as 04 RELEASE_READINESS A12 | preset; Godot export doc ("To export an AAB file you need to set up Gradle builds") https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html |
| P3 overall on Play | **UNKNOWN** | the authority is Play Console's app bundle explorer on the uploaded AAB. Not done: no AAB, no upload | — |
Not a policy issue: shipping x86_64 is allowed. arm64-only for release is a size choice (04 R12, 08 R1).

## 4. What has to change (requests sent to 02 and 04; nothing here is a 06 change)
1. **02:** add a release preset with the Gradle build and AAB export (`use_gradle_build=true`, `export_format=1`). Keep `target_sdk` empty or 36, and `min_sdk` empty or 24. The Gradle template brings AGP 8.6.1 and NDK r29. Keep Q2: no ad or billing plugin and no extra permissions (06's `android_permissions` check covers this).
2. **04 (release verification), on the first AAB:**
   - `bundletool dump config --bundle=<aab>` must show `PAGE_ALIGNMENT_16K`.
   - Run `zipalign -v -c -P 16 4` and the ELF LOAD/RELRO check on the universal APK from bundletool.
   - Check `aapt2 dump badging` for targetSdk 36 and the Q4 label.
   - After the user's internal-track upload, read Play Console's app bundle explorer for 16 KB and 64-bit status. That is a user action.
3. **Not now:** a 16 KB emulator image or device run. That needs an emulator, which is outside this task and after the 18:00–18:30 quiet window.
