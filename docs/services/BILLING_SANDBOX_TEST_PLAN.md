# Real purchase verification with license testers and the internal test track (owner: 06-services)
Version: 1 (2026-10-31). Status: **PLAN ONLY. Nothing here has been run.** It can only be run after the user approves purchases (OPEN_DECISIONS.md U1, U6), owns a Play developer account, and a billing adapter exists (BILLING_PLUGIN_CANDIDATES.md). No real money is charged when steps are followed exactly with license testers.

Legend: **[USER]** = only the account owner can do it (Play Console, accounts, money, legal). **[04]** = build/export owner. **[06]** = services owner. **[07]** = QA records evidence.

## 1. Sources (checked 2026-10-31; paraphrased)
| Fact | Source |
|---|---|
| License testers are set in Play Console → Settings → License testing (email lists up to 2,000 addresses, or Google Groups). The publishing account is always a license tester. One-time products must be published before they can be tested | https://support.google.com/googleplay/android-developer/answer/6062777?hl=en |
| License testers bypass the "app must be uploaded to Play" check, so a sideloaded debug build works if the package name matches the Play app; they get test payment methods that charge no money; a notice is shown in the purchase dialog; the purchase uses the account that downloaded the app | https://developer.android.com/google/play/billing/test |
| Test instruments: always approves, always declines, slow card that approves / declines after a few minutes, approves then charges back. Unacknowledged license-tester purchases are refunded after **3 minutes** (production: 3 days), with an email; check the Orders tab | same page |
| Internal test track: up to 100 testers by email list; new bundles reach testers within minutes; internal testers still pay for in-app purchases unless they are also license testers; internal-test purchases are subject to spend limits; first upload fixes the package name | https://support.google.com/googleplay/android-developer/answer/9845334?hl=en |
| Selling requires a payments profile (legal business name, physical address, contact, support email, card statement name; bank account in the same country) | https://support.google.com/googleplay/android-developer/answer/7161426?hl=en |
| Query purchases after connecting (launch and foreground) so out-of-app and completed pending purchases are processed | https://developer.android.com/google/play/billing/integrate |
Content was rephrased for compliance with licensing restrictions.

## 2. One-time setup
| # | Owner | Step | Done when |
|---|---|---|---|
| S1 | **[USER]** | Create a Play developer account (personal or organisation, OPEN_DECISIONS.md U2) and complete identity verification | Play Console opens the app list |
| S2 | **[USER]** | Create the payments profile (business name, address, support email, statement name, bank account) | Monetization settings show a linked payments profile |
| S3 | **[USER]** | Create the app in Play Console with package `com.soltyspring.lanedefence` (export_presets.cfg) — **the first upload fixes the package name** | App exists |
| S4 | **[USER]** | Add license testers: Settings → License testing → email list (own Gmail accounts that will run tests) | List saved |
| S5 | **[USER]** | Create the internal testing track and add the same accounts as internal testers; share the opt-in link; each tester opts in | Testers see the app in Play |
| S6 | **[USER]** + 01 | Create and publish the one-time products whose IDs match `data/meta.json` `iap_catalog.products`; keep **multi-quantity off** (BILLING_PLUGIN_CANDIDATES.md §3 gap) | Products listed as active |
| S7 | **[04]** | Enable Gradle build, install the chosen plugin, add BILLING permission if needed, build a signed AAB with a version code higher than the last upload | AAB builds; merged manifest has `com.android.vending.BILLING` and `com.google.android.play.billingclient.version` |
| S8 | **[06]** | Write `play_billing_provider.gd`, set services mode for this test build (a test-only config; production mode is still unimplemented today), keep the mock verifier unreachable | Services diagnostics show `adapters.billing = production` on the test build |
| S9 | **[USER]** | Upload the AAB to the internal track and roll out | Testers receive the update |
| S10 | **[07]** | On each test phone: install from the internal track (or sideload the same package with a license-tester account), sign in with the license-tester account only | Purchase dialog shows the test notice |
Signing keys and passwords stay outside the repo (ENGINE.md §3, GIT_WORKFLOW).

