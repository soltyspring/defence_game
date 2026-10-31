# Purchases without a verification server: minimum bar and risks (owner: 06-services)
Version: 1 (2026-10-31). Status: **analysis for the user decision U6 (option C), not a decision.** Today the code makes this impossible on purpose: `unavailable_receipt_verifier.gd` answers `verification_unavailable` for every real purchase, so nothing is granted and Play auto-refunds. Enabling client-side purchases needs an explicit user choice through 01 and a new verifier adapter.

Google's position (paraphrased, checked 2026-10-31): verify purchases on a secure backend before granting, keep all purchase tokens, use the Developer API; client-side acknowledge/consume is possible but server-side gives more protection (https://developer.android.com/google/play/billing/security). A purchase carries a signature over its JSON made with the developer's key using RSASSA-PKCS1-v1_5 (https://developer.android.com/reference/com/android/billingclient/api/Purchase). Content was rephrased for compliance with licensing restrictions.

## 1. When client-only purchases are acceptable for this game
All must hold. If one fails, keep purchases off or add a server.
| ID | Condition | Why | Current state |
|---|---|---|---|
| M1 | Single-player and offline: no trading, no leaderboards with purchased advantages, no shared economy | A cheater only affects their own game | True today (no network code) |
| M2 | Nothing required to finish chapter 1 can be bought (ECONOMY.md design constraint) | Purchases are convenience/support, so bypassing them has low impact | Design intent, untested (A4) |
| M3 | Low-value products only: one "supporter / remove ads" non-consumable and, at most, small consumables | Limits loss from fraud and refunds | No catalog yet |
| M4 | No paid random items (gacha) | Korean probability-disclosure law and higher fraud/legal stakes | Not in design |
| M5 | Prices come from Play product details, never hard-coded | Regional pricing and tax | Not built |
| M6 | The store text and privacy policy say purchases are verified on the device only | Honesty; Data safety consistency | Templates have markers |

## 2. Minimum implementation (each item already exists unless marked)
| ID | Requirement | Where / evidence |
|---|---|---|
| R1 | Grant only state PURCHASED; never PENDING or unknown states | purchase_service.gd; test_services_m3 `billing_transitions` |
| R2 | One grant per purchase token (ledger keyed by token hash), persisted with the reward in one atomic save | purchase_service.gd + save_bridge.gd; integration gate P1 (binding=game) |
| R3 | Acknowledge/consume only after the grant is persisted; a failed grant is left unacknowledged so Play refunds it | purchase_service.gd; test_services `purchase_consumable` |
| R4 | Query owned purchases on launch and on resume | services.gd `reconcile()`; test_services_m8 |
| R5 | Restore button; offline restore never revokes | purchase_service.gd; test_services `purchase_restore` |
| R6 | Non-consumable revoked when a successful query no longer lists it (refund) | test_services `purchase_restore` |
| R7 | **Missing:** a `client_side_verifier.gd` adapter that answers `ok` only for state PURCHASED + package name match + product in catalog (+ optional signature check, §3). Must be labelled `kind() = "client_side"` and diagnostics `trusted_verifier=false` | not written (needs U6 = C) |
| R8 | **Missing:** quantity handling or multi-quantity kept off in Play Console | BILLING_PLUGIN_CANDIDATES.md §3 |
| R9 | **Missing:** user-facing text: purchase received message (B8), "purchases are tied to your Google account; restore via Restore", "coin balances are stored on this device only" | 04 / 01 |

## 3. Optional on-device signature check
The Play purchase JSON is signed (RSASSA-PKCS1-v1_5). The app could verify it with the Base64 public licence key from Play Console. Godot's Crypto class has RSA verify, but its exact padding behaviour and whether the chosen plugin exposes the signed JSON and signature are **not verified** (BILLING_PLUGIN_CANDIDATES.md §2). Effect: stops simple fake-purchase injectors that return unsigned data. It does **not** stop a modded APK that removes the check. The public key is not a secret, but keep it in export config rather than source so the static guard stays clean.

## 4. Risks without a server
| Risk | Likelihood (judgement) | Impact here | Mitigation without a server | Residual |
|---|---|---|---|---|
| Modded APK grants items without paying | Medium for any popular Android game | Only that player's offline game | M1–M3; optional §3 check | Accepted if M1–M3 hold |
| Fake-purchase / billing-emulator apps | Medium on rooted devices | Same as above | §3 signature check; grant only via real Play flow | Low–medium |
| Refund after consumable was consumed | Low–medium | Player keeps coins; we lose the sale | Small consumables only (M3); Voided Purchases API needs a server | Accepted loss |
| Refund of non-consumable while offline | Low | Entitlement kept until next online launch | R6 revokes on next successful query | Small window |
| Chargeback abuse | Low | Same as refund | Same | Accepted |
| Lost/cleared local save | Medium | Non-consumables restorable from Play; consumable balances lost | R5; tell players balances are device-only (R9) | Player-facing loss for consumables; prefer non-consumables |
| Grant persisted but acknowledge never succeeds within 3 days | Low | Player gets item, Play refunds payment | R3 ack retry on each reconcile | Accepted (free item, no charge) |
| Account sharing / family devices | Low | One purchase used on several devices of the same account | Play allows this for the same account | Accepted |
| Policy / review: Play asks for evidence of correct handling | Low | Delays | Sandbox plan T1–T16 evidence | — |

## 5. What a minimal server would add
Purchase verification via the Developer API, a global token ledger, Voided Purchases / RTDN handling (refunds, chargebacks), server-side acknowledge/consume, and protection against modded clients for consumables. Cost: hosting, a service account kept only on the server, and maintenance (user decision, U6 option B).

## 6. 06 recommendation (not a decision)
If the user wants purchases at launch without a server: option C restricted to **one non-consumable** (supporter / remove ads) with R1–R9 done, the §3 check if the plugin exposes signatures, and no consumables. Add consumables only together with a server.
