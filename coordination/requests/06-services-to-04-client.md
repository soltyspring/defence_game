# 06-services → 04-client
Status: QUEUED (file request, not confirmed delivered). Date: 2026-10-31.
Context: docs/services/SERVICES.md, PRODUCTION_REQUIREMENTS.md, ANALYTICS_EVENTS.md. Ownership note: tests/services/** is 06-owned (eight-worker expansion).
01 asked for no visible ad/IAP UI until the user decides (01-director-to-04-client). Everything below is for AFTER approval, except U4 which is input you can use now.

## U1 UI states from service result codes (after approval)
- Show a "watch ad" button only when `Services.ads.availability(placement_id, context_id) == "ok"`. Call `request()` and wait for `Services.ads.finished(request_id, placement_id, code)`.
- Purchases: `Services.purchases.availability(product_id)`, `purchase()`, then `purchase_finished(product_id, code)`. Required: a "Restore purchases" button calling `restore()` and showing `restore_finished(summary)`.
- Map codes to text keys `svc.<code>` (01 owns data/text). `pending` needs a "payment pending" message; `verification_unavailable` needs "could not confirm purchase, try Restore later"; `already_owned` should suggest Restore.

## U2 Privacy settings (after ads or analytics approval)
A settings entry that calls `Services.consent.set_choice(purpose, "granted"|"denied")` and `withdraw_all()`. Purposes: `ads`, `ads_personalized`, `analytics`. Defaults are `unknown` = blocked.

## U3 Android export (after approval only)
Plugin install (ads/billing candidates in PRODUCTION_REQUIREMENTS.md §1–2), INTERNET and AD_ID permissions, app/ad unit IDs and licence key in git-ignored export config handed to 02's boot `Services.setup()`. Not before approval; INTERNET stays off.

## U4 Privacy disclosure input (usable now)
ANALYTICS_EVENTS.md §4 is a data inventory for the Play Data safety form and privacy policy draft. Current honest answer: the game collects and shares no data. That changes the moment an ad SDK, billing or remote analytics ships.

## U5 Optional
A native connectivity check could back `src/services/network_probe.gd` (today it reports `unknown`). Low priority.

# Update M2 (2026-10-31) — still QUEUED, after approval only
- Offer buttons: prefer `Services.ads.offer_for(placement_id, situation)` (policy + gates, no SDK call). Show only on `code == "ok"`. Treat `not_eligible` as "do not show". The `reason` field is for logs, not players.
- When an offer becomes visible, call `Services.telemetry.offer_shown(placement_id, context_id)`. It is de-duplicated and gated by analytics consent.
- Debug overlay: `Services.diagnostics()` returns a detached, JSON-safe snapshot without tokens or ids.

# Update M5 (2026-10-31) — QUEUED, input only (no work until the user decides)
docs/services/RELEASE_READINESS_SERVICES.md §2 lists items in your area: B8 purchase-received UI, B9 Gradle build for billing plugins (export_presets.cfg:25 is false), A1 reward disclosure/opt-in UI, A2 privacy-options button, V2 in-app privacy policy link (required for every release, even with no data collected), C1 confirm exported targetSdk ≥ 36 (export_presets.cfg:31 is empty, engine default unverified).

# Update M6 (2026-10-31) — QUEUED
- Privacy policy template: docs/services/PRIVACY_POLICY_DRAFT.md. Play requires a link or the text inside the app (V2). Suggest a "개인정보처리방침 / Privacy Policy" entry in settings opening `{{PRIVACY_POLICY_URL}}` once the user supplies hosting (OPEN_DECISIONS.md U3).
- Store listing draft for screenshots/feature graphic captions: docs/services/STORE_LISTING_DRAFT.md. Screenshots must show the real build (Metadata policy).

# Update M9 (2026-10-31) — QUEUED, input only (no install before user approval)
Billing plugin candidates (checked 2026-10-31, both MIT, both Billing 9.1.0): GodotGooglePlayBilling 3.3.0 (the plugin the Godot docs link) and AndroidIAPP v2.2. Both need the Android Gradle build (export_presets.cfg:25 is false today). When approved, please verify on a real export: merged manifest contains com.android.vending.BILLING and com.google.android.play.billingclient.version, and which purchase fields (signature, original JSON, quantity) the plugin exposes. Details: docs/services/BILLING_PLUGIN_CANDIDATES.md, setup steps S7/S10 in BILLING_SANDBOX_TEST_PLAN.md.

# R-M11 (2026-10-31) — QUEUED: credits panel content and privacy link (needed for ANY Q2 option)
Spec and acceptance checks: docs/services/IN_APP_LEGAL_DISPLAY.md. Summary of what the credits/settings area should contain:
1. Settings: a "개인정보처리방침 / Privacy Policy" button next to Credits that opens `{{PRIVACY_POLICY_URL}}` with OS.shell_open (hidden while no URL is configured), plus one offline line "현재 이 게임은 개인정보를 수집하지 않습니다 / This game currently collects no personal data" (true only in disabled mode). Play requires a link or the text inside the app even when nothing is collected.
2. Credits (exists): add developer `{{DEVELOPER_NAME}}`, "Art, music and sound: original works made for this game", "Made with Godot Engine", keep the Galmuri line.
3. New "오픈소스 라이선스 / Open source licenses" scroll view under Credits: full text of res://assets/fonts/OFL-Galmuri.txt (OFL condition 2 needs the copyright notice and licence in each copy; today the panel shows only a file path the player cannot open), Godot MIT text from Engine.get_license_text() with "This game uses Godot Engine…", and the third-party list from Engine.get_copyright_info()/get_license_info() (Godot docs "Complying with licenses").
4. Re-verify in a new APK that OFL-Galmuri.txt is packed (your A6; the 07e97ca APK I inspected has fonts_provenance.json but no OFL txt), and that aapt2 still shows no permissions after adding the browser link.
Data safety: I confirmed your A7/C1 result (no permissions, no INTERNET) against the same APK (SHA-256 09AF2E47…A6DE) and HEAD 8ad912f; "No data collected or shared" holds for the disabled build until the release AAB is re-checked with the same commands (docs/services/DATA_SAFETY_DRAFT.md §2a).

# Backup study + permission check (2026-10-31 16:56 KST) — QUEUED
- **New check:** `tests/services/test_services_android.gd` (in the services runner) checks your APK `build/qa/apk_head/defence-debug.apk` and any APK/AAB under `build/android/` or `build/release/`.
  - It fails on AD_ID, BILLING, INTERNET or ACCESS_NETWORK_STATE in the binary manifest. It also runs `aapt2 dump permissions` when aapt2 is installed.
  - It compares `allowBackup`, `dataExtractionRules`, `fullBackupContent`, `hasFragileUserData` and `targetSdk` with docs/services/SAVE_BACKUP_POLICY.md §1.
  - Today it passes on your 07e97ca APK: `allowBackup=false`, no rules, `hasFragileUserData=false`, target 36, no permissions.
- **Release preset R12-2:** not present yet (`release_preset=WAITING`). When you or 02 build a release APK/AAB, please put it under `build/release/` (or tell 06 the path) so the same check runs on it. Please also add AD_ID and BILLING to your A7 aapt2 check. For an AAB, run it on the universal APK from bundletool.
- **Player-visible effect for your QA notes:** progress is lost on reinstall, on "clear data" and on a new phone (except some device-to-device transfers). A tester who replaces a debug APK with a Play-signed build must uninstall first, so they start over (S7). Nothing has been tested on a device.

# 2026-10-31 17:25 KST — QUEUED: 3 untracked Godot .uid files in your paths (06 did not commit them)
Godot 4.4+ says `.uid` files must be committed (https://godotengine.org/article/uid-changes-coming-to-godot-4-4/). Audit: docs/services/GODOT_UID_AUDIT.md.
- `src/ui/title_block.gd.uid`, `src/ui/upgrade_panel.gd.uid`, `tests/ui/redraw_probe.gd.uid`. All three scripts are tracked. Please add the `.uid` files to your next Publish-Task `-Paths`. No tracked file uses these UIDs yet.
- FYI: `tests/services/test_services_upgrade.gd` reads your upgrade_panel.gd (comments stripped). It fails if the panel code references Services, billing, receipt, token, sku, product, rewarded/show_ad, iap, gems, shell_open or HTTP. Your word "purchase" for the coin spend is allowed. It passes today.

# 2026-10-31 ~17:45 KST — QUEUED: release checks to add for Play's 16 KB / 64-bit / API 36 rules (static study; no Godot run)
Details and URLs: docs/services/PLAY_TECH_REQUIREMENTS.md. Your 07e97ca debug APK passes target 36, 64-bit, ELF LOAD 0x4000 + RELRO, and zipalign -P 16. Its `.so` are compressed, so the zip check is trivially OK. The release AAB is the open part. On the first AAB (A12), please record:
1. `bundletool dump config --bundle=<aab>` → `PAGE_ALIGNMENT_16K`.
2. On the universal APK from bundletool:
   - `zipalign -v -c -P 16 4` → "Verification successful"
   - ELF LOAD align ≥ 0x4000 and the RELRO check per https://developer.android.com/guide/practices/page-sizes (NDK `llvm-readelf -Wl`; NDK r27 is installed here, readelf not on PATH)
   - `aapt2 dump badging` → targetSdkVersion 36 and the Q4 label
3. After the user's first internal-track upload: the 16 KB and 64-bit status in Play Console's app bundle explorer (user action).
06's test_services_android also re-reads permissions and labels from APKs under build/release/.

# 2026-10-31 ~17:50 KST — FYI for screenshots and QA after 02 4b5926d (static check, no Godot run)
- **Android launcher label is correct** in the debug APKs built at 17:36 and 17:37: default/en "Bakery Knights", ko "빵집 기사단". 06's check reports `VERIFIED_DEBUG_ONLY`, and the release label is WAITING until build/release has an APK or AAB.
- **"Lane Defence" can still appear in:**
  - the desktop window title (Godot sets it from `config/name`, which 02 kept to protect desktop `user://`)
  - the Godot Project Manager
  - the engine fallback menu (src/gameplay/fallback_ui.gd "LANE DEFENCE", shown only if scenes/ui fails)
- For store screenshots, capture on Android or crop the PC window frame, so the old title is not in the image.
- Full table: STORE_LISTING_DRAFT.md §2b.

# 2026-10-31 ~17:58 KST — QUEUED: store screenshots (Play rules; static check, no Godot run)
Details: docs/services/STORE_GRAPHICS.md. Checker: `python tests/services/check_store_graphics.py` (no Godot).
- **Needed:** at least 3, better 6, real-gameplay screenshots, **1920×1080, 16:9 landscape, RGB with no alpha** (JPEG or 24-bit PNG). The 640×360 game view ×3 is exactly 1920×1080. Please put the finals in `docs/services/store_assets/screenshot_<nn>_<ko|en>.png` or tell 06 the path.
- **Why the existing captures don't qualify:**
  - The 1600×720 emulator captures fail: Play rejects images whose long side exceeds twice the short side (20:9).
  - The 1280×720 captures are below the 1920×1080 asked for game recommendations, and 136 of them have an alpha channel.
- **Order:** 09 §32.1. The first 3 should be real battle UI. For #3 use **밀가루**, not 반죽 (D25).
- **Captions:** ≤ 20% of the image, no "play now"-style call to action, no ranking words.
- **Q2:** no shop or price screen.
- **Do not capture the PC window frame** (title "Lane Defence"), and no device frames or fingers.
- Anything needing a Godot run waits until after 18:30.

# 2026-10-31 ~19:06 KST — FYI: AAB (your A12) blocked by JDK 25 vs Gradle 8.11.1
Details: PLAY_TECH_REQUIREMENTS.md §5. A JDK 17 for `export/android/java_sdk_path` is the first step. bundletool is also not installed, and you need it for the 16 KB/label/size checks on the AAB.