## 3. Test cases
Each case: run on a real phone, record order ID (redacted), screenshot of the Play dialog, `Services.diagnostics()` before/after, and the save file's `services.iap` section. "Expected service result" uses our result codes (src/services/service_result.gd).

| ID | Scenario | Steps | Expected service result | Expected Play / Console | Maps to |
|---|---|---|---|---|---|
| T1 | Non-consumable approved | Buy `remove_ads`-type product with "Test card, always approves" | `purchase_finished(ok)`, `entitlement_changed(true)`, acknowledged | Order not refunded after 3 min | B2, B3 |
| T2 | Declined | Buy with "always declines" | `error` or `cancelled`; no ledger entry | No order or failed order | B2 |
| T3 | User cancels the sheet | Open purchase, press back | `cancelled`; no ledger entry | — | — |
| T4 | Slow card approves | Buy with "Slow test card, approves after a few minutes"; leave app open | `pending` first, later granted once via unsolicited update | Order completes | B2, P-pending |
| T5 | Slow card approves while app closed | Same as T4 but close the app before approval; reopen after 5 min | `restore_finished` with `auto=true`, `code=ok`, `restored=1`; `entitlement_changed(true)` once | — | R09-06-2.1, M8 |
| T6 | Slow card declines | "Slow test card, declines after a few minutes"; restart app after decline | `pending`, then nothing granted; `availability()` = `ok` again after restart | Cancelled order | P4 |
| T7 | Ack failure safety | Temporarily block the acknowledge call in a test build; buy; wait 3 min | `purchase_finished(ok)` but ack missing; after Play refunds, next reconcile `restore_finished.revoked=1`, `entitlement_changed(false)` | Refund email, Orders tab shows refund | B3, B6 |
| T8 | Consumable | Buy the consumable 3 times | `consumable_granted` ×3 and `purchase_finished(ok)` ×3, each consumed once; save `coins` +3×grant | 3 orders | B3 |
| T9 | Crash after payment | Buy consumable, kill the app from recents immediately after the Play success screen; reopen | launch `restore_finished` (`auto=true`, `restored=1`), `consumable_granted` once; later launches `already` | Not refunded | R4/P1, R09-06-2.1 |
| T10 | Reinstall restore | Buy non-consumable, uninstall, reinstall, press nothing | launch `restore_finished` (`auto=true`, `restored=1`); manual `restore()` → `ok` with `already=1` | — | P3, R09-06-1 |
| T11 | Second device | Same account on a second phone | `restore_finished` `ok`, `restored=1`; diagnostics `ack_elsewhere` +1, no acknowledge call | — | P5 |
| T12 | Refund | Refund the T1 order in Play Console (Orders → Refund) | On next launch/resume with network: entitlement revoked (`entitlement_changed(false)`); offline: kept | Refunded order | B6, B7 |
| T13 | Chargeback | "Test card, approves then charges back" | next reconcile `restore_finished.revoked=1` once Play stops reporting ownership; PendingRefundReview notification needs a server (not available) | Chargeback notice | B6 |
| T14 | Offline | Airplane mode, open shop, try buy and restore | `offline` (or SDK error mapped to `offline`), no crash, no grant, entitlements kept | — | — |
| T15 | Play Store blocked/unavailable | Device where the system blocks the Play Store (e.g. OEM kids mode), or Play Store disabled | `unsupported`/`error`, no crash; Billing 9.0.0 release notes say the blocked case now reports BILLING_UNAVAILABLE | — | B1 note |
| T16 | Disabled build regression | Install the normal (disabled) release build | `purchase()` / `restore()` / `reconcile()` → `disabled`; diagnostics `live.real_billing=false` | — | D1–D6 |
Pass rule: every case passes on at least 2 phones (one Android 13+, one older supported version), evidence attached by 07. A failed case blocks enabling purchases.

## 4. What these tests cannot show
- Fraud resistance: license testers and test cards say nothing about modded clients or fake-purchase apps (NO_SERVER_MINIMUM.md).
- Production auto-refund timing (3 days) is shortened to 3 minutes for testers.
- Real payment methods, taxes and regional prices (taxes are not computed for test purchases).
