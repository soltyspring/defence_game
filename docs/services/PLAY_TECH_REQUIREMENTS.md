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

## 5. Debug-signed test AAB attempt (2026-10-31 18:51–19:02 KST, scratch copy only)
Script: `pwsh -NoProfile -File tests/services/try_debug_aab.ps1`. It works on a `git archive` copy of HEAD f41fd12 in %TEMP%. **Only in that copy** it sets `use_gradle_build=true` and `export_format=1`, and unpacks Godot's `android_source.zip` into `android/build`; `--install-android-build-template` did not create it headless. It then runs `--export-debug Android` with the editor's debug keystore. No upload key was created, nothing was uploaded, and 02/04 files were not changed. The scratch copy and the Gradle daemon were removed afterwards.

**Result: no AAB. Blocked at the Gradle step.**
| Step | Result |
|---|---|
| Godot export preparation (manifest, ko label resource `values-ko/godot_project_name_string.xml`, asset pack) | done |
| Gradle wrapper downloads Gradle 8.11.1 (Godot 4.7.2 template) | done (now cached in `%USERPROFILE%\.gradle`) |
| `gradlew validateJavaVersion clean bundleStandardDebug` | **FAILED**: "Unsupported class file major version 69" |
Cause: the only JDK on this machine is **25.0.2**, set in the editor's `export/android/java_sdk_path`. Gradle's official compatibility table says Java 25 needs Gradle 9.1.0 or later to run, and the Godot 4.7.2 template pins Gradle 8.11.1 (https://docs.gradle.org/current/userguide/compatibility.html). Godot's Android export doc recommends OpenJDK 17 (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). The template's `config.gradle` also asks for Java 17.

Not checked because no AAB exists: per-device APKs via bundletool, target 36, 64-bit, 16 KB alignment (`PAGE_ALIGNMENT_16K`), ko/en label in the bundle, download size. bundletool is not installed either. The verdicts in §3 stay as they are (P4 FAIL, P3c UNKNOWN).

What unblocks it (requested from 02/04; a machine setup step, not a 06 file change):
1. Install a JDK 17 and point the editor setting `export/android/java_sdk_path` at it. This is an editor_data setting, not in the repo.
2. Add a release/test preset with the Gradle build and AAB export to export_presets.cfg (02), or keep this scratch override.
3. Install bundletool (a jar from Google's bundletool releases) for the per-device APK checks.

## 6. Debug-signed test AAB built with a private JDK 17 (2026-10-31 19:09–19:31 KST, scratch copy of HEAD 53883db)
**How:** `pwsh -NoProfile -File tests/services/try_debug_aab.ps1 -JavaHome <jdk17> -Bundletool <jar>`.
- Godot prepares the Gradle project with its editor settings, then its own Gradle step fails on JDK 25 as in §5.
- The script then reruns **Godot's exact Gradle command** (`gradlew validateJavaVersion clean bundleStandardDebug …`, every argument quoted) with `JAVA_HOME` set **only inside that build process**.
- System PATH, JAVA_HOME, the registry and the shared editor settings were not changed.
- Signed with the editor's debug keystore. **No upload key was created and nothing was uploaded.** 02/04 files are untouched.
- Note: headless Godot re-saves `tools/engine/editor_data/editor_settings-4.7.tres` on exit with unchanged values (engine behaviour; untracked file).

**Results (measured on the AAB, SHA-256 0F9D39B0…C116BE, 59,198,558 B):**
| Check | Result | Tool |
|---|---|---|
| Bundle 16 KB zip alignment | `PAGE_ALIGNMENT_16K`, native libs uncompressed | `bundletool dump config` |
| Split APK alignment | `zipalign -c -P 16` "Verification successful" on base-arm64_v8a and base-x86_64 (libs at 16 KB offsets) | build-tools 36.1.0 |
| ELF LOAD alignment (arm64 split) | all LOAD segments 0x4000 | 06 ELF header read |
| min / target SDK | 24 / **36** | `bundletool dump manifest`, aapt2 on the universal APK |
| 64-bit | native-code `arm64-v8a`, `x86_64` only | aapt2 |
| Launcher label | default/en **Bakery Knights**, ko **빵집 기사단** | aapt2 on the universal APK |
| Permissions | none | aapt2 dump permissions |
| allowBackup | false | dump manifest |
| Download size (per ABI, all devices) | arm64-v8a 30,390,920–30,402,608 B (≈ 29.0 MiB); x86_64 33,177,021–33,188,709 B | `bundletool get-size total --dimensions=ABI` |
| Universal APK | 164,958,636 B (uncompressed libs; not what Play serves) | — |
Updated verdicts for §3:
- **P1, P2, P3a, P3c: PASS on a test AAB.** P3b (RELRO) is the same libraries as §2.
- **P4: an AAB can be built**, but only with a JDK 17 and a Gradle/AAB preset. Both are still missing from the repo setup (02).
- **Release label:** VERIFIED on this test AAB, but the AAB is not in build/release, so lint `release_label` stays WAITING.
- Play Console's own check needs an upload, which is a user action.

**Tools downloaded (06, for builds only; remove by deleting the folder):**
| Tool | Location | Version | SHA-256 (matches official) | Source |
|---|---|---|---|---|
| Eclipse Temurin JDK (zip, not installer) | `%LOCALAPPDATA%\svc06_tools\jdk-17.0.20.1+1\` | 17.0.20.1+1 | e53a79c3c3d86865bd7e787903884331068e71321714ffd44f145785affc7cb0 (Adoptium API `package.checksum`) | https://api.adoptium.net/v3/assets/latest/17/hotspot ; GitHub adoptium/temurin17-binaries |
| bundletool | `%LOCALAPPDATA%\svc06_tools\bundletool-all-1.18.3.jar` | 1.18.3 (2025-12-15) | a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29 (GitHub release asset digest) | https://github.com/google/bundletool/releases/tag/1.18.3 |
| Gradle 8.11.1 (downloaded by Godot's wrapper) | `%USERPROFILE%\.gradle\wrapper\dists\gradle-8.11.1-bin\` | 8.11.1 | not checked by 06 (wrapper handles it) | services.gradle.org |
Removal: delete `%LOCALAPPDATA%\svc06_tools\` (334 MB; the JDK zip was already deleted after extraction), plus `%USERPROFILE%\.gradle\wrapper\dists\gradle-8.11.1-bin\` if unwanted. Nothing else was installed. The scratch copy `%TEMP%\svc06_aab_*` was deleted.

## 7. End-to-end rerun of the committed script, install check, size breakdown (2026-10-31 19:34–19:45 KST, HEAD 84c18ab)
**Rerun (one command, clean snapshot):** `try_debug_aab.ps1 -TimeoutSec 900 -JavaHome … -Bundletool …`.
- Godot's own Gradle step reported **BUILD SUCCESSFUL in 1m 1s**, then copyAndRenameBinary, and produced `out/defence-debug.aab` directly. This happened even though the editor setting still says JDK 25 and the log shows "Updating JAVA_HOME … jdk-25.0.2".
- Gradle printed "1 incompatible and 2 stopped Daemons could not be reused" and started a new daemon. Why it now succeeds on JDK 25 is **not understood**. Possibly the Gradle cache left by the 19:2x JDK 17 run. Treat it as unproven; the JDK 17 path stays the reliable one.
- The Godot process again did not exit and was killed at 240 s, after the AAB was written.
| Item | 19:31 run (53883db) | 19:39 rerun (84c18ab) |
|---|---|---|
| AAB size / SHA-256 | 59,198,558 B / 0F9D39B0… | 59,200,008 B / 61C0F2FB… (different commit; not expected to match) |
| PAGE_ALIGNMENT_16K | yes | yes |
| Download size arm64-v8a | 30,390,920–30,402,608 B | 30,392,252–30,403,934 B (SDK 24–27 / 28 / 29+ split) |
| Download size x86_64 | 33,177,021–33,188,709 B | 33,178,353–33,190,035 B |
| Default label in bundle resources | Bakery Knights | Bakery Knights (`dump resources string/godot_project_name_string`) |
| ko label / target 36 / native-code via aapt2 on the universal APK | 빵집 기사단 / 36 / arm64+x86_64 | **not re-read**: the script's universal step had a PowerShell argument bug (`--output=(Join-Path …)` passed literally). Fixed after the run, not yet rerun |

**Install / run check: NOT DONE.** No emulator or device was attached (`adb devices` empty at 19:34). Per instructions 06 did not start one. Still open: bundletool `install-apks`, launch, launcher label on the home screen, first screen reached, no crash, logcat error count.

**Per-device download composition (arm64-v8a, SDK 29+: base-master + base-arm64_v8a + density + ko splits + install-time asset pack; deflate-6 estimate, close to bundletool's 30.40 MB):**
| Part | Files | Uncompressed | Est. download | Share |
|---|---|---|---|---|
| Native libraries (`libgodot_android.so` 76.2 MB, `libc++_shared.so` 1.4 MB) | 2 | 77.6 MB | 25.9 MB | **85.2%** |
| Godot project files (asset pack: fonts 1.0 MB, music 0.6 MB, scripts, atlases) | 331 | 2.6 MB | 2.3 MB | 7.5% |
| Java/Kotlin `classes*.dex` (Godot Android library) | 3 | 6.1 MB | 2.1 MB | 6.9% |
| Android resources | 64 | 0.09 MB | 0.05 MB | 0.2% |
| Signatures, manifest | 53 | 0.12 MB | 0.05 MB | 0.2% |
Largest single item: the engine library. Reduction candidates (requests to 02/08; none verified):
1. A custom **release** export template built with unused engine modules disabled (Godot's "Optimizing a build for size" docs), e.g. no 3D, no unused modules.
2. Release, not debug, templates. This test was a debug build; release templates are smaller but were not measured.
3. Drop x86_64 from the release preset. Play serves per ABI, so it does not change phone downloads; it only shrinks the AAB.
4. Smaller fonts (subset Galmuri to the used glyphs) and music bitrate (05/03), together about 1.6 MB uncompressed.

## 8. Committed script rerun with isolation (2026-10-31 23:01–23:07 KST, HEAD 29d31be)
One command: `pwsh -NoProfile -File tests/services/try_debug_aab.ps1 -Ref 29d31be -TimeoutSec 900 -JavaHome … -Bundletool …`. Every Godot call ran with a private APPDATA: `SVC06_ISOLATION isolated=true`, 0 new files in the real user folder, real save unchanged.
| Check | Result |
|---|---|
| AAB | 59,213,224 B, SHA-256 B88CC674…310BEE (different commit from §6/§7, so a different hash is expected) |
| Gradle | BUILD SUCCESSFUL (1 m 55 s), copyAndRenameBinary BUILD SUCCESSFUL |
| PAGE_ALIGNMENT_16K | yes |
| `out/universal_badging.txt` (the fixed step) | targetSdkVersion 36; application-label `Bakery Knights`, en `Bakery Knights`, ko `빵집 기사단`; native-code `arm64-v8a` `x86_64`; no uses-permission lines |
| Download size arm64-v8a | 30,404,872–30,416,554 B (SDK 24–27 / 28 / 29+) |
| Download size x86_64 | 33,190,973–33,202,655 B |
| Leftovers | no Gradle 8.11.1 / svc06_tools Java process running afterwards; %TEMP%\svc06_aab_29d31be deleted |
The §7 gap (universal-APK step not re-read) is closed. Install and run on the emulator is still **NOT DONE**: `adb devices` was empty at 23:07, and 02 has not announced LaneDefence_Phone.

## 9. Line endings of data files in the test AAB (static, 2026-10-31 ~23:40 KST, HEAD 91237d4)
Trigger: 10 found that `content_version` (src/core/content.gd, a hash of data/**) differs between CRLF and LF copies of the same data. A build from a CRLF copy and one from an LF copy would make every player save look "data changed" (DATA_AND_BACKEND_ANALYSIS.md). Byte counts of `\r\n` vs bare `\n` in the 21 tracked `data/**/*.json` files (no Godot run):
| Copy | LF | CRLF | mixed | Note |
|---|---|---|---|---|
| git blobs (committed) | 21 | 0 | 0 | the repo stores LF |
| shared working tree | 21 | 0 | 0 | LF despite autocrlf: files were written by tools, not re-checked-out |
| **`git archive HEAD`** (what `try_debug_aab.ps1` and `run_services_on_head.ps1` build from) | 0 | **21** | 0 | this PC has `core.autocrlf=true` (system gitconfig, Git 2.47.0.windows.1), and archive applies it |
| build/qa/apk_head APK (04, built from git archive) | 0 | 21 | 0 | `assets/data/**` in the APK |
| build/android APK (02, built from the shared tree, 17:37) | 20 | 0 | **1** | `data/economy.json` has 18 CRLF + 1 LF line ending |
**06's test AAB (§6–§8) therefore packed CRLF data.** This is an inference: the AAB was built from the same `git archive` path as the CRLF APK above. The AAB itself was deleted after the checks and was not re-read. Godot copies these non-resource JSON files byte for byte.
- Consequence: the three local builds (06 test AAB, 04 APK, 02 APK) carry three different `content_version` values for the same commit.
- Play policy: no effect.
- Release risk: a save made with one build is treated as migrated by another (X1 rewrite, unlock recompute, .bak rotation).
Request to 02 (root files are 02's): pin line endings for release builds, e.g. `.gitattributes` with `* text=auto eol=lf` (or at least `data/** text eol=lf`). Or make `content_version` normalise `\r\n` → `\n` before hashing. Then build releases only from a checkout verified as LF. 06 will re-read `assets/data/**` bytes in the next test AAB.

## 10. Test AAB rebuilt from an LF-pinned copy; data bytes read from the AAB itself (2026-10-31 23:42–23:52 KST, HEAD 3e355a8)
**Fix in 06's scripts (4bf8f74):** `try_debug_aab.ps1` and `run_services_on_head.ps1` now build from `git -c core.autocrlf=false -c core.eol=lf archive …`. Before any Godot step, a gate counts `\r\n` in every `data/**/*.json` of the copy. If any file has CRLF (or there are no data files), the script refuses with exit 5 and builds nothing. Static check: the old archive form gave 21/21 CRLF, the pinned form 0/21. This does not depend on 02's `.gitattributes`.

**Run:** one `heavy_run` block '06-test-aab-lf' (lock acquired after a 273 s wait).
- eol gate: 21 files, CRLF 0
- `SVC06_ISOLATION isolated=true`: 0 writes to the real folder, real save unchanged
| Check (read from the AAB, not inferred) | Result |
|---|---|
| `assetPackInstallTime/assets/data/**/*.json` entries | 21 (same as committed) |
| Files with any CRLF | **0** (every file is LF only; e.g. meta.json 216 LF, units.json 370 LF) |
| content_version from the AAB's data bytes (06 PowerShell reimplementation of `Content._compute_content_version`) | `c1-e8790a4f2e85` |
| content_version from the committed blobs at 3e355a8 | `c1-e8790a4f2e85` |
| content_version printed by Godot (`Content.content_version`) on the LF build copy, same heavy run | `c1-e8790a4f2e85` |
| Match | **all three equal** |
| AAB | 59,212,662 B, SHA-256 6F6C11CF…183698A2; PAGE_ALIGNMENT_16K |
| Labels / target / ABI (universal APK) | en/default Bakery Knights, ko 빵집 기사단; target 36; arm64-v8a + x86_64 |
| arm64 download | 30,404,065–30,415,747 B |
| Leftovers after the run | %TEMP%\svc06_aab_* deleted, no svc06_iso_* folder, 0 Gradle 8.11.1 / svc06_tools Java processes |
The PowerShell reimplementation (`tests/services/svc06_content_version.ps1`) was checked first against 10's published values for 7b93d1f (LF `c1-a7b265ce4f6f`, CRLF `c1-ea9c929ba40e`); both reproduce exactly. The §9 inference ("06's AAB carried CRLF") applied to the earlier builds. From 4bf8f74 on, 06 test builds carry LF data, and the value matches the repo. Builds from other paths (04 apk_head, 02's shared tree) are still as in §9 until 02 pins line endings.

## 11. Test AAB installed and run on an emulator (2026-11-01 00:14–00:56 KST; EMULATOR EVIDENCE ONLY)
**Not a real-phone check and not a payment check.** Ads and billing stay disabled (Q2 deferred). Debug key; nothing uploaded.

**AAB:** rebuilt from the LF-pinned copy of 3e355a8 in heavy_run '06-aab-emu-check'.
- eol gate 21/0; AAB data CRLF 0
- content_version c1-e8790a4f2e85 = committed blobs
- AAB SHA-256 4B7A24CF…2CD98, 59,212,655 B

**Script:** `tests/services/emu_install_check.ps1`, run inside heavy_run '06-emu-check'.
- No emulator was running, so 06 started `build/avd` LaneDefence_Phone itself: `-no-window -no-snapshot-save -no-snapshot-load -read-only -no-audio -no-boot-anim -gpu host -port 5590`. `-read-only` leaves the AVD files unchanged; 02's install on the AVD was only replaced inside this throw-away instance.
- Device: sdk_gphone64_x86_64, Android 16 / API 36, x86_64.
- Device APK set: `bundletool build-apks`/`extract-apks` with the device spec + ko-KR → base-master, base-x86_64, base-xhdpi, base-en, base-ko, assetPackInstallTime. Installed with `adb install-multiple` → **Success**.
| Check | Run 2 (00:49) | Run 3 (00:52, final) |
|---|---|---|
| Boot (cold) | 25 s | 26 s |
| Installed target SDK | 36 | 36 |
| Launcher label (installed package) | default `Bakery Knights`; `split_config.ko.apk` contains `빵집 기사단` | same |
| First launch | running (pid); `[App] boot ok … title=Bakery Knights: Mold Defense screen=menu … save_recovered=false` | same |
| Title shown | screenshot `docs/services/evidence/emu_first_launch.png`: logo "Bakery Knights / Mold Defense", Play / Select Round / Upgrades / Settings, 0 coins | — |
| Godot log errors (`ERROR`/`SCRIPT ERROR`) | 0 | 0 (one "Failed to load cached shader, recompiling" warning) |
| logcat FATAL / Fatal signal / F DEBUG lines | **76, not attributed** (full log not kept in that run) | **0** |
| ANR | 0 | 0 |
| Save persistence | — | a valid save (checksum per save.gd; coins 4321, unlocked_round 2) was written to `files/save.json` via `run-as`, then: launch (no recovery) → `am force-stop` → relaunch. The file is byte-identical (sha 3de5c46d…), `save_recovered=false`, and screenshot `emu_relaunch.png` shows **4321 coins and "Continue"**, i.e. the game read it |
| After relaunch | running, FATAL 0, ANR 0 | same |
| Cleanup | `adb emu kill` → emulator exited; qemu 0; Gradle/svc06 Java 0 | same |
Limits:
- The 76 lines in run 2 cannot be attributed afterwards. In that run the app process was alive and its Godot log had 0 errors. The final run, which records per-process attribution (`logcat_fatal_*.txt`), shows 0.
- The ko label was checked in the installed ko split, not visually on the launcher (device locale en-US).
- The save was seeded, not created by gameplay. The game did not rewrite it on boot (no data change required a write). So this shows the files dir survives a force-stop and is loaded, not a gameplay-made save.
- Run 1 (00:20) failed at device-spec handling and was fixed. The 00:41 attempt timed out at boot (warm boot) and was fixed with `-no-snapshot-load`.
- Evidence files (6ca56a7): trailing spaces at line ends of the logcat extracts were trimmed (the repo whitespace check rejects them), and the local temp path in `emu_check.json` was replaced by `%TEMP%`. No other content changed.

## 12. Release checklist (blocking items)
| ID | Item | Status | Blocks release until |
|---|---|---|---|
| RB1 | **One line-ending path for every release build.** All release AAB/APK builds come from one build path whose data bytes are LF (06's pinned `git -c core.autocrlf=false -c core.eol=lf archive` + CRLF gate, or a checkout covered by `.gitattributes eol=lf`), **or** 02 normalises `\r\n`→`\n` in `Content._compute_content_version`. Today 06 builds are LF (§10). 04 `tools/build/build_android_debug.ps1` (plain git archive → CRLF on this PC) and 02 shared-tree exports (LF + mixed `data/economy.json`) are not | **OPEN (blocking)** | the release build's `assets/data/**` is checked LF (or the hash is normalised) and its content_version equals the repo's (06 `aab_data_check.txt`) |
| RB2 | Gradle/AAB release preset in export_presets.cfg (02) and a JDK 17 the build uses | OPEN | §4, §6 |
| RB3 | Launcher icon keys set (02), placeholder replaced | OPEN | STORE_GRAPHICS.md §2 |
| RB4 | Real phone run (not emulator) and Play Console 16 KB / 64-bit status on the uploaded bundle | OPEN (user / 07) | §11 is emulator-only |
| RB5 | KIPRIS check before the final store name | OPEN (user) | KIPRIS_MANUAL_CHECK.md |
