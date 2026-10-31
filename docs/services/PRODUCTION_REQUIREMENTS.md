# Production requirements for real ads, billing and analytics (owner: 06-services)
Date: 2026-10-31. Status: REQUIREMENTS ONLY. **Superseded for policy facts by RELEASE_READINESS_SERVICES.md (official URLs re-checked 2026-10-31, incl. Play Billing v9.1.0 and API 36); user decisions in OPEN_DECISIONS.md.** None of this is installed, configured or verified.
Nothing below may be started until the user approves the business model and specific products/placements through 01 (ECONOMY.md Q2–Q5). Paid services and store accounts are separate user actions.

## 1. Rewarded ads (only if Q2 = M2 or hybrid and Q3 approves placements)
| Item | Requirement | Owner | State |
|---|---|---|---|
| Ad network | User choice. Default candidate: Google AdMob (Google Mobile Ads SDK) | user via 01 | not chosen |
| Godot plugin | A maintained Godot 4.7-compatible Android plugin. Candidates found 2026-10-31: [Poing Studios AdMob plugin](https://github.com/poing-studios/godot-admob-plugin) (includes UMP consent), [godot-sdk-integrations/godot-admob](https://github.com/godot-sdk-integrations/godot-admob). Must be re-evaluated (licence, Godot version, SDK version) at integration time | 04 installs/exports, 06 writes adapter | not installed |
| Account + IDs | AdMob account, app ID, rewarded ad unit IDs. App ID goes in the Android manifest via export config, never in src/ | user creates; 04 configures | none |
| Test ads | Google test ad units and registered test devices during development. Clicking own live ads is a policy violation | 04/06 | n/a |
| Consent | Google UMP (or certified CMP) for EEA/UK/Switzerland; Korean privacy notice; withdraw option in settings | 04 UI, 06 adapter → `consent.apply_external()` | not built |
| Audience | If child-directed (Q5): Families policy, only Families-certified ad SDKs, no personalised ads | user via 01 | Q5 not asked |
| Server-side verification (SSV) | Optional AdMob rewarded SSV callback to our own server for anti-tamper. Needs a server. Not needed for an offline, low-value reward | user decision | not planned |
| Permissions | INTERNET (+ AD_ID permission declaration for Android 13+ if the SDK uses the advertising ID) | 04 export | currently off |
| Production adapter | `src/services/ads/admob_ad_provider.gd` mapping plugin signals to `ad_provider.gd` | 06 | not written |
| Evidence before claiming "ads work" | Real device, test ad units: load, show, reward, cancel, no-fill, airplane mode, background during ad, consent denied | 06 + 07 | none |

## 2. In-app purchases (only if Q2 includes IAP and Q4 approves a catalog)
| Item | Requirement | Owner | State |
|---|---|---|---|
| Play Console | Developer account, app created, merchant profile, products created with IDs matching `data/meta.json` | user | none |
| Billing library | Play Billing Library 8 or newer. Google's deprecation page states new apps/updates must use v8+ from 2026-08-31 ([deprecation FAQ](https://developer.android.com/google/play/billing/deprecation-faq)). Restore uses querying owned purchases | 04 plugin choice | not installed |
| Godot plugin | Candidates: [godot-sdk-integrations/godot-google-play-billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) (official org), [AndroidIAPP](https://github.com/code-with-max/godot-google-play-iapp) (states Billing 8). Verify the bundled billing version ≥ 8 at integration | 04 | not installed |
| Production adapter | `src/services/billing/play_billing_provider.gd` mapping plugin callbacks to `billing_provider.gd` (incl. pending, already owned, unsolicited updates on app start) | 06 | not written |
| Verification server | HTTPS endpoint that receives `{product_id, token}` and calls the Google Play Developer API (purchases.products.get) with a **service account held only on the server**; returns ok / invalid / revoked. Optionally Real-time developer notifications (Pub/Sub) for refunds | user chooses hosting (cost); server code is a separate task | does not exist |
| Secrets | Service-account JSON: server only, never in the app or repo. App licence public key: not secret but kept in export config. No credentials in source, logs or commits | user/04 | none |
| Fallback if no server | Option A (recommended): keep IAP off. Option B: client-side signature check of Play signed data with the app public key, labelled "client-side verification, tamperable", and accepted only for low-value non-consumables. Requires explicit user decision | user via 01 | not chosen |
| Acknowledgement | Acknowledge non-consumables / consume consumables only after verified grant; unacknowledged purchases are auto-refunded by Play after the window | 06 (implemented in state machine) | mock-tested only |
| Refunds | Restore revokes entitlements the store no longer reports; a server with voided-purchase checks is stronger | 06 | mock-tested only |
| Testing | Licence testers, test cards, internal testing track, purchase on a real device; test pending payments, cancel, refund, reinstall + restore, second device | 04/06/07 | none |
| Legal | Korean e-commerce/refund notice text, price display incl. VAT, Play payments policy. Korean probability disclosure only if paid random items (M3, not recommended) | user/01 | n/a |

## 3. iOS (documented only)
StoreKit 2 via a Godot iOS plugin, App Store Connect products, App Store Server API for verification (server-held key), ATT prompt only if tracking. Same service interfaces; new adapters. Not planned before Android.

## 4. Analytics
| Item | Requirement | State |
|---|---|---|
| Decision | Remote analytics at all? Vendor (e.g. Firebase) or own endpoint? | not asked; recommendation: none at launch |
| Contract | docs/services/ANALYTICS_EVENTS.md (allow-list, no IDs) | draft done |
| Sink | Remote sink adapter + HTTPS endpoint + retention policy | not written |
| Disclosure | Privacy policy URL, Play Data safety form (app activity / diagnostics), consent | 04 / user |

## 5. Release configuration boundary
- Source contains no app IDs, ad unit IDs, product prices, licence keys, server URLs or credentials. Static test `static_guards` fails on `ca-app-pub-`, private keys, URLs and device-ID APIs in src/services.
- Production values come from export-time configuration owned by 04 (e.g. `export_credentials.cfg` or environment variables, git-ignored) and are handed to `Services.setup()` by 02 at boot. Mode `production` stays unavailable until real adapters exist.
- Debug-only mock mode is refused in release builds.

## 6. Gate to say "ads/billing are live"
All rows in §1/§2 for the chosen model show real device evidence (logs, screenshots, sandbox order IDs redacted), 07 has re-run them, and the user has approved going live. Until then, report: "service boundaries and mock-tested state machines exist; real ads/billing are not integrated".
