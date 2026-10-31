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
