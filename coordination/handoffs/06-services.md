# 06-services handoff
Updated: 2026-10-31 (M10 complete)
Status: **M8 COMPLETE. Game Save integration gate PASSES (exit 0, binding=game)** after 02 registered the Services autoload (141d226). Resume check: worktree for 06 paths clean, checkpoint branch checkpoint/quota-20261031-092323/06-services (726e22a) has no diff vs HEAD for 06 paths → nothing lost. No Godot processes left running by 06.
Session ID: not exposed to the agent (same Kiro window throughout; never closed or restarted).
Nothing is live: no ad SDK, billing library, consent SDK, server, account or key. All services run in `disabled` mode. No monetization decision exists; none was invented.

## Ownership
src/services/**, docs/services/**, tests/services/**, coordination/status/06-services.md, coordination/handoffs/06-services.md, coordination/requests/06-services-to-*.md. User questions only via 01, one at a time.

## User decisions processed
- Q1 theme: A "빵집 기사단 vs 곰팡이 군단" (coordinator-to-06-services.md, 2026-10-31 09:03 KST; literal "모두 고치고 A) 빵집 기사단 vs 곰팡이 군단이걸로"). DECISIONS.md still showed Q1 PENDING when last read; 01 asked to record it.
- Monetization (Q2–Q5): not asked, not decided. D9 DEFAULT (disabled) applies.

## Milestones and commits (all PUSHED to origin/main, verified with `git ls-remote`)
| M | What | Commits |
|---|---|---|
| M1 | Service boundaries, disabled/mock adapters, state machines, contract tests | 17623c1, 9c20763, b7fa3c0 |
| M2 | Ledger-first fix, cross-instance and corrupt-state fixes, reward policy, telemetry, diagnostics | 0f84461, 708bdb0, 7c43ebd |
| M3 | Real save.gd isolated tests incl. process death, grant-sink contract enforcement, consent flow, pending-cancel / ack-elsewhere | 5d61d0d, 078df2e, 1f6e57c |
| M4 | Game Save integration gate (exit 0/2/1), REWARD_STATE_TABLE, SAVE_INTEGRATION_CONTRACT, Services auto-attach/rebind, runner | 7fe59f9, 47c187b, f88ce03 |
| M5 | RELEASE_READINESS_SERVICES (23 requirements, official URLs, 2026-10-31) + gap table, OPEN_DECISIONS U1–U8 | 56cd600, 07e97ca |
| M6 | STORE_LISTING_DRAFT ko/en, PRIVACY_POLICY_DRAFT ko/en, metadata lint | 3afb259, e5bd4aa |
| M7 | NAME_SEARCH_LOG, CONTENT_RATING_DRAFT, DATA_SAFETY_DRAFT, lint groups, C1 → MET (APK targetSdk 36) | 996952fb43a2e34e36b1043aca7c052c301ac1c8 |
| M8 | Integration gate exit 0 on the real game wiring; launch/resume purchase reconcile; no-fill offer cooldown; brand-word lint; per-process test dirs (flaky collision fix); 8 mutations caught | d33a27bc22c33279f67a2134257e9ec7a5a10b6d |
| M9 | Billing prep: plugin candidates (both Billing 9.1.0, not installed), license-tester + internal-track test plan T1–T16 with [USER] steps, no-server minimum bar and risks, billing_docs lint (75 checks, 5 mutations caught) | 82108f86b612c1dbc5bae725be58a72cfea90d42 |
| M10 | Multi-quantity consumables: grant × quantity once per token, ledger records quantity, one consume; > max_quantity or invalid fails closed; test_services_m10 (81 checks incl. crash and sink-saves-then-fails on the autoload Save); state table P7; 5 mutations caught | 710384033c8cf518f83b5ea6afd81776ba0a898b |
| Checkpoint | this handoff + status | see status file / `git log -- coordination/handoffs/06-services.md` |

## M7 details (this task)
- Name search (2026-10-31 09:15–09:25): Play search page is JS-only (no results) → web search restricted to play.google.com + general web search. No app/game with any of the 6 candidate titles found; similar concepts: Rottenlands (mold-creature tower defense), A Baker's Dungeon (Steam), many bakery sims; CookieRun: Kingdom noted as concept-level comparison. **KIPRIS: NOT_CHECKED** (home page loads, trademark query URL timed out, search is browser-only, OpenAPI needs a key — not added). Manual steps listed in NAME_SEARCH_LOG.md §4.
- Content rating draft: answers per IARC topic with evidence and confirmer; expected outcome is an estimate only. **Open:** human-looking characters (current pre-theme art has warm-skin soldiers; hero head baker may stay human) could move PEGI 3/7 → 12. Change table for ads, purchases, random items, online/chat, location, redesign, children.
- Data safety draft (disabled mode): "No" collected/shared. Evidence: `aapt dump permissions build/qa/apk_head/defence-debug.apk` (09:03 build) → no permissions; badging targetSdk 36, minSdk 24; export INTERNET=false; no network code in src/; services D1 nothing live. Caveat: release AAB must be re-checked. Change table for ads, IAP, verification server, analytics, accounts.

## Validation (actual, last run before checkpoint)
`pwsh -File tests/services/run_services_suites.ps1` → test_services 502/0, test_services_m2 130/0, test_services_m3 161/0, test_services_listing 783/0 (incl. name_search_log 93, content_rating_draft 50, data_safety_draft 25), test_services_integration exit 2 BLOCKED_NOT_INTEGRATED (146 passes, 0 failures, blockers I1–I4). OVERALL exit=2. Mutation checks done in M2–M6 (all caught); none run for the M7 lint groups (not done before the stop).

## M8 validation (actual)
`pwsh -File tests/services/run_services_suites.ps1` → test_services 502/0, m2 130/0, m3 161/0, listing 893/0, m8 26/0, integration exit 0 `verdict=PASS_INTEGRATED` 156/0 blockers 0 `binding=game` (I1–I4 PASS, I5 NOT_REQUIRED_YET, I6 PASS; R1–R9, R14, R15, P1 game_evidence=true). OVERALL exit=0.
Found and fixed: `process_death` failed once (marker empty) while another Godot run started in the same second; test dirs were shared names wiped by the other run. Now `user://svc_*_test_<pid>`; 3 reruns clean.
Mutations (each exit 1, hash restored): M7 lint — KIPRIS row removed, invalid name status, rating topic removed, Data safety category removed, brand in title; M8 — attach reconcile removed, resume reconcile removed, no-fill cooldown removed.
## Unfinished / open
- RESOLVED: 02 S1/S2 (autoload registered; gate exit 0). S3 grant sinks only when 01 enables placements/products.
- Done: M7 lint mutation checks (M8).
- KIPRIS and live Play name search: user/professional must do by hand.
- Rating: human-looking-character question for 01/03.
- DD1 (late reward callback vs AdMob delivery rule) awaits 01.
- Requests to 01/02/04/07/10 all QUEUED (no acknowledgements seen).

## M9 validation (actual)
Runner OVERALL exit=0: 502/0, 130/0, 161/0, listing 968/0 (billing_docs 75), m8 26/0, integration PASS_INTEGRATED 156/0 binding=game. The billing_docs check first failed on 9 vague test-case expectations (prose instead of codes/signals); the plan was rewritten with exact signals and rerun green. 5 doc mutations each caught (exit 1), restored.
Open from M9: plugin purchase fields (signature/JSON/quantity) unverified; quantity not handled by purchase_service (keep multi-quantity off); client-side verifier not written (needs U6 = C).
## M10 validation (actual)
`pwsh -File tests/services/run_services_suites.ps1` on the tree of 7103840 (worktree clean): 502/0, 130/0, 161/0, listing 969/0, m8 26/0, m10 81/0, integration PASS_INTEGRATED 156/0 binding=game; OVERALL exit=0. Mutations (each exit 1, restored): quantity ignored (100 instead of 300), grant per unit loop (900), max_quantity unchecked (q=11 granted), ledger quantity dropped, consume per unit (3 consumes). One real bug found on the way: the quantity-mismatch counter existed only in the verify path, not in the ledger-hit path; fixed (no regrant happened in either path).
Semantics chosen from Play's multi-quantity guidance: one token, quantity N, one consume. Not verified on a real store: how the chosen plugin reports quantity (BILLING_PLUGIN_CANDIDATES.md §2).
## Exact next steps when resumed
1. Read coordinator-to-06-services.md (latest section), DECISIONS.md, quota, replies to 06.
2. `pwsh -File tests/services/run_services_suites.ps1` must stay OVERALL exit 0.
3. When 01 publishes themed display names (data/text still had pre-theme names at 15:45): replace `[이름 확정 대기]`/`[NAMES PENDING]` in STORE_LISTING_DRAFT.md, rerun the listing lint.
4. When 03's re-themed art lands: revisit CONTENT_RATING_DRAFT.md violence/human-looking and disgust rows.
5. Monetization work only after 01 records user decisions (OPEN_DECISIONS.md U1…).
## Errors seen this session (all handled)
- Publish-Task.ps1 fails if its stderr is redirected (`2>&1`, `2>$null`) because git fetch writes progress to stderr under ErrorActionPreference=Stop. Call it without redirection.
- Helper refused once with "Index is not empty" (another role's staged files); waited, did not touch foreign index entries.
- Auth expiry (08:21–08:22, previous account) left no partial files.
