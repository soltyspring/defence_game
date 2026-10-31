# 06-services handoff
Updated: 2026-10-31 ~23:42 KST (real-folder leftovers quarantined; CRLF check; blue-screen resume before)
## Quarantine and line endings (23:35–23:42, no Godot)
- **Quarantine:** 16 06-made files moved, not deleted, from `%APPDATA%\Godot\app_userdata\Lane Defence\` to `%LOCALAPPDATA%\defence_userdata_quarantine\06-20261031-233513\`, with MANIFEST_06.json.
  - Before/after hashes all match; save.json 614A1FAC… and .bak E4263BE6… unchanged.
  - Undo one-liner: docs/services/USERDATA_QUARANTINE_06.md.
  - Not touched: save files, logs/, other roles' files.
- **Line endings:** blobs LF; `git archive` CRLF (system core.autocrlf=true); 04 apk_head CRLF; 02 build/android LF + economy.json mixed. PLAY_TECH_REQUIREMENTS §9; request to 02.
- **Next AAB run** (under heavy_run): add a check of `assets/data/**` line endings in the AAB. Expected CRLF until 02 adds .gitattributes or normalises the hash.
## Blue-screen resume check (23:23)
- `git status` for 06 paths: clean. `git diff HEAD` over all 127 tracked 06 files: clean. No file is missing, zero-byte or NUL-filled (byte scan).
- Last 06 commit before the crash, 6303e18, is in origin/main. No 06 temp folders and no Gradle Java processes were left.
- Before the crash 06's last heavy run ended 23:07 (AAB). Nothing of 06 was running at 23:08:55.
## Heavy-run rule (from 23:2x, must follow)
- Every Godot, Gradle/AAB/APK or emulator step runs one at a time PC-wide, inside `& .\coordination\heavy_run.ps1 -Label '06-<name>' -Script { … }`.
- 06 runners check this: `Assert-SvcHeavyLock` in svc06_isolation.ps1 makes `run_services_suites.ps1`, `run_services_on_head.ps1` and `try_debug_aab.ps1` exit 4 unless an ancestor process holds the lock. Verified: a direct run is refused (exit 4); the heavy_run run is accepted.
- Commands:
  - suites: `& .\coordination\heavy_run.ps1 -Label '06-services-suites' -Script { pwsh -NoProfile -File tests/services/run_services_suites.ps1 }`
  - AAB: `& .\coordination\heavy_run.ps1 -Label '06-test-aab' -Script { pwsh -NoProfile -File tests/services/try_debug_aab.ps1 -TimeoutSec 900 -JavaHome "$env:LOCALAPPDATA\svc06_tools\jdk-17.0.20.1+1" -Bundletool "$env:LOCALAPPDATA\svc06_tools\bundletool-all-1.18.3.jar" }`
  - The emulator install check (below) must also run inside one heavy_run block.
## Post-crash validation (actual)
- Run: heavy_run '06-services-suites', lock acquired after 308 s wait, 23:30:44 end.
- Results: 502/0, 130/0, 161/0, listing 1831/0, m8 26/0, m10 81/0, android 189/0 (VERIFIED_DEBUG_ONLY / release WAITING), upgrade 927/0, integration PASS_INTEGRATED 156/0. OVERALL exit 0.
- SVC06_ISOLATION isolated=true; 0 writes to the real folder; real save unchanged; 0 other Godot processes at start.
- Commit: 96e996245591795a75b03a580cd74de230cc3be0 [Test] (heavy_run guard); 287ad661adcb35b9b73184c0b3be3d10538a1e5c [Docs] (this resume record, status, 02 request).
## Earlier resume (22:57) for reference
Updated earlier: 2026-10-31 ~23:08 KST (resumed after the 97% stop at 20:27; new account, quota ~0.4% at 22:57)
## Resume check (22:57)
- **Nothing lost.** Branch `checkpoint/quota-20261031-202729/06-services` (fede276) is an empty WIP commit; `git diff` vs the working tree for 06 paths is empty; the 06 worktree was clean.
- **Decisions in force:** Q1 theme A, Q2 deferred (ads/billing disabled), Q3 title "빵집 기사단: 곰팡이 디펜스", Q4 launcher "빵집 기사단". Q5 difficulty is unanswered; D28 is a default, not an approval.
## Done this session (real SHAs)
| What | Commit |
|---|---|
| Isolation: `tests/services/svc06_isolation.ps1`, used by `run_services_suites.ps1`, `run_services_on_head.ps1` and `try_debug_aab.ps1`. Private APPDATA; real save hashed before/after; proof line `SVC06_ISOLATION`; no proof → OVERALL 1 | 29d31be19fd9a2fe701f2bfbc8ec36e7aaccbc0e |
| Docs: PLAY_TECH §8 (AAB rerun results), requests 02/10, this handoff and status | e78c7900f2df63b4bf1ef434a6f293148a6277e5 |
## Validation (actual)
- `pwsh -NoProfile -File tests/services/run_services_suites.ps1`, 23:00:34–23:01:04, shared tree, 4 other Godot processes:
  - 502/0, 130/0, 161/0, listing 1831/0, m8 26/0, m10 81/0
  - android 189/0 (launcher_label=VERIFIED_DEBUG_ONLY, release_label=WAITING)
  - upgrade 927/0, integration PASS_INTEGRATED 156/0
  - OVERALL exit 0
  - SVC06_ISOLATION isolated=true, private_logs=5, 0 new reports and 0 new godot logs in the real folder, real save unchanged
- `try_debug_aab.ps1 -Ref 29d31be -JavaHome <svc06 jdk17> -Bundletool <jar>`, 23:01–23:07, end to end:
  - AAB 59,213,224 B, PAGE_ALIGNMENT_16K
  - universal_badging: target 36, labels en/default Bakery Knights, ko 빵집 기사단, native-code arm64-v8a + x86_64, no permissions
  - arm64 download 30.40–30.42 MB
  - isolated=true; no Java leftovers; scratch deleted
## Open
1. **Emulator install/run: WAITING.** `adb devices` empty at 23:07; 02 has not announced LaneDefence_Phone (request appended 23:08). Procedure unchanged (below). Never stop qemu.
2. **Leftover 06 files in the real user folder** (7 `services_*_report.json` from 18:44/19:04, `m3dbg1~3`): not deleted, because that would be a write there. Asked 10/coordinator.
3. A single suite run directly with `godot -s` still uses the real folder. Use the runners.
## Next steps when resumed (newest first)
1. (done 23:07) Rerun `try_debug_aab.ps1` to confirm `out/universal_badging.txt`.
2. When 02 announces LaneDefence_Phone is running, in an agreed time slot and without stopping qemu:
   - `java -jar bundletool build-apks --connected-device --bundle=<aab> --output=x.apks --ks=<debug ks> …`
   - `install-apks --apks=x.apks`
   - `adb shell monkey -p com.soltyspring.lanedefence 1`
   - record the launcher label, the first screen, any crash (`adb shell pidof`), and the `logcat -s godot` error count
   - check that the window is on DISPLAY2
3. Godot's own Gradle success on the JDK 25 setting is unexplained. Do not rely on it; keep passing -JavaHome.
## Test AAB with private JDK 17 (19:09–19:35)
- **Command:**
  ```
  pwsh -NoProfile -File tests/services/try_debug_aab.ps1 -TimeoutSec 900 -JavaHome "$env:LOCALAPPDATA\svc06_tools\jdk-17.0.20.1+1" -Bundletool "$env:LOCALAPPDATA\svc06_tools\bundletool-all-1.18.3.jar"
  ```
  The Godot step is capped at 240 s because Godot may not exit after export. The Gradle rerun uses a temp .cmd with every argument quoted, since the ABI list contains `|`.
- **This session:** the final Gradle rerun and the bundletool checks were run by hand with the same logic, after the script's first pass had the `C:`/`|` quoting bugs. The committed script contains those fixes, but **a full end-to-end rerun of the committed script has not been done yet.** Do one before relying on it.
- **Cleanup after each run:** delete %TEMP%\svc06_aab_* and stop leftover Java processes whose command line contains svc06_tools or GradleDaemon.
- **Tool locations and checksums:** PLAY_TECH_REQUIREMENTS §6.
## Test AAB attempt (18:51–19:02)
- **Script:** `pwsh -NoProfile -File tests/services/try_debug_aab.ps1 [-TimeoutSec 600]`. Scratch git-archive copy; it flips the Gradle/AAB options and unpacks android_source.zip there only, then exports with `--export-debug` and the editor's debug keystore.
- **Blocker:** editor setting `export/android/java_sdk_path` = JDK 25.0.2. Gradle 8.11.1 needs Java ≤ 23. Once a JDK 17 exists and the setting points at it, rerun the script; on success, check the AAB with bundletool (not installed): `build-apks --mode=universal` and per-device APKs, `dump config` PAGE_ALIGNMENT_16K, aapt2 badging target 36 / labels, `get-size total`.
- **Cleanup:** the script leaves %TEMP%\svc06_aab_<sha> and possibly a Gradle daemon. Delete them afterwards, as done this time.
- **Quota:** ~82% at 19:05.
## Clean-HEAD run (18:39–18:46)
- **Command:** `pwsh -NoProfile -File tests/services/run_services_on_head.ps1 [-Ref <sha>] [-Keep]`. It runs a git archive snapshot with its own `--import`, copies the APKs from build/, and runs the same 9 suites. Use it whenever other roles have uncommitted edits in the shared tree (at 18:39 src/core/app.gd, content.gd, save.gd and audio_event_bridge.gd were modified by others).
- **Snapshot limits:** godot_uid_tracked reports NOT_RUN there (no .git), so run test_services_android in the shared tree for it.
- **q2_repo_scan mutation hook:** `-- --q2-extra-dir=<dir>` (planted files only, outside the repo).
- **Launcher icon next step:** after 02 adds the launcher_icons keys and rebuilds, compare the APK's icon_foreground.webp/icon_background.webp with 03's layers (colour/shape probe as in this session).
## Store graphics (17:55–18:00, Python only)
- **Checker:** `python tests/services/check_store_graphics.py`. Final assets are expected in docs/services/store_assets/, which does not exist yet: `icon*.png`, `feature*.png|jpg`, `screenshot*.png|jpg`.
- **After 18:30, if Godot is allowed:**
  1. Run the services runner.
  2. When 02 sets launcher_icons and rebuilds, read the APK's mipmap icon resources (aapt2 dump resources) to confirm the adaptive icon is used instead of icon.svg.
  3. Consider adding check_store_graphics.py to run_services_suites.ps1 as a non-blocking step. Exit 3 must not turn OVERALL red.
## Label settings check (17:45–17:52)
- **What 02 changed (4b5926d, read only):** package/name "Bakery Knights", name_localized en "Bakery Knights" / ko "빵집 기사단". config/name stays "Lane Defence" to keep the desktop user:// path.
- **Debug APKs:** 02's debug APKs (build/android 17:37, build/qa/apk_q4probe 17:36) carry the right labels. Note: apk_q4probe is not in the scanned dirs.
- **First runner run:** OVERALL exit 1. 06's own lint still expected the old doc line, and the "Q4 waits" check was stale. Both fixed and rerun: exit 0.
- **Proof of release_label=VERIFIED:** done with a temporary copy in build/release, which was removed. It showed release_preset=PRESENT, and the doc mismatch that follows from that, as the 2 expected failures.
- **Next:** when a real release APK/AAB lands in build/release, expect release_label=VERIFIED and release_preset=PRESENT, then update SAVE_BACKUP_POLICY §1/§8 and DATA_SAFETY §2a for that build. **No Godot runs between 18:00 and 18:30.**
## Play tech requirements (2026-10-31 ~17:45, static)
- No Godot, editor or emulator was run (coordinator: 18:00–18:30 quiet window for 08, and this task was to be done without Godot).
- Tools used: zipalign -c and a PowerShell read of ELF64 program headers from the APK zip entries (p_align, GNU_RELRO vaddr+memsz vs the LOAD segments).
- Next time Godot is allowed again: optionally add an automatic ELF/zip-alignment group to test_services_android for APKs under build/release, then run the full runner. Not done now because it would need a Godot run to validate.
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
| D25/Q4 | Store text on 01 D25 words; §7 split blocked vs allowed generic (제빵사, 화덕); lint game_text_overlap (data/text ko/en vs block list, ui.title = working title, store names resource/worker/hero); privacy preview with working title + KIPRIS banner (make_privacy_preview.ps1, lint privacy_preview reverse-transform); §2b launcher name vs store title with Play sources, label unchanged (`Lane Defence`, 02); lint launcher_label_note; 10 mutations caught | 78318a24d4ff5393b7135ad7b778660e17d9adc8 |
| Q4 | Launcher name decision recorded (§2b launcher blocks, NAME_SEARCH_LOG, OPEN_DECISIONS U10, KIPRIS search-first note); lint: launcher = store title before ":", brand/Bread Defense clean, KIPRIS §3 rows + no-space forms, name-log rows; android launcher_label: aapt2 badging (UTF-8 via temp file) OLD=WAITING / OK=VERIFIED / else FAIL, preset package/name + name_localized checks | c0218449596086c29a3fecd91078e5930effcfb6, 2193dcb6a87598fa00c4eca62f33999df83a3a2e |
| Play tech | PLAY_TECH_REQUIREMENTS.md: P1 API 36, P2 64-bit, P3 16 KB (ELF LOAD, RELRO own-segment rule, zip alignment), P4 AAB; preset + Godot 4.7.2 config.gradle (AGP 8.6.1, NDK r29, target 36/min 24) + debug APK ELF header read; verdicts PASS/PASS/PASS(APK)/UNKNOWN(AAB zip)/FAIL(AAB); requests to 02 (release Gradle/AAB preset) and 04 (bundletool PAGE_ALIGNMENT_16K etc.). Static only, no Godot run | (this commit, see status) |
| Label fmt | 4b5926d read only; listing lint cites export settings; android launcher_label VERIFIED_DEBUG_ONLY vs release_label (build/release only); config/name "Lane Defence" impact table (PC title, Project Manager, fallback menu) + options to 02/04 | 31dc7b0b0226dbad1ecebdc18eb2e5f8cc4670fb, fa5661b58269ec54f13b28f8973f5877f953151f |
| Graphics | STORE_GRAPHICS.md (Play icon/feature/screenshot/video rules + adaptive icon guide), check_store_graphics.py (Python), 09 order vs rules (#3 반죽 conflict), requests 03/04/02/09 | a68bf517ce3b93c375bd7ff8337cdc7175dd88a7, a143134be5ba6c2fbe2082bcd1f8f09c4ec23de2 |
| HEAD run | run_services_on_head.ps1 (clean snapshot runner); q2_repo_scan group (repo-wide Q2 deferred scan); launcher icon placeholder confirmed in both APKs; exact launcher_icons keys to 02 | 643cfa05f879ff76fffb96c909a1de4309fa3970 (+ next [Docs]) |
| AAB try | try_debug_aab.ps1 (scratch Gradle/AAB export) → blocked by JDK 25 vs Gradle 8.11.1; DATA_SAFETY §2c code-evidence lines; B0–B3 question candidate to 01; requests 02/04 | 71325251423518de06b657dc3c250336997d01db (+ next [Docs]) |
| AAB built | private Temurin 17 + bundletool 1.18.3 (checksums verified); Godot's Gradle command rerun with process-only JAVA_HOME; AAB checks all PASS; script updated (end-to-end rerun pending) | 8fc4715b704c056b073c871ece834f8efd146e4f (+ next [Docs]) |
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
## D25/preview/Q4 validation (actual)
Runner OVERALL exit=0 (listing 1775/0). Mutations (exit 1 with expected message): 반죽 back in res.supply and "Warmth" in an en string (temp copies via `--text-dir=`), en ui.title "Lane Defence", store text without the resource word, "dough" in store text, 제빵사 exception note removed, preview banner "KIPRIS 미확인" removed, preview body drift vs template, {{APP_NAME}} filled in the template, §2b claiming the label changed. 3 mutation set-ups were wrong on the first run (expected-message text, one mutation left the second 밀가루) and were fixed in the script, not in the lint.
Found: USER_QUESTION Q4 says the title is 14자; lint counts 15 (sent to 01). 04's 97c8b9c (panel wired to cmd_buy_upgrade) still passes test_services_upgrade.
## Q4 validation (actual)
- Runner OVERALL exit=0.
- Label check proof: four throwaway APKs were built with `aapt2 compile/link` against android-36 android.jar (labels: OK, typo, full title, wrong ko) and copied briefly into build/android. Results: OK → `launcher_label=VERIFIED`, exit 0; the other three → FAIL. All four were deleted afterwards.
- Found on the way:
  1. OS.execute's captured stdout loses Korean on Windows (UTF-8 probe), so badging is read through a redirected temp file.
  2. Passing the redirect through `cmd /c` broke quoting (every label read as NONE), so the command now runs from a tiny temp .cmd file.
  3. The KIPRIS launcher check first matched the §5 summary rows, which let one mutation through; it is now tied to the §3 term-row format and that mutation is caught.
- Q2 deferred and nothing published remain true.
## Exact next steps when resumed
1. Read coordinator-to-06-services.md (latest section), DECISIONS.md, quota, replies to 06.
2. Runner must stay OVERALL exit 0 (9 suites).
3. When 02 rebuilds with the Q4 label: expect launcher_label=VERIFIED, then update STORE_LISTING §2b "Current launcher name in the build" (lint launcher_label_note follows package/name).
4. KIPRIS done by a person → final name; then P3 fill and drop the preview.
## Older next steps (D25 / preview) → update STORE_LISTING_DRAFT §2b current label (lint launcher_label_note enforces).
4. 01 renames game words again → store text §4/§5 and COMPETITOR_*/ALLOWED_GENERIC_KO follow (lint game_text_overlap enforces).
5. privacy_site/index.html edited → rerun `pwsh -File tests/services/make_privacy_preview.ps1` (lint privacy_preview enforces).
6. KIPRIS done by a person → final name; then fill {{APP_NAME}} in the template (P3) and drop the preview.
## Older next steps (.uid / upgrade)
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
