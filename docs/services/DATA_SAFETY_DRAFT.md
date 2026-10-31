# Google Play Data safety form — draft answers, disabled mode (owner: 06-services)
Version: 1 (2026-10-31). Status: **DRAFT, not submitted.** Applies only while services are `disabled` (no ads, no purchases, no remote analytics). Machine-checked by `tests/services/test_services_listing.gd` group `data_safety_draft`, which fails if the Android export enables INTERNET or if the default services build reports anything live, because then these answers are wrong.

## 1. Sources (checked 2026-10-31)
| Fact (paraphrased) | Source |
|---|---|
| All apps on closed, open or production tracks must complete the form, even if they collect nothing, and must link a privacy policy; internal-testing-only apps are exempt | https://support.google.com/googleplay/android-developer/answer/10787469?hl=en |
| Data accessed only on the device and never sent off it does not have to be declared as collected | same |
| "Sharing" means transferring user data to a third party (off-device, or on-device to another app); SDK data counts as the app's | same |
| Data type categories: Location, Personal info, Financial info, Health and fitness, Messages, Photos and videos, Audio files, Files and docs, Calendar, Contacts, App activity, Web browsing, App info and performance, Device or other IDs | same |
| Purposes include: App functionality, Analytics, Developer communications, Advertising or marketing, Fraud prevention/security/compliance, Personalization (list as fetched; the page may list more) | same |
| Google Mobile Ads SDK collects and shares IP address, product interactions, diagnostics and device IDs; TLS in transit | https://developers.google.com/admob/android/privacy/play-data-disclosure |
Content was rephrased for compliance with licensing restrictions.

## 2. Evidence for "no data collected or shared" (current build)
| Check | Result | How |
|---|---|---|
| Android permissions in the built APK | **none requested** | `aapt dump permissions build/qa/apk_head/defence-debug.apk` (APK built 2026-10-31 09:03, 56.4 MB) printed only the package line; `aapt dump badging`: sdkVersion 24, targetSdkVersion 36 |
| INTERNET permission in export preset | `permissions/internet=false` | export_presets.cfg:65 (read-only; 02/04 file) |
| Network code in src/ | none found (HTTPRequest, WebSocket, ENet, StreamPeerTCP, OS.shell_open) | text search over src/**/*.gd, 2026-10-31 |
| Services mode | `disabled`; live flags real_ads/real_billing/trusted_verifier/remote_analytics all false | test_services_integration.gd D1 |
| Analytics sink | null sink, nothing leaves the device | ANALYTICS_EVENTS.md §4, D1 |
| Save data | progress stays in app-private storage (`user://save.json`) | INTERFACES.md §3 |
Caveat: the debug APK is not the release AAB. The release bundle's merged manifest must be re-checked with the same command before submission (04). Android vitals / crash data that Google Play collects at the OS level is Google's, not the app's.

