# 06-services → 02-engine
Status: QUEUED (file request, not confirmed delivered). Date: 2026-10-31.
Context: docs/services/SERVICES.md. Everything is DISABLED by default (D9). None of this is urgent for the playable slice. Do it when convenient; S1–S3 make the service state persist and are needed before any ad/IAP can be turned on.

## S1 Autoload (your decision)
Add `Services="*res://src/services/services.gd"` after `Save`. In disabled mode it only builds disabled adapters (no network, no SDK, no visible effect). Alternative: defer until 01 confirms monetization. Either is fine; tell me which.

## S2 Save integration (the "reward once" guarantee depends on it)
- Keep a `services` Dictionary in the payload: add `"services": {}` to `Save.fresh()`. `_migrate` already keeps unknown keys; please keep that true for `services` in future migrations.
- After every `Save.load_progress()` (including `.bak` recovery) call:
  `Services.setup({"store": preload("res://src/services/service_store.gd").new(Save.progress["services"], Save.save_progress)})`
  Reason: `load_progress()` replaces the `progress` Dictionary, so an earlier store reference would go stale.
- The service ledger and the reward are then written in the same atomic `save_progress()`.
- If you prefer an accessor (e.g. `Save.services_state() -> Dictionary` + a `Save.loaded` signal), tell me and I adapt.

## S3 Grant sinks (only when 01 enables placements/products)
- Ads: `Services.ads.grant_sink = Callable(...)` with signature `(placement_id: String, reward: Dictionary, context_id: String) -> bool`. Apply `reward.effect` in memory (data/meta.json: `gold_mult_2` at results_win, `player_base_heal_ratio_0_3` once in-round below 30%). Return false if the context is no longer valid (battle ended, already doubled). Do not save inside the sink; the service commits.
- Consumables: `Services.purchases.grant_sink` with `(product_id, grant: Dictionary, purchase_key: String) -> bool`.

## S4 Battle uid (additive contract key)
Add `battle_uid: String` to `BattleInfo` and `BattleResult`, unique per battle instance for at least 7 days (e.g. `"%d-%d" % [Time.get_unix_time_from_system(), counter]`). Ads use `result:<battle_uid>` / `rescue:<battle_uid>` as context ids so one battle can never be rewarded twice.

## S5 Analytics producers (no-op while disabled)
`Services.analytics.track("round_start", {"round_id": id, "attempt": n})`, `track("round_end", {round_id, won, stars, duration_s, kills})`, `track("session_start", {app_version, build, lang})`. Schema: docs/services/ANALYTICS_EVENTS.md. Undeclared params are rejected.

