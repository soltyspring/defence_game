# Offline save: Android backup and restore policy (owner: 06-services)
Version: 1 (2026-10-31). Scope: restore-service area while monetization stays deferred (user, Q2 16:09 KST). **This is a desk study of the repository, the built APK and official docs. No real-device test has been run.** Every "Verified on device" cell below says NOT TESTED.

Machine-checked by `tests/services/test_services_android.gd`: the §1 values must match `export_presets.cfg`, `src/core/save.gd` and (when aapt2 and the APK are present) the APK manifest; no export preset or checked APK may carry the ad ID, billing, internet or network-state permission; every §3 row has a source and a device-test status.

## 1. Current values (read 2026-10-31)
| Setting | Where it comes from | Current value | Evidence |
|---|---|---|---|
| allowBackup | Godot 4.7.2 prebuilt template manifest (we do not set it) | false | `aapt2 dump xmltree --file AndroidManifest.xml build/qa/apk_head/defence-debug.apk`; template https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/src/main/AndroidManifest.xml |
| dataExtractionRules | not set anywhere | absent | same aapt2 dump; template has no such attribute |
| fullBackupContent | not set anywhere | absent | same |
| hasFragileUserData | export_presets.cfg `package/retain_data_on_uninstall` | false | export_presets.cfg; APK manifest shows `hasFragileUserData=false` |
| use_gradle_build | export_presets.cfg `gradle_build/use_gradle_build` | false | export_presets.cfg (prebuilt template, so the manifest cannot be edited; AAB also needs a Gradle build, RELEASE_READINESS A12) |
| package | export_presets.cfg `package/unique_name` | com.soltyspring.lanedefence | export_presets.cfg; APK manifest |
| targetSdk | Godot template default | 36 | APK manifest `targetSdkVersion=36` (Android 12+ backup rules apply) |
| release preset | export_presets.cfg | none (only preset.0 "Android", debug export path, empty keystore) | export_presets.cfg; 04 R12-2 asks 02 for it. **Status: WAITING** |
| save path | src/core/save.gd `var path` | user://save.json | save.gd line `var path := "user://save.json"` |

APK read: `build/qa/apk_head/defence-debug.apk`, SHA-256 `09AF2E47989F147970B00E27DD4D9D3843EBD13060744B5119EFC19F5C70A6DE`, built 09:03 from 07e97ca by 04 (debug, `debuggable=true`). It is older than HEAD; the export settings above did not change since (export_presets.cfg only gained the font include filter, 02 R12-1).

### 1a. What lives in user:// on Android
Godot 4.7.2 maps `user://` to the app's private internal storage, `Context.getFilesDir()` (GodotIO.java `getDataDir()`, used by `OS_Android::get_user_data_dir`). On a phone this is typically `/data/user/0/com.soltyspring.lanedefence/files`; 06 has not read it on a device. Other apps cannot read it; uninstall and "clear data" delete it.

| File | Written by | Contents | Should a backup carry it? |
|---|---|---|---|
| user://save.json | save.gd | progress (rounds, stars, gold, upgrades, settings) and `progress.services` (reward ledger, entitlements; save_bridge.gd) in one file with a checksum | yes, if backup is turned on |
| user://save.json.bak | save.gd | previous good save | yes (recovery copy) |
| user://save.json.tmp | save.gd | write staging, exists only briefly | no |
| user://save.json.corrupt-<unix>[-n] | save.gd | quarantined unreadable saves | no |
| user://shots/ | app.gd (QA screenshots) | images | no |
| user://selftest_* | diag/selftest.gd (dev only) | test files | no (release preset should not ship it, 04 R12-2) |

The services ledger and the progress it protects are in the **same file**, so any backup restores them together. A restored older save cannot give a second reward for the same token: the ledger entry and the granted item come back as one snapshot (REWARD_STATE_TABLE.md).

## 2. Platform rules used (official sources, checked 2026-10-31)
| Rule (paraphrased) | Source |
|---|---|
| Apps targeting API 23+ take part in Auto Backup unless `allowBackup` is false; default is true | https://developer.android.com/identity/data/autobackup |
| Restore runs when the app is installed (Play, device setup, adb install), before first launch | same |
| Auto Backup covers cloud backup (Google Drive) and device-to-device (D2D) transfer; Android 12+ apps targeting 31+ use `dataExtractionRules`, Android 11 and lower use `fullBackupContent` | same |
| Android 12+ (targeting 31+): include/exclude rules in the old format do not affect D2D; on devices from some manufacturers `allowBackup="false"` disables Drive backup but not D2D | https://developer.android.com/about/versions/12/behavior-changes-12 |
| `data-extraction-rules` has separate `cloud-backup`, `device-transfer` and (Android 16 QPR2+) `cross-platform-transfer` sections | https://developer.android.com/identity/data/autobackup |
| `hasFragileUserData`: whether the user is offered to keep app data on uninstall; default false | https://developer.android.com/guide/topics/manifest/application-element |
| Data safety: data that never leaves the device is not "collected"; a user's own upload to their own cloud storage, which the app never accesses, need not be declared | https://support.google.com/googleplay/android-developer/answer/10787469 |
Content was rephrased for compliance with licensing restrictions.