## 2a. Confirmation against 04's APK check (2026-10-31)
| Check | 04 result (docs/qa/RELEASE_READINESS.md) | 06 re-check | Agree |
|---|---|---|---|
| Permissions | A7 TESTED: `aapt2 dump permissions` → none | `aapt2 dump permissions build/qa/apk_head/defence-debug.apk` → package line only, no `uses-permission` | Yes |
| INTERNET | A7: no INTERNET | none in APK; export_presets.cfg:65 `permissions/internet=false` at HEAD 8ad912f | Yes |
| Data leaving the device | C1 TESTED (static): no INTERNET, no SDKs → nothing leaves the device | Android's INTERNET permission is what allows opening network sockets (https://developer.android.com/reference/android/Manifest.permission#INTERNET), so without it the app cannot send data itself | Yes |
| Build identity | debug APK from isolated HEAD copy 07e97ca, 59,106,028 B, minSdk 24 / target 36 | same file, SHA-256 `09AF2E47989F147970B00E27DD4D9D3843EBD13060744B5119EFC19F5C70A6DE`; native libs arm64-v8a + x86_64; uses-feature faketouch only | Yes |
| Changes since 07e97ca that could add permissions or data flows | — | `git diff 07e97ca HEAD -- export_presets.cfg addons android project.godot`: include_filter now also packs `assets/fonts/*.txt, *.json`; project.godot adds the `Services` autoload (disabled mode, no network code). No plugin, no permission, no `addons/` | No change to the answer |
**Decision for the disabled build: "No data collected or shared" is CONFIRMED** for the build above and for HEAD 8ad912f by static analysis. Conditions that void it: any `permissions/*=true`, any plugin in `addons/` or an Android plugin AAR, services mode other than `disabled`, or remote analytics. Before submission, 04 must re-run the same aapt2 commands on the **release AAB** (a debug APK is not what Play receives) and record the hash here. A privacy-policy link that opens the browser (Godot `OS.shell_open`) is expected not to add permissions; 04 confirms with aapt2 after adding it.
Side finding (04 A6): `assets/fonts/OFL-Galmuri.txt` is not inside this APK (only `fonts_provenance.json` is); 02's include_filter fix came later (141d226) and needs a new APK to verify. Not a Data safety issue, but a licence one (IN_APP_LEGAL_DISPLAY.md).
## 2b. Re-check against the Android backup policy (2026-10-31)
Current build: `allowBackup=false`, no `dataExtractionRules`/`fullBackupContent`, `hasFragileUserData=false` (SAVE_BACKUP_POLICY.md §1). The "No" answer and the deletion answer below **hold**: the app never sends the save anywhere; a device-to-device transfer that some phone makers still run (S5) is a user-initiated system transfer the developer never receives. If save backup is turned on later (option B1), 06 expects "No" to stay (the copy goes to the user's own Google backup; compare the Data safety FAQ on user uploads to their own Drive), but the deletion row and the privacy policy `[백업 활성화 시]` sentence change. Full table: SAVE_BACKUP_POLICY.md §5. Not verified on a device.
## 2c. Each draft answer tied to code evidence (HEAD f41fd12, 2026-10-31 ~19:05 KST; Q2 deferred; not submitted)
`git grep` runs over tracked `src/**/*.gd` and `scenes/**/*.tscn`, comment-only lines excluded. Commands are listed so anyone can rerun them.
| Form item | Draft answer | Evidence (rerunnable) | Result |
|---|---|---|---|
| Network use by the app | none | `git grep -nE "HTTPRequest|HTTPClient|StreamPeerTCP|StreamPeerTLS|WebSocketPeer|PacketPeerUDP|ENetMultiplayerPeer|TCPServer|UDPServer|OS\.shell_open" -- "src/*.gd" "scenes/*.tscn"` | **0 hits** |
| Network permission | none | export_presets.cfg `permissions/internet=false`, `access_network_state=false`; APK `aapt2 dump permissions` lists none; lint `android_permissions` | 0 permissions |
| Third-party SDKs / plugins | none | `git grep -nE "Engine\.get_singleton|JavaClassWrapper|JNISingleton|GDExtension"` → **0 hits**; no `addons/`; no `android/plugins`; no enabled `plugins/*` (lint `q2_repo_scan`) | none |
| Ads, billing, receipts | none | lint `q2_repo_scan`: 0 `Services.ads`/`Services.purchases`/AdMob/billing/receipt calls outside src/services; services run in `disabled` mode (`service_diagnostics` live = all false) | none |
| Device or other IDs (incl. advertising ID) | not collected | `git grep -nE "get_unique_id|advertising|AD_ID|ANDROID_ID|get_model_name|IP\.get_local"` → **0 hits**; no AD_ID permission (lint) | 0 |
| App info and performance (crash logs, diagnostics) | not collected | `git grep -nE "OS\.alert|Logger|FileAccess\.open\(.*log"` → **0 hits**. Godot's own file log, if enabled, stays in `user://logs` on the device; no code sends it. Android vitals data is Google's, not ours | 0 |
| App activity / analytics | not collected | analytics sink is `null` by default (lint `data_safety_draft`); no remote endpoint | 0 |
| On-device game progress | not "collected" (never leaves the device) | `user://save.json` in app-private storage; `allowBackup=false` (SAVE_BACKUP_POLICY.md §1) | stays on device |
| Encrypted in transit | not applicable | nothing transmitted (rows above) | — |
| Deletion | uninstall or clear app data | §2b; privacy draft §4 | — |
Limits: grep finds only code that is in the repo. A future plugin, SDK or Gradle dependency must be re-checked on the release AAB's merged manifest and libraries; none exists yet (§5 of PLAY_TECH_REQUIREMENTS.md: no AAB). This is a draft for the user. It is not submitted and not published.
## 3. Draft answers (disabled mode)
| Form section | Draft answer | Note |
|---|---|---|
| Does the app collect or share any of the required user data types? | **No** | §2 evidence |
| Data types collected (all 14 categories: Location, Personal info, Financial info, Health and fitness, Messages, Photos and videos, Audio files, Files and docs, Calendar, Contacts, App activity, Web browsing, App info and performance, Device or other IDs) | None | On-device progress is not "collected" (never leaves the device) |
| Data shared with third parties | None | No SDKs |
| Encrypted in transit | Not applicable (nothing transmitted) | Form only asks when data is collected |
| Users can request data deletion | Not applicable; on-device data is removed by uninstalling or clearing app data | State this in the privacy policy §4/§5 |
| Privacy policy URL | `{{PRIVACY_POLICY_URL}}` (required even with "No") | user supplies hosting (OPEN_DECISIONS.md U3); text: PRIVACY_POLICY_DRAFT.md |
| Independent security review | Not planned | optional |

## 4. What changes when features are turned on
| Feature | Data types to add (purpose) | Shared? | Other answers |
|---|---|---|---|
| Rewarded ads (Google Mobile Ads SDK) | Location: approximate (IP address; mapping is a 06 judgement, confirm); App activity: app interactions; App info and performance: diagnostics; Device or other IDs: advertising ID (Advertising or marketing, Analytics, Fraud prevention) | Yes, with the ad network | Encrypted in transit: Yes (SDK uses TLS); data collection optional: per SDK/consent; re-read the SDK page for the exact version used |
| In-app purchases (Play Billing, client only) | Financial info: purchase history (App functionality) if the app stores or sends purchase records off-device; Play handles payment details | Only if sent to our verification server or a vendor | Payment info itself is handled by Google Play |
| Verification server | Financial info: purchase history; possibly Device or other IDs if an account/obfuscated ID is used | Server is ours (not "sharing" unless a vendor) | Encrypted in transit: Yes required; retention period in privacy policy |
| Remote analytics (event contract in ANALYTICS_EVENTS.md) | App activity: other actions (gameplay); App info and performance: diagnostics/crash logs (Analytics) | Only if a vendor | Consent-gated already in code; session id not persisted |
| Accounts / cloud save | Personal info (email or user IDs), plus account deletion requirement | — | V4 in RELEASE_READINESS_SERVICES.md |
Each change also requires: privacy policy update (PRIVACY_POLICY_DRAFT.md markers), content rating / ads declaration update (CONTENT_RATING_DRAFT.md §3), and a new aapt permission check.
