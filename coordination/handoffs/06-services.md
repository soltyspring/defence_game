# 06-services handoff
Updated: 2026-10-31 17:30 KST (.uid audit, upgrade isolation, hosting question; backup study before)
Status: **M8 COMPLETE. Game Save integration gate PASSES (exit 0, binding=game)** after 02 registered the Services autoload (141d226). Resume check: worktree for 06 paths clean, checkpoint branch checkpoint/quota-20261031-092323/06-services (726e22a) has no diff vs HEAD for 06 paths → nothing lost. No Godot processes left running by 06.
Session ID: not exposed to the agent (same Kiro window throughout; never closed or restarted).
Nothing is live: no ad SDK, billing library, consent SDK, server, account or key. All services run in `disabled` mode. No monetization decision exists; none was invented.

## Ownership
src/services/**, docs/services/**, tests/services/**, coordination/status/06-services.md, coordination/handoffs/06-services.md, coordination/requests/06-services-to-*.md. User questions only via 01, one at a time.

## User decisions processed
- Q1 theme: A "빵집 기사단 vs 곰팡이 군단" (coordinator-to-06-services.md, 2026-10-31 09:03 KST; literal "모두 고치고 A) 빵집 기사단 vs 곰팡이 군단이걸로"). DECISIONS.md still showed Q1 PENDING when last read; 01 asked to record it.
- Monetization (Q2–Q5): not asked, not decided. D9 DEFAULT (disabled) applies.
- Q2 business model: DEFERRED by user 16:09 KST ("수익모델은 보류").
- Q3 title: working title "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense" (user 16:19 KST). Final store name only after a person runs KIPRIS classes 9 and 41 (KIPRIS_MANUAL_CHECK.md; NOT DONE).

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
| M11 | Data safety "No" confirmed vs 04 A7/C1 + own aapt2 (APK SHA-256 09AF2E47…A6DE, HEAD 8ad912f delta checked); in-app privacy link + licences display proposal (OFL text, Godot MIT + Engine copyright info); Q2 options A/B/C work and test scope; legal_and_options lint 55 checks, 3 mutations caught | e5099bdd7b911bd703ae9866b125c28173fde197 |
| M12 | Q2 deferred acknowledged; publishable disabled-mode privacy page (privacy_site/index.html, 6 placeholders = publish blockers), GitHub Pages hosting facts + H1–H4 choices + P1–P9 steps; content rating re-check for Q2 deferred; Families assessment T1–T3 aligned with 09 §25.3; lint privacy_site 41 + families 30 checks, 5 mutations caught | 98e757b15ce2e30dba6b2426715dd58115af22bb |
| Q3 | Working title in STORE_LISTING_DRAFT (single title block ko 15 / en 28 chars), App Store subtitle ko 21 / en 28, short ko 44 / en 73, full text reworded by role (no 반죽/제빵사/dough) and aligned to 01's data/text names; §7 Bread Defense phrase list; lint: title = Q3 title, ≤30 and ≥2, subtitle ≤30, competitor_overlap (279), brands +빵어전/bread defense/eternaxcode, kipris_manual_check (222: 16 terms × class 9/41, results need date+searcher, name log stays NOT_CHECKED while open); KIPRIS_MANUAL_CHECK.md; NAME_SEARCH_LOG v2; OPEN_DECISIONS U9; 16 mutations caught | f0d80e0a27692cdb891ff5b56f5ea67afd3dc334 |
| Backup | SAVE_BACKUP_POLICY.md: current values (allowBackup=false from Godot 4.7.2 template, no dataExtractionRules/fullBackupContent, hasFragileUserData=false, prebuilt template, user:// = getFilesDir, save.json/.bak/.tmp/.corrupt, ledger in same file), scenarios S1–S8 all NOT TESTED, options B0–B3 (rec. B0 now, B1 with Gradle), B1 rule XML, device test plan; DATA_SAFETY §2b; privacy [백업 활성화 시]/[IF BACKUP ENABLED]; test_services_android.gd (91 checks: preset permissions, APK binary-manifest + aapt2 AD_ID/BILLING/INTERNET/NETWORK_STATE absent, doc vs preset/save.gd/APK values, consistency), release_preset=WAITING; 12 mutations caught | 5fc46e1854460885150ce773a355d7bc0f0f892d, 082e9ca45def5f0255cdd707de1f74eda59886a1 |
| UID/upgrade | GODOT_UID_AUDIT.md (Godot 4.4+ rule: commit .uid; 19 untracked at start → 10 committed 4, 06 committed 4, 12 left for 02/04/07 via requests); godot_uid_tracked group in test_services_android; test_services_upgrade.gd (static scan of save.gd buy_upgrade/app.gd/04 panel, meta.json coin-only upgrades + iap disabled + gems disabled, runtime direct + App path: Services diagnostics and progress.services unchanged, result keys only id/to_level/code/coins/level); 8 mutations on temp copies (no other role's file edited); 01 hosting question candidate (not executed); SAVE_BACKUP_POLICY 10 cross-check | f59587cc763c4bc7fdaf8c9b8c35101d3e9fd7a8, 8f58a1c22c53253883a43dc5d570517afd0076db |
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
## M11 validation (actual)
Runner OVERALL exit=0: 502/0, 130/0, 161/0, listing 1024/0 (legal_and_options_docs 55), m8 26/0, m10 81/0, integration PASS_INTEGRATED 156/0 binding=game. Mutations (exit 1, restored): legal source removed, option cell empty, APK hash removed. Own re-check: aapt2 on build/qa/apk_head/defence-debug.apk (07e97ca) → no permissions, target 36, min 24, SHA-256 09AF2E47…A6DE; OFL-Galmuri.txt not in that APK (04 A6 still open). Requests: 04 R-M11 (privacy button, credits, licences view, APK re-check), 01 M11 (Q2 cost table), 05 (confirm no third-party audio).
## M12 validation (actual)
Runner OVERALL exit=0: 502/0, 130/0, 161/0, listing 1087/0, m8 26/0, m10 81/0, integration PASS_INTEGRATED 156/0 binding=game. Mutations (exit 1, restored): draft marker on page, section renamed, ad placeholder leaked onto page, rating answer flipped to Yes, Families source removed. Found on the way: the older content_rating check parsed my new §2a table as §2 (test scope fixed), and F2–F5 cited "same" instead of a URL (fixed). One edit hit a transient file lock while Godot read the file; mutation results from that run were discarded and redone after the edit succeeded.
User decision processed: Q2 DEFERRED 16:09 KST ("수익모델은 보류"): ads/billing stay disabled, no monetization UI.
## Q3 validation (actual)
Runner OVERALL exit=0: 502/0, 130/0, 161/0, listing 1482/0, m8 26/0, m10 81/0, integration PASS_INTEGRATED 156/0 binding=game. Mutations (each exit 1 with the expected message, files restored from byte backups): ko/en title over 30, ko/en subtitle over 30, short ko over 80, 반죽 in full.ko, "warm bread" in short.en, "duels" (plural) in full.en, 빵어전 in subtitle, ads line without marker ko/en, "Free" in title, fake KIPRIS status in the name log, KIPRIS result without searcher, HITS_RECORDED without a record, missing class 41 row.
Found on the way: 01's data/text (provisional_theme false) already uses 반죽/Dough, 제빵사, 화덕포, which are Bread Defense's words; store text now avoids them, the in-game names are routed to 01 (options keep / rename, 06-services-to-01-director.md Q3). 01's `ui.title` is still "레인 디펜스" (routed to 01). The old draft's unit names (바게트 투척병, 크루아상 방패병) no longer matched data/text; replaced by roles.
## Backup study validation (actual)
Runner OVERALL exit=0 incl. test_services_android 91/0 (2 APKs found: build/qa/apk_head 09AF2E47…, build/android 07:23 build; aapt2 36.1.0). Mutations (exit 1 with expected message): preset internet=true, preset custom AD_ID, retain_data_on_uninstall=true, release .aab export path, doc allowBackup=true, doc save path, S5 marked TESTED without evidence, .tmp in rule XML, "no device test" line removed, en backup conditional removed, Data safety deletion row changed, fake APK with AD_ID in build/release (removed after; dir did not exist before and was removed). Preset mutations used a temp copy (`-- --presets=`), not 02's file.
Not verified: any device behaviour (S1–S8), maker-specific D2D, whether Play's Data safety treats system backup as "not collected" (06 judgement by analogy with the Drive FAQ).
Seen, not acted on (not 06 scope): 03 A1/A2 note to 06 (working-title logos, adaptive icon layers for the export preset → 02/04).
## UID/upgrade validation (actual)
Runner 9 suites OVERALL exit=0 (android 176/0, upgrade 285/0). godot_uid_tracked failed (3) before the 06 .uid commit and passed after: check proven both ways. Upgrade-suite mutations (exit 1 with expected message, temp copies via --save-gd/--app-gd/--meta/--panel; hashes of the originals unchanged): Services call in buy_upgrade, gems instead of coins, receipt field in upgrade_result, App bypassing Save.buy_upgrade, product_id in meta upgrades, iap_catalog enabled, show_ad in panel, services data touched at runtime (--selfcheck-touch-services). Test artifact fixed on the way: JSON reload turns 1 into 1.0, so the disk comparison uses the same round trip on both sides.
.uid for test_services_upgrade.gd was written with ResourceUID.create_id() (same "uid://…\n" form as the editor) because Godot -s runs do not create one for a new script. 10's v0.18 note (no fsync on Android user://; B1 rules fine) acknowledged in SAVE_BACKUP_POLICY §4.
Privacy hosting: nothing created or published. One question candidate in 06-services-to-01-director.md (hosting approval; values asked later).
## Exact next steps when resumed
1. Read coordinator-to-06-services.md (latest section), DECISIONS.md, quota, replies to 06.
2. `pwsh -File tests/services/run_services_suites.ps1` must stay OVERALL exit 0 (9 suites).
3. When adding a new 06 script: run it once, then commit `<script>.gd.uid` with it (godot_uid_tracked fails otherwise).
4. If 01 approves hosting: the user creates the repo (P4/P5); 06 then fills placeholders (P3) only with values the user gave.
5. Backup option answer from 01 → SAVE_BACKUP_POLICY steps (see older list below).
## Older next steps (backup study): B1/B2 → wait for 02's Gradle build, then update SAVE_BACKUP_POLICY §1 values from the new APK and rerun test_services_android (it compares doc and APK). B1 → switch privacy draft/page and DATA_SAFETY §3 deletion row.
4. When a release preset or build/release APK/AAB appears: the android check runs on it automatically; record its hash in DATA_SAFETY §2a.
5. KIPRIS record filled by a person → update NAME_SEARCH_LOG KIPRIS rows from it only.
6. 01's in-game names (반죽/제빵사/화덕포) or differentiation wording → STORE_LISTING §4/§5/§7 + COMPETITOR_* lists.
## Older next steps (Q3, superseded): update the KIPRIS rows of NAME_SEARCH_LOG.md from that record only, rerun the lint; if any live 동일/유사 mark, tell 01 (patent attorney step).
4. If 01 renames 반죽/제빵사/화덕포 or picks other differentiation wording: update STORE_LISTING_DRAFT §4/§5/§7 and COMPETITOR_* in the lint.
5. When 03's re-themed art lands: revisit CONTENT_RATING_DRAFT.md violence/human-looking and disgust rows.
6. Monetization work only after 01 records user decisions (OPEN_DECISIONS.md U1…).
## Older next steps (M12, superseded)
1. Read coordinator-to-06-services.md (latest section), DECISIONS.md, quota, replies to 06.
2. `pwsh -File tests/services/run_services_suites.ps1` must stay OVERALL exit 0.
3. When 01 publishes themed display names (data/text still had pre-theme names at 15:45): replace `[이름 확정 대기]`/`[NAMES PENDING]` in STORE_LISTING_DRAFT.md, rerun the listing lint.
4. When 03's re-themed art lands: revisit CONTENT_RATING_DRAFT.md violence/human-looking and disgust rows.
5. Monetization work only after 01 records user decisions (OPEN_DECISIONS.md U1…).
## Errors seen this session (all handled)
- Publish-Task.ps1 fails if its stderr is redirected (`2>&1`, `2>$null`) because git fetch writes progress to stderr under ErrorActionPreference=Stop. Call it without redirection.
- Helper refused once with "Index is not empty" (another role's staged files); waited, did not touch foreign index entries.
- Auth expiry (08:21–08:22, previous account) left no partial files.