## 3. Does the save survive? (current build: allowBackup=false, no rules, hasFragileUserData=false)
| ID | Scenario | Save survives? | Why | Source | Verified on device |
|---|---|---|---|---|---|
| S1 | App update from Play (same signing key) | Yes | update keeps internal storage | autobackup doc (restore only on install); Android app update behaviour | NOT TESTED |
| S2 | Uninstall, then reinstall on the same phone | **No** | uninstall deletes files dir; no keep-data prompt (hasFragileUserData=false); no cloud backup to restore (allowBackup=false) | application-element; autobackup doc | NOT TESTED |
| S3 | Settings → clear app data | **No** | files dir deleted | autobackup doc (files dir is app data) | NOT TESTED |
| S4 | New phone set up from a Google cloud backup | **No** | allowBackup=false disables Drive backup | autobackup doc; behavior-changes-12 | NOT TESTED |
| S5 | New phone by cable/wireless D2D transfer, Android 12+ on both | **Maybe** (depends on the maker) | some manufacturers still run D2D when allowBackup=false; we set no `device-transfer` rule | behavior-changes-12 | NOT TESTED |
| S6 | New phone by D2D, old phone Android 11 or lower | **No** (expected) | allowBackup=false opts out of backup and restore on these versions | autobackup doc | NOT TESTED |
| S7 | Debug or test APK replaced by a Play-signed release | **No** | different signing key cannot update in place; tester must uninstall first (S2) | Android signing rules (RELEASE_READINESS A12) | NOT TESTED |
| S8 | Transfer to iPhone (Android 16 QPR2 cross-platform) | **No** (expected) | no iOS app, no `cross-platform-transfer` rule | autobackup doc | NOT TESTED |
In plain words: today a player keeps progress across updates only. Reinstalling, clearing data or changing phones starts from round 1, except possibly a D2D transfer on some phones.

## 4. Options (not a decision; 01 decides whether the user is asked)
| Option | What changes | Save on reinstall / new phone | Work | Privacy and Data safety |
|---|---|---|---|---|
| B0 keep as is | nothing | lost (S2–S4), maybe kept on some D2D (S5) | none | no change; behaviour on S5 varies by phone maker |
| B1 back up the save only | Gradle build + manifest: `allowBackup="true"`, `dataExtractionRules` and `fullBackupContent` that include only `save.json` and `save.json.bak` (XML in §6) | restored from the user's Google backup on reinstall and new phone (S2, S4, S5); still lost after "clear data" without reinstall | 02: Gradle build template (needed for the AAB anyway); 06: privacy text switch; 07: device test plan §7 | privacy policy gets the [백업 활성화 시] sentence; Data safety stays "No" (06 judgement by analogy with the Drive FAQ, confirm when filling the form) |
| B2 no backup at all, made explicit | Gradle build + `dataExtractionRules` excluding everything in `cloud-backup` and `device-transfer` | lost in every case (closes the S5 maker gap) | 02: Gradle build; 07: device test | no change; behaviour the same on all phones |
| B3 keep-data prompt only | export option `package/retain_data_on_uninstall=true` (no Gradle needed) | kept on reinstall **if the user chooses to keep data** at uninstall; lost on new phone | 02: one export option | privacy line "삭제하면 함께 삭제" needs "unless you choose to keep data" |

**06 recommendation (not a decision): B0 now, B1 when 02 sets up the Gradle build for the AAB.** Reasons: B0 needs no change and matches every current privacy and Data safety answer. B1 fixes the common "lost my progress on a new phone" case, the save is small (one JSON file), holds no personal data, and the reward ledger travels with the progress it protects. B1 depends on the Gradle build, which the release needs anyway. Choose B2 instead if 01 wants identical behaviour on every phone and accepts lost progress.

Not recommended: backing up the whole files dir (would carry `.tmp`, `.corrupt-*`, screenshots), or adding a cloud-save account (needs a server, sign-in, Data safety "collected").

Cross-check by 10 (docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §9.9, request 10→06 v0.18, no change requested). On Godot 4.7.2, Android `user://` writes do not fsync. 10 infers, without a device test, that a power cut right after two quick saves could corrupt both `save.json` and `.bak`. A B1 backup copy would then be the only way back. The include-only rule set also leaves out the `save.json.tmp-XXXXXX` files Godot would create if save-and-swap were ever enabled.

