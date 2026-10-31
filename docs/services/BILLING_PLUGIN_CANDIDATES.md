# Google Play Billing plugin candidates for Godot 4.7 (owner: 06-services)
Version: 1. Checked **2026-10-31** from the official repositories, release pages and GitHub API. **Nothing is installed.** No plugin, AAR, Gradle change or key was added to the project. Installing is a later step after the user approves purchases (OPEN_DECISIONS.md U1/U6), and the export change is 04/02's (Gradle build is currently off: export_presets.cfg:25).

Requirement B1 (RELEASE_READINESS_SERVICES.md): new apps and updates must use a supported Play Billing Library. v7 stopped being accepted for new apps/updates on 2026-08-31; v8 is accepted until 2027-08-31, v9 until 2028-08-31 (https://developer.android.com/google/play/billing/deprecation-faq).

## 1. Candidates
| ID | Plugin | Latest release (date) | Billing Library | Meets B1 (≥ v8) | Godot support stated | License | Source |
|---|---|---|---|---|---|---|---|
| P-A | GodotGooglePlayBilling (godot-sdk-integrations; linked from the Godot docs page "Android in-app purchases" as the first-party plugin) | 3.3.0 (2026-07-27) | 9.1.0 (release notes: "Bump to Billing Library v9.1.0"); previous 3.2.0 used 8.3.0 | YES | 4.2 and above (3.x line) | MIT | https://github.com/godot-sdk-integrations/godot-google-play-billing/releases ; https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html |
| P-B | AndroidIAPP (code-with-max/godot-google-play-iapp) | v2.2 (2026-09-28) | 9.1.0 (release text: "Godot 4.7.2 plugin for Google Play Billing 9.1.0") | YES | 4.7+ per repo description; README compatibility section says 4.3 or newer | MIT | https://github.com/code-with-max/godot-google-play-iapp ; https://api.github.com/repos/code-with-max/godot-google-play-iapp/releases/latest |

Repository facts from the GitHub API (2026-10-31): P-A last push 2026-09-25, not archived, 267 stars, 3 open issues; P-B last push 2026-09-28, not archived, 81 stars, 9 open issues. Stars are popularity, not quality.

## 2. What each needs (from their docs)
| Need | P-A | P-B |
|---|---|---|
| Android Gradle (custom) build | Yes ("Enable Gradle Build for Android Export") | Yes ("Use Custom Build enabled") |
| Plugin enabled in Project Settings → Plugins | Yes | Yes; also requires Godot's built-in Play Billing plugin to be disabled |
| BILLING permission in export preset | Not stated on the pages read | Yes ("Billing permission enabled") |
| API shape | `BillingClient.new()`; signals `connected`, `query_purchases_response`, `on_purchase_updated`, `consume_purchase_response`, `acknowledge_purchase_response` | `GooglePlayBilling` node; signals `iap_purchases_updated`, `iap_purchases_queried`, `iap_consumed_success`, `iap_acknowledged_success`, `iap_error_occurred` |
| Pending purchases | Purchase dictionaries carry state (docs) | README: do not grant PENDING; check `purchase_state` |
| Signature / original JSON exposed to GDScript | **Not verified** (needed only for client-side signature checks, NO_SERVER_MINIMUM.md §3) | **Not verified** (README lists `purchase_token`, `products`, `purchase_state`, `is_acknowledged`) |
| Testing note | — | Billing may not work when launched from the editor; use a Play testing track build |

## 3. Fit with our service boundary
Both map onto `src/services/billing/billing_provider.gd` signals (`purchase_updated`, `owned_queried`, `acknowledged`, `consumed`). A real adapter (`play_billing_provider.gd`, not written) must:
- start the connection, then call the owned-purchases query on connect and on app resume (our `reconcile()` already asks for this);
- map purchase state PURCHASED/PENDING/other to `purchased`/`pending`/`unspecified` (other states are never granted, tested in test_services_m3 `billing_transitions`);
- pass `quantity` through. **Fixed 2026-10-31 (M10, mock level):** `purchase_service.gd` grants catalog grant × quantity once per token, records the quantity in the ledger and consumes once; quantities above the product's `max_quantity` (data/meta.json, default 1) or invalid values are not granted and not consumed (tests/services/test_services_m10.gd). Enable multi-quantity in Play Console only for products whose `max_quantity` matches the Console limit (Play docs: multi-quantity is opt-in per product, https://developer.android.com/google/play/billing/integrate);
- set `environment: "production"` so the mock verifier can never approve it.

## 4. Recommendation (06, not a decision)
P-A first: it is the plugin the Godot documentation points to, it ships Billing 9.1.0, and it has more users. P-B is a reasonable fallback that states Godot 4.7.2 support explicitly. Before choosing, 04 must confirm on the real Godot 4.7.2 export: Gradle build works, the merged manifest contains `com.android.vending.BILLING` and `com.google.android.play.billingclient.version` (B1 check), and the plugin's purchase dictionary fields match §3. Neither has been built or run here.
