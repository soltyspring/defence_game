# 06-services handoff — CHECKPOINT (user stop, 2026-10-31)
Updated: 2026-10-31 ~09:35 KST
Status: **STOPPED at a safe point by user instruction.** M7 complete and pushed. No work in progress; working tree for 06 paths is clean except this handoff/status (committed in the checkpoint commit). No Godot or emulator processes started by 06 are running (checked: `Get-Process Godot*` returned none).
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
| Checkpoint | this handoff + status | see status file / `git log -- coordination/handoffs/06-services.md` |

## M7 details (this task)
- Name search (2026-10-31 09:15–09:25): Play search page is JS-only (no results) → web search restricted to play.google.com + general web search. No app/game with any of the 6 candidate titles found; similar concepts: Rottenlands (mold-creature tower defense), A Baker's Dungeon (Steam), many bakery sims; CookieRun: Kingdom noted as concept-level comparison. **KIPRIS: NOT_CHECKED** (home page loads, trademark query URL timed out, search is browser-only, OpenAPI needs a key — not added). Manual steps listed in NAME_SEARCH_LOG.md §4.
- Content rating draft: answers per IARC topic with evidence and confirmer; expected outcome is an estimate only. **Open:** human-looking characters (current pre-theme art has warm-skin soldiers; hero head baker may stay human) could move PEGI 3/7 → 12. Change table for ads, purchases, random items, online/chat, location, redesign, children.
- Data safety draft (disabled mode): "No" collected/shared. Evidence: `aapt dump permissions build/qa/apk_head/defence-debug.apk` (09:03 build) → no permissions; badging targetSdk 36, minSdk 24; export INTERNET=false; no network code in src/; services D1 nothing live. Caveat: release AAB must be re-checked. Change table for ads, IAP, verification server, analytics, accounts.

## Validation (actual, last run before checkpoint)
`pwsh -File tests/services/run_services_suites.ps1` → test_services 502/0, test_services_m2 130/0, test_services_m3 161/0, test_services_listing 783/0 (incl. name_search_log 93, content_rating_draft 50, data_safety_draft 25), test_services_integration exit 2 BLOCKED_NOT_INTEGRATED (146 passes, 0 failures, blockers I1–I4). OVERALL exit=2. Mutation checks done in M2–M6 (all caught); none run for the M7 lint groups (not done before the stop).

## Unfinished / open
- **BLOCKER (02):** `Services` autoload not in project.godot → integration gate cannot reach exit 0. One line requested repeatedly (06-services-to-02-engine.md S1). No reply seen.
- M7 lint groups have no mutation check yet.
- KIPRIS and live Play name search: user/professional must do by hand.
- Rating: human-looking-character question for 01/03.
- DD1 (late reward callback vs AdMob delivery rule) awaits 01.
- Requests to 01/02/04/07/10 all QUEUED (no acknowledgements seen).

## Exact next steps when resumed
1. Read coordinator-to-06-services.md (latest section), DECISIONS.md, quota usage.json, any 02→06 reply.
2. `git fetch` + `git status` for 06 paths (expect clean).
3. If project.godot has `Services=`: run `pwsh -File tests/services/run_services_suites.ps1`; require OVERALL exit 0 and every R/P row `binding=game`, then update SAVE_INTEGRATION_CONTRACT.md status and REWARD_STATE_TABLE.md "Game binding" column; commit.
4. Optional: mutation-check the M7 lint groups (remove a KIPRIS row, flip INTERNET in a temp copy is NOT allowed — use a test-only override instead).
5. When 01 publishes themed unit names: replace `[이름 확정 대기]` / `[NAMES PENDING]` in STORE_LISTING_DRAFT.md and rerun the listing lint.

## Errors seen this session (all handled)
- Publish-Task.ps1 fails if its stderr is redirected (`2>&1`, `2>$null`) because git fetch writes progress to stderr under ErrorActionPreference=Stop. Call it without redirection.
- Helper refused once with "Index is not empty" (another role's staged files); waited, did not touch foreign index entries.
- Auth expiry (08:21–08:22, previous account) left no partial files.