## 5. Data safety and privacy policy re-check against the backup policy
| Statement | File | Holds under B0 (current)? | Under B1 | Under B2 | Under B3 |
|---|---|---|---|---|---|
| "Does the app collect or share user data? **No**" | DATA_SAFETY_DRAFT.md §3 | Yes: the save never leaves the device by the app's action; D2D (S5) is a user-initiated system transfer the developer never receives | Yes (06 judgement): the system copies the file to the user's own Google backup; the developer cannot access it. Confirm when filling the form | Yes | Yes |
| "Users can request deletion: not applicable; removed by uninstalling or clearing app data" | DATA_SAFETY_DRAFT.md §3 | Yes | Partly: a copy can stay in the user's Google backup until Google removes it; the user controls it in device/Google settings | Yes | Partly: the user may keep data at uninstall |
| "게임 진행 정보는 기기 안에만 저장되며 개발자에게 전송되지 않습니다" | PRIVACY_POLICY_DRAFT.md §1 | Yes | Yes for "not sent to the developer"; add the [백업 활성화 시] sentence | Yes | Yes |
| "게임을 삭제하거나 앱 데이터를 지우면 함께 삭제됩니다" | PRIVACY_POLICY_DRAFT.md §4 | Yes on this phone. A D2D copy on a new phone (S5) is the user's own transfer | Needs the [백업 활성화 시] sentence | Yes | Needs a "keep data" note |
| Content rating "Shares location / Users interact / Unrestricted internet: No" | CONTENT_RATING_DRAFT.md §2a | Yes (backup is a system function, no internet permission in the app) | Yes | Yes | Yes |
| Permissions: none (no INTERNET, AD_ID, BILLING) | RELEASE_READINESS A7; §1 | Yes (lint `android_permissions`) | Yes (backup needs no app permission) | Yes | Yes |
Result: **no contradiction with the current build (B0).** B1 and B3 need the privacy-policy sentence prepared in PRIVACY_POLICY_DRAFT.md `[백업 활성화 시]` / `[IF BACKUP ENABLED]`; Data safety stays "No".

## 6. Rule files for B1 (proposal for 02; not in the repo)
`res/xml/data_extraction_rules.xml` (Android 12+), referenced by `android:dataExtractionRules`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup>
        <include domain="file" path="save.json"/>
        <include domain="file" path="save.json.bak"/>
    </cloud-backup>
    <device-transfer>
        <include domain="file" path="save.json"/>
        <include domain="file" path="save.json.bak"/>
    </device-transfer>
</data-extraction-rules>
```
`res/xml/backup_rules.xml` (Android 11 and lower, minSdk is 24), referenced by `android:fullBackupContent`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <include domain="file" path="save.json"/>
    <include domain="file" path="save.json.bak"/>
</full-backup-content>
```
Domain `file` is the files dir, which is where Godot's user:// lives (§1a). If 02 ever sets `application/config/use_custom_user_dir` or moves the save, these paths must move with it.

## 7. Device test plan (all NOT RUN; needs a phone or the emulator, owner 07 with 02's AVD)
1. B0 on an Android 12+ emulator: install, win r01, `adb shell bmgr backupnow com.soltyspring.lanedefence`, uninstall, reinstall, start → expect round 1 (S2).
2. B1 build: same steps → expect r01 cleared and stars kept; `save.json.tmp` and `.corrupt-*` absent after restore.
3. B1: restore while a reward was in flight (ledger `pending`) → expect no double grant (reconcile on launch, REWARD_STATE_TABLE R-rows).
4. Release AAB: re-run the §1 aapt2 checks on the universal APK built from the AAB (bundletool), not on the debug APK.

## 8. Release preset and permissions check
The lint group `android_permissions` checks every preset in export_presets.cfg and every APK it finds under `build/qa/apk_head/`, `build/android/` and `build/release/`:
- **blocked permissions:** `com.google.android.gms.permission.AD_ID`, `com.android.vending.BILLING`, `android.permission.INTERNET`, `android.permission.ACCESS_NETWORK_STATE`. These must stay out while ads, billing and analytics are disabled (Q2 deferred).
- **Why the APK check matters more than the preset check:** the Google Mobile Ads SDK and the Play Billing library add AD_ID and BILLING through manifest merge in a Gradle build, so they would appear in the APK without any change to export_presets.cfg.
- **Release preset: WAITING.** There is no release preset yet (04 R12-2 → 02). When one appears (a preset whose name or export path says release, or an AAB/APK under `build/release/`), the same checks run on it automatically. Until then the lint reports `release_preset=WAITING`; this is not a failure.