## FYI (not a request)
On 2026-10-31 `selftest.gd` returned exit 1 because of files I do not own: `src/audio/audio_manager.gd` (missing preload `audio_event_bridge.gd`) and `src/ui/hud_top.gd` (parse error). It reported no errors for src/services/**.

# Update M2 (2026-10-31) — still QUEUED, no reply seen
## S2 clarified (ordering now ledger-first)
06 writes the ledger entry into `Save.progress["services"]` BEFORE calling your grant sink, then calls `commit_fn` (= `Save.save_progress`). So a save during the sink is safe. Please still do not save inside the sink. Requested acceptance check, once you integrate: a headless test that kills the process (or simulates a failed `save_progress`) between the sink and the commit, then reloads, and shows that coins and `services.ads.granted_contexts` are both present or both absent. 06 has only shown this against a save double (tests/services/test_services_m2.gd `crash_ads`/`crash_iap`), not against src/core/save.gd. I will not claim cross-save atomicity until that real test exists.
Also: call `Services.setup()` once per load. Two live instances on the same store no longer double-grant (tested), but the second instance drops the first one's in-flight session.

## S6 Offer situations for the policy (needs S4 battle_uid)
- Results: `Services.ads.offer_for("ad_double_gold", {"kind": "result", "result": <BattleResult with battle_uid>})`.
- In battle: `Services.ads.offer_for("ad_base_repair", {"kind": "battle", "battle_uid": uid, "snapshot": <HudSnapshot>, "ended": false})`.
- An eligible rescue returns `constraints.max_stars = 2` (01 rule, RELEASE_DESIGN_REVIEW.md §3). Your sink should apply it to that battle's star result.
- Until S4 exists every call returns `not_eligible` with reason `missing_battle_uid`. That is intended fail-closed behaviour.

# Update M3 (2026-10-31) — still QUEUED, no reply seen
## S2 concrete wiring (tested against your save.gd, unchanged)
After EVERY `Save.load_progress()` (including in `_ready`):
`Services.setup({"store": preload("res://src/services/save_bridge.gd").make_store(Save, Events)})`
- Needs `Save` and `Events` as the autoloads at `/root/Save`, `/root/Events`. The save epoch is counted only when `Events` is `/root/Events` (save.gd emits there).
- A store bound before a reload refuses offers/grants/commits (fail-closed), so re-binding after each load is required.
- Keep ONE Save instance per save file. Two instances = last writer wins; tests show disk stays consistent but one grant is lost.
- Evidence: tests/services/test_services_m3.gd (11 groups, incl. real process death via a child Godot process). It still does not prove the game calls this, so I keep the claim "not integrated".
## Request S7 (optional, small): emit a save epoch you own
If you ever stop emitting `progress_changed` after each save, please expose `Save.saves_completed: int` instead; services would read it. No change needed today.

# Update M4 (2026-10-31) — BLOCKING for service persistence, QUEUED, no reply to S1/S2 seen
S1/S2 are now the blocking items for any claim that service state is persisted by the game. To make it a one-line change:
- S1: add `Services="*res://src/services/services.gd"` after `Save=` in project.godot `[autoload]`.
- S2: nothing else required. As autoload `Services`, services.gd attaches to `/root/Save` in `_ready` and rebinds within one frame after every `Save.load_progress()`. Mode stays `disabled`; no network, SDK or UI effect.
- Acceptance: `pwsh -File tests/services/run_services_suites.ps1` must go from `OVERALL exit=2 (BLOCKED_NOT_INTEGRATED)` to `exit=0`. Report: user://services_integration_report.json. Contract: docs/services/SAVE_INTEGRATION_CONTRACT.md.
- S3 grant sinks: not needed until 01 enables a placement/product (gate reports I5 NOT_REQUIRED_YET).
- S4 battle_uid: seen done (battle.gd:65/74/210); gate check I6 passes against your generator. Thanks.
- The fault hook 07/10 requested is not needed by this gate (it uses a directory at save.json.tmp and child-process OS.kill).

# Status check M6 (2026-10-31 ~09:2x KST) — still BLOCKING, QUEUED
Re-ran `pwsh -File tests/services/run_services_suites.ps1`: integration still exit 2 (I1–I4), `Services` not in project.godot. The one-line S1 change remains the only thing needed from 02 for the gate.

# Update M8 (2026-10-31 ~15:45 KST) — S1/S2 RESOLVED, thank you
Your autoload line (141d226) works: `pwsh -File tests/services/run_services_suites.ps1` → OVERALL exit 0, integration `verdict=PASS_INTEGRATED binding=game`, I1–I4 PASS, all R/P rows game evidence. New in services.gd (no action needed): purchases are reconciled automatically on attach and on NOTIFICATION_APPLICATION_RESUMED (disabled mode: no-op). Still open only when 01 enables a placement/product: S3 grant sinks.

# Backup/restore study (2026-10-31 16:56 KST) — QUEUED, nothing blocking now
Full study: docs/services/SAVE_BACKUP_POLICY.md (desk study; no device test run). Checked by `tests/services/test_services_android.gd` (now in the services runner).
- Current state, read from your files and 04's APK (07e97ca, SHA-256 09AF2E47…A6DE): `allowBackup=false` from the Godot 4.7.2 prebuilt template, no `dataExtractionRules`, no `fullBackupContent`, `package/retain_data_on_uninstall=false` → `hasFragileUserData=false`, `use_gradle_build=false`. Save is `user://save.json` (+ `.bak`, `.tmp`, `.corrupt-*`) in `Context.getFilesDir()`; the services ledger is inside the same file.
- Effect: progress survives updates only. It is lost on reinstall, on "clear data", and on a new phone from Google backup. On some makers' Android 12+ phones a device-to-device transfer may still copy it, because `allowBackup=false` alone does not stop D2D there (Android 12 behaviour changes).
- No change requested now (06 recommends option B0 until the Gradle build exists). 01 picks the option.
- **When you set up the Gradle build for the AAB (A12):** please do not hard-code a backup choice. Wait for 01's answer:
  - **B1** (06 recommendation): `allowBackup="true"` + `dataExtractionRules` + `fullBackupContent` with the two XML files in SAVE_BACKUP_POLICY.md §6. They include only `save.json` and `save.json.bak`.
  - **B2**: rules that exclude everything, for the same behaviour on every phone.
  - Either way, tell 06 so the §1 values and the lint follow.
  - If you ever change `Save.path` or set `use_custom_user_dir`, the §6 include paths must change too (the lint compares them with save.gd).
- **Release preset (04 R12-2):** none exists yet, so the lint reports `release_preset=WAITING` (not a failure). When you add one:
  - Keep `permissions/custom_permissions` empty and every `permissions/*` false while Q2 is deferred.
  - Export to a path or name containing "release" (or an .aab), so the check picks it up automatically.
  - The APK/AAB check scans `build/qa/apk_head/`, `build/android/` and `build/release/` for AD_ID, BILLING, INTERNET and ACCESS_NETWORK_STATE in the binary manifest. These matter because the Mobile Ads SDK and Billing library add AD_ID and BILLING by manifest merge without any preset change.
- The mutation tests for this lint use a temp copy of export_presets.cfg (`-- --presets=<path>`). Your file was never edited.

# 2026-10-31 17:25 KST — QUEUED: 2 untracked Godot .uid files in your paths (06 did not commit them)
Godot 4.4+ says `.uid` files must be committed (https://godotengine.org/article/uid-changes-coming-to-godot-4-4/). Without them, UID references break on other clones and Godot falls back to paths with warnings. Your `.gitignore` already allows them. Audit: docs/services/GODOT_UID_AUDIT.md.
- `src/core/diag/flip_check.gd.uid`, `src/core/diag/wave_clear_probe.gd.uid`. Both scripts are tracked (22d99ea). Please add them to your next Publish-Task `-Paths`.
- No tracked file uses these UIDs yet, so nothing is broken today.
- Suggestion for everyone: list `<script>.gd.uid` next to `<script>.gd` in `-Paths`. The helper stages only the listed files, and that is how these were missed.
- FYI: `Save.buy_upgrade` (4d77225) is now covered by `tests/services/test_services_upgrade.gd`. It checks that there are no Services, ads, billing or receipt calls and that `progress.services` is unchanged after a real purchase. It passes. The mutation tests use temp copies of save.gd and app.gd; your files were not edited.

# 2026-10-31 ~17:50 KST — QUEUED, after 01 records Q4 (launcher name). No change now
- The build's launcher name is `Lane Defence` (export_presets.cfg `package/name`, project.godot `config/name`; the 07e97ca APK shows `application-label:'Lane Defence'` in every locale). The store and in-game title are now "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense". Please wait for 01's Q4 record before changing anything.
- When you change it, two things to check (06 did not verify either):
  1. Whether ko and en launcher names can differ with the prebuilt template (`application/config/name_localized`, or `package/name` only).
  2. That renaming `config/name` moves the desktop `user://` folder (Windows `%APPDATA%/Godot/app_userdata/<name>`). Desktop test saves and the services tests' `user://svc_*` dirs would start fresh. Android is not affected; its files dir is per package.
- After the change, 06's lint `launcher_label_note` will fail until STORE_LISTING_DRAFT §2b states the new label. That is intended: 06 updates the doc.

# 2026-10-31 ~18:05 KST — Q4 DECIDED (user 17:19): launcher name ko "빵집 기사단", en "Bakery Knights". FYI on how 06 checks your change
- **Expected after your change:** `aapt2 dump badging` shows the ko label `빵집 기사단`. The en label (or the default label, if there is no en entry) shows `Bakery Knights`. The in-game and store titles stay the full working title.
- **06 check:** `tests/services/test_services_android.gd` group `launcher_label` reads the real label of every APK in `build/qa/apk_head/`, `build/android/` and `build/release/`. Rules:
  - All labels still `Lane Defence` = WAITING (built before your change). This is not a failure.
  - Labels that match Q4 = VERIFIED.
  - Anything else fails: a typo, the full title, a missing ko entry, or a mix with `Lane Defence`.
- It also checks `export_presets.cfg` `package/name` (once it is no longer `Lane Defence`, it must be one of the two Q4 names) and `application/config/name_localized` ko/en (if you set it).
- The check was tested on four throwaway APKs built with aapt2 (OK, typo, full title, wrong ko). They were deleted afterwards. Today both existing APKs read `Lane Defence`, so the status is WAITING.
- Reminder from the earlier entry: renaming `config/name` moves desktop `user://`. Android is unaffected.

# 2026-10-31 ~17:45 KST — QUEUED: Play technical requirements vs your export preset (static study; no Godot run)
Full table with official URLs: docs/services/PLAY_TECH_REQUIREMENTS.md. Results:
- **Passes on the 07e97ca debug APK:**
  - target API 36 (Godot 4.7.2 default; required since 2026-08-31)
  - 64-bit only (arm64-v8a + x86_64, no 32-bit)
  - 16 KB ELF LOAD alignment 0x4000 and RELRO layout on all 4 `.so`
  - zipalign -P 16
- **FAIL: no AAB.** New apps must ship as an AAB (https://support.google.com/googleplay/android-developer/answer/9844279). The preset uses the prebuilt template (`use_gradle_build=false`, `export_format=0`). Request, when you set up the release build (same as 04 A12):
  - a release preset with `use_gradle_build=true` and `export_format=1`
  - `target_sdk` empty or 36, `min_sdk` empty or 24
  - per Godot 4.7.2 config.gradle: AGP 8.6.1, NDK 29.0.14206865
  - no ad or billing plugin (Q2 deferred)
- **UNKNOWN until an AAB exists:** whether the uncompressed `.so` in the AAB are 16 KB zip-aligned (expected with AGP ≥ 8.5.1, not measured). 04 checks it with bundletool.

# 2026-10-31 ~17:50 KST — 4b5926d checked (read only), plus the impact of keeping config/name="Lane Defence"
- **Your format works with 06's check:** `package/name="Bakery Knights"` plus `config/name_localized` {en, ko}.
  - Services runner at 17:46: OVERALL exit 0.
  - `launcher_label=VERIFIED_DEBUG_ONLY`: build/android/defence-debug.apk (17:37) reads default/en `Bakery Knights`, ko `빵집 기사단`. The 09:03 apk_head still reads `Lane Defence` (built before your change).
  - `release_label=WAITING` until an APK or AAB appears in build/release/.
  - 06 changed only its own check and doc: the doc line now cites the export settings instead of the old build, and a debug APK no longer counts as release proof. Your files were not edited.
- **Where "Lane Defence" still shows** (static, no Godot run; table in STORE_LISTING_DRAFT.md §2b, source: ProjectSettings class reference):
  - **Desktop window title.** Godot sets it from `config/name` at startup, and src/ has no `window_set_title`. Seen in editor and PC runs and their screenshots, not on Android.
  - **Project Manager name and description** (developers only).
  - **`src/gameplay/fallback_ui.gd` hard-coded "LANE DEFENCE".** Players see it if the real menu scene fails to load.
- Options, all your call; Android is fine as is:
  - (a) leave the PC title as dev-only
  - (b) set the window title at startup from `name_localized` or ui.title, keeping the desktop `user://` path
  - (c) rename `config/name` with `use_custom_user_dir`. This still moves the desktop folder: a custom dir lives at `<OS data dir>/<name>`, not under `Godot/app_userdata/`.
  - The fallback text could use `ui.title`.

# 2026-10-31 ~17:58 KST — QUEUED: launcher icon in the export preset (static read; check after 18:30)
- `export_presets.cfg` has no `launcher_icons/*` keys, so Godot falls back to `config/icon` = res://icon.svg (16×16-grid placeholder).
- 03's adaptive layers pass the Android guide's size and safe-zone rules: 432×432, 0 px outside the 66 dp circle, opaque background (docs/services/STORE_GRAPHICS.md §2).
- When you are ready, please set:
  - `launcher_icons/adaptive_foreground_432x432` = res://docs/art/branding/adaptive/ic_launcher_foreground_432.png (or a copy under assets/, if docs/* stays excluded from export; your call)
  - `launcher_icons/adaptive_background_432x432` = the background layer
  - `launcher_icons/main_192x192` = 03's 192 candidate
- 06 reads the rebuilt APK's icon resources after 18:30. Not verified yet.

# 2026-10-31 ~18:46 KST — launcher icon: placeholder confirmed in both APKs; exact preset keys (06 read only)
- **Confirmed:** export_presets.cfg has no `launcher_icons/*` keys. Per Godot 4.7.2 `EditorExportPlatformAndroid::load_icon_refs` (platform/android/export/export_plugin.cpp), the build then uses:
  - main icon = `application/config/icon` = res://icon.svg
  - adaptive foreground = that same icon
  - adaptive background = template default
- **Measured:** both existing APKs (build/android 17:37 and apk_head 09:03) show `res/mipmap-xxxhdpi-v4/icon_foreground.webp` with 83% icon.svg colours, and `icon_background.webp` as a single colour #32516b. 03's layers are not used. Details: docs/services/STORE_GRAPHICS.md §2.
- **Please add to `[preset.0.options]`.** Option names are exactly as in export_plugin.cpp. Values are `res://` paths, file hint `*.png,*.webp,*.svg`:
  ```
  launcher_icons/main_192x192="res://<path>/app_icon_candidate_192.png"
  launcher_icons/adaptive_foreground_432x432="res://<path>/ic_launcher_foreground_432.png"
  launcher_icons/adaptive_background_432x432="res://<path>/ic_launcher_background_432.png"
  ```
  - Optional: `launcher_icons/adaptive_monochrome_432x432`. 03 has no monochrome layer yet.
  - `exclude_filter` contains `docs/*`. If you point at docs/art/branding/, check that the exporter still reads the source (it loads icons at export time). Otherwise copy the files under assets/ (03 owns the art; you choose the path).
- After your rebuild, 06 will compare the APK's `icon_foreground.webp`/`icon_background.webp` with 03's layers.
- **Services on clean HEAD 643cfa0** (snapshot runner, 18:43–18:44): OVERALL exit 0, 9 suites. That includes your 4b5926d (label VERIFIED_DEBUG_ONLY) and the new repo-wide Q2 scan: 0 ad, billing, receipt or SDK calls outside src/services, no addons/, no enabled plugins.

# 2026-10-31 ~19:06 KST — QUEUED: debug test AAB is blocked by the JDK (scratch try, your files untouched)
`tests/services/try_debug_aab.ps1` ran on a git-archive copy of f41fd12. Only in that copy it set `use_gradle_build=true`/`export_format=1` and unpacked android_source.zip (headless `--install-android-build-template` did not create android/build).
- **Result:** Godot's export step completed, including the ko label resource. Gradle 8.11.1 then failed: "Unsupported class file major version 69".
- **Cause:** the editor's `export/android/java_sdk_path` is JDK 25.0.2. Gradle needs 9.1+ for Java 25 (https://docs.gradle.org/current/userguide/compatibility.html). Godot recommends JDK 17, and the template's config.gradle uses Java 17.
- **Needed (machine setup, not a repo file):** install a JDK 17 and set `export/android/java_sdk_path` to it. Then add a Gradle/AAB preset (your file). 06 reruns the script and checks the AAB with bundletool (also not installed yet).
- No upload key was made and nothing was uploaded. My scratch copy and Gradle daemon are gone. Gradle 8.11.1 is now cached in the user's ~/.gradle.

# 2026-10-31 ~19:33 KST — test AAB built (scratch, private JDK 17); what the repo still needs
PLAY_TECH_REQUIREMENTS.md §6.
- **Test AAB:** scratch copy of 53883db, debug key, JDK 17 only inside the build process. Results:
  - 16 KB bundle alignment, split zipalign and ELF 0x4000 all PASS
  - target 36, min 24
  - arm64 + x86_64 only
  - labels en "Bakery Knights", ko "빵집 기사단"
  - no permissions, allowBackup=false
  - download ≈ 29.0 MiB (arm64)
- **Still needed in the repo/machine (yours):**
  1. A Gradle/AAB release preset in export_presets.cfg.
  2. A JDK 17 the editor uses. Today the editor setting says JDK 25, and Godot's own Gradle step fails. A private Temurin 17 is at `%LOCALAPPDATA%\svc06_tools\jdk-17.0.20.1+1` if you want to point `export/android/java_sdk_path` at it. That is your call; 06 did not change editor settings.
  3. Headless `--install-android-build-template` did not create android/build here; the script unpacks android_source.zip instead.
- **Launcher icon** is still the Godot placeholder in this AAB (no launcher_icons keys; see the 18:46 entry).

# 2026-10-31 ~19:46 KST — size: engine library is 85% of the 29 MiB arm64 download (PLAY_TECH_REQUIREMENTS.md §7)
- `libgodot_android.so` is 76.2 MB uncompressed, ≈ 25.9 MB of the ≈ 30.4 MB download. Project files are ≈ 2.3 MB and dex ≈ 2.1 MB.
- Candidates (not measured):
  - a size-optimized custom release template with unused modules disabled
  - measuring with release templates (this test used debug)
  - arm64-only release preset (AAB size only)
- **Install test not done:** no emulator was running at 19:34, and 06 did not start one. When LaneDefence_Phone is up, tell 06 a time slot (≈ 10 min) for bundletool `install-apks` + launch + logcat. 06 will not stop or restart the emulator.

# 2026-10-31 ~23:08 KST — still waiting for an emulator slot (install/run of the test AAB)
- `adb devices` was empty at 19:34 and 23:07. 06 will not start, stop or restart LaneDefence_Phone or its qemu.
- When it is up, please name a ~10 min slot here. 06 will then:
  1. `bundletool build-apks --connected-device` + `install-apks` (debug key, test AAB from tests/services/try_debug_aab.ps1)
  2. `adb shell monkey -p com.soltyspring.lanedefence 1`
  3. record the launcher label, first screen, crash (pidof) and the `logcat -s godot` error count
  4. uninstall only this test install if you want the device clean (tell 06)
- Test AAB on 29d31be, re-verified (PLAY_TECH_REQUIREMENTS.md §8): target 36, labels en/ko OK, 16 KB OK, arm64 download ≈ 30.4 MB.

# 2026-10-31 ~23:33 KST — after the blue screen: emulator slot request stands, under heavy_run
06's install check (bundletool install-apks, launch, label, first screen, crash, logcat count) will run inside **one** `coordination\heavy_run.ps1` block. When LaneDefence_Phone is up, name a time here. 06 will not start or stop the emulator or qemu. Note that 06 cannot start it either: starting it is a heavy run under the new rule and it is yours.

# 2026-10-31 ~23:40 KST — QUEUED: release-build line endings (10's content_version finding), measured on our builds
Static byte counts over the 21 tracked `data/**/*.json` files (PLAY_TECH_REQUIREMENTS.md §9):
- the repo stores LF;
- `git archive HEAD` on this PC gives CRLF for all 21, because the system gitconfig has `core.autocrlf=true`. That covers 06's test AAB, run_services_on_head and 04's apk_head;
- your build/android APK (shared tree) is LF except `data/economy.json`, which is mixed (18 CRLF / 1 LF).
So the same commit yields different `content_version` values depending on where it is built.

**Request (your files):**
1. Add `.gitattributes` at the root, e.g. `* text=auto eol=lf` (at least `data/** text eol=lf`, `*.json text eol=lf`), then renormalise once. **Or** make `_compute_content_version` hash data with `\r\n` → `\n`. Both is safest.
2. Build release AABs only from a checkout whose data bytes are checked as LF.
3. Fix `data/economy.json`'s mixed endings in the shared tree. 01 owns data; the mixed file is in the shared tree only, the blob is LF.

06 will check `assets/data/**` endings in the next test AAB (under heavy_run).

# 2026-10-31 ~23:55 KST — FYI: 06 builds now pin LF; measured in the AAB itself (PLAY_TECH_REQUIREMENTS.md §10)
- 06's test AAB and HEAD-snapshot runs now use `git -c core.autocrlf=false -c core.eol=lf archive` and refuse to build if any data JSON has CRLF (4bf8f74).
- **Rebuilt AAB on 3e355a8:** all 21 data files LF. content_version `c1-e8790a4f2e85` is the same three ways: from the AAB bytes, from the committed blobs, and as printed by Godot's `Content` on the build copy.
- The 23:40 request to you stands for every other build path (04's `tools/build/*` git archive, your shared-tree export): `.gitattributes` with `eol=lf` and/or a normalised hash. The same `-c core.autocrlf=false -c core.eol=lf` flags on `git archive` fix 04's builds without waiting.

# 2026-11-01 ~00:57 KST — FYI: 06 used your LaneDefence_Phone AVD read-only; release-checklist blocker RB1
- **Emulator use:** no emulator was running and there was no slot reply, so per coordinator instruction 06 started `build/avd` LaneDefence_Phone itself with `-read-only` (AVD files unchanged), `-no-window -no-snapshot-save -no-snapshot-load`, port 5590, inside heavy_run. 06 stopped it with `adb emu kill`; qemu 0 afterwards. Your app install was replaced only inside that read-only instance, not in the AVD.
- **Results** (PLAY_TECH_REQUIREMENTS.md §11; emulator only): the LF test AAB installs as a device APK set; the title menu shows; FATAL/ANR 0; labels OK; a save survives force-stop and is read (4321 coins shown).
- **RB1 (blocking, §12):** release builds must come from one LF path, or `_compute_content_version` must normalise CRLF. Today only 06's builds are LF.
