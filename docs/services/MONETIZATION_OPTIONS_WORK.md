# Q2 business model options: extra 06 work and test scope (owner: 06-services, for 01)
Version: 1 (2026-10-31). Status: **input for 01's Q2 question, not a decision.** Monetization stays disabled (D9). Options as named by the reviewer: A rewarded ads + "remove ads" purchase, B paid app, C chapter purchases. Effort is a relative 06 estimate (S/M/L), not a schedule. Work owned by other roles is listed so 01 sees the whole cost, but only 06 items are 06's.

## 1. Comparison
| Item | A: rewarded ads + remove-ads purchase | B: paid app (upfront price) | C: chapter purchases (non-consumable unlocks) |
|---|---|---|---|
| New 06 code | ad SDK adapter (`admob_ad_provider.gd`), UMP/CMP consent adapter for consent_flow.gd, Play Billing adapter, verifier per U6, grant sinks wiring with 02 (S3) | none required; services stay `disabled` | Play Billing adapter, verifier per U6, chapter entitlement query API for 02 (`has_entitlement("chapter_2")`) |
| Existing 06 code reused | rewarded_ad_service, reward_policy, consent, telemetry, purchase_service (non-consumable), reconcile on launch/resume | — | purchase_service (non-consumables), restore/reconcile, ledger, state table P3/P5 |
| Open design decisions (01) | DD1 late reward; what "remove ads" removes when every ad is opt-in rewarded (09 R09-06-1 guardrail: entitlement must suppress all forced ads, but the design has none; e.g. auto-grant rewards without watching, or supporter perk); placements and caps | price; refund window (Play lets users return a paid app within 2 hours, https://support.google.com/googleplay/android-developer/answer/2741495?hl=en) | chapter content and price; what chapter 1 contains for free (design constraint: no purchase needed to finish chapter 1); chapter 2 does not exist yet |
| User prerequisites (U-list) | U1, U2, U3, U4 (children → Families-certified SDK), U5 (ad network, EEA), U6, payments profile, AdMob account | U1, U2, U3, payments profile | U1, U2, U3, U6, payments profile |
| Permissions / export (04/02) | INTERNET, AD_ID (merged by SDK), Gradle build, two plugins | none added | Gradle build, billing plugin (BILLING permission) |
| Data safety (06 drafts) | Changes to "Yes": approximate location (IP), app interactions, diagnostics, device IDs shared with the ad network (DATA_SAFETY_DRAFT.md §4) | Stays "No" | Stays "No" if client-only (purchase data handled by Google Play); "Yes" for purchase history if a verification server is used |
| Privacy policy | `[광고 활성화 시]` + `[결제 활성화 시]` blocks | unchanged template | `[결제 활성화 시]` blocks |
| Content rating / declarations | "Contains ads" = Yes; In-game purchases; ad content rating cap | none | In-game purchases |
| Consent UI (04) | required for EEA/UK/CH (certified CMP) + privacy options entry | none | none (unless analytics added) |
| Main risks | policy (rewarded ads, Families), consent, ad-fill dead ends (handled: no-fill cooldown), SDK data disclosure, reward-delivery complaints (09 R09-06-1) | lower install volume; piracy of the APK (no in-app check) | chapter content bundled in the APK can be unlocked by modding (NO_SERVER_MINIMUM.md); needs real chapter 2 content before launch |
| 06 effort | L | S | M |

## 2. Test scope per option (beyond the current 7 suites, which must stay at OVERALL exit 0)
| Test area | A | B | C |
|---|---|---|---|
| Headless contract tests (mock) | extend ads + consent suites for the real adapter's callback mapping; remove-ads entitlement effect; DD1 behaviour | disabled-mode regression only (D1–D6 already in the gate) | chapter gating API, entitlement survives save migration and `.bak` recovery, restore/reconcile for several chapters |
| Integration gate rows | R1–R16 with game grant sinks (`I5` must become PASS), P1–P7 subset for the non-consumable | unchanged | P3, P5, P6 + new rows for chapter unlock/revoke |
| Real device, Play sandbox (BILLING_SANDBOX_TEST_PLAN.md) | T1–T3, T5, T7, T10–T14, T16 for the non-consumable | not needed (no billing); install from internal track + paid-app purchase by a license tester | T1–T3, T5–T7, T10–T14, T16 |
| Real device, ads | AdMob test ad units: load, show, reward, cancel, no-fill, offline, app backgrounded during ad, consent required/denied (UMP debug geography EEA), child/unknown age path | — | — |
| Store/policy docs | listing monetization lines, Data safety "Yes" answers, rating "Contains ads", privacy blocks | listing text; no price or promotion wording in title, icon or developer name (Metadata policy) | listing "chapter 2 sold separately" wording, privacy blocks |
| Approx. new automated checks | large (two adapters + consent) | none | medium |

## 3. 06 observations (not a recommendation of a model)
- B needs almost no further 06 work and keeps "no data collected"; it does not use any of the ad/billing code built so far.
- C reuses the purchase code with the least new surface (no ads SDK, no consent UI), but depends on chapter 2 content existing.
- A uses everything built so far but adds the most policy, privacy and consent work, and one open design contradiction ("remove ads" with opt-in-only ads).
Whichever is chosen, 01 asks the user one question at a time (OPEN_DECISIONS.md U1 first).
