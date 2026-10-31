# 06-services status
Updated: 2026-10-31 ~23:56 KST (LF-pinned test builds; AAB data read directly; content_version matches)
Status: COMPLETE except the emulator install check.
- **4bf8f74:** 06 build copies use `git -c core.autocrlf=false -c core.eol=lf archive`, plus a gate that refuses a build if any data JSON has CRLF (exit 5).
- **AAB rebuilt once under heavy_run (3e355a8):** 21/21 data files LF inside the AAB. content_version c1-e8790a4f2e85 is the same from the AAB bytes, the committed blobs and Godot.
- Labels, target 36, 16 KB and ABI unchanged.
- No temp folders or Gradle Java processes left.
- Requests to 02/04 for the other build paths. Emulator still WAITING for 02.
- Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Commits: 4bf8f742e049c7cc050e8951ba88321b860c1585 [Test] PUSHED; docs in the next [Docs].
Previous: 95d9b1c / 3e355a8 (quarantine, CRLF table).
--- History (older entries, not current) ---
(quarantine entry) Updated: 2026-10-31 ~23:42 KST (real-folder leftovers quarantined; CRLF impact on test AAB)
Status: COMPLETE except the emulator install check.
- **Leftovers moved:** 16 files (7 reports and m3dbg1~3) moved to `%LOCALAPPDATA%\defence_userdata_quarantine\06-20261031-233513\`. Hashes verified, save.json/.bak unchanged. Undo: USERDATA_QUARANTINE_06.md.
- **Line endings:** `git archive` on this PC gives CRLF data (core.autocrlf=true), so 06's test AAB carried CRLF data (inferred from the same input; the AAB itself was deleted). The 02 shared-tree APK has LF plus 1 mixed file. Requests sent to 02 (.gitattributes / normalised content_version).
- **Emulator:** WAITING for 02.
- Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Commits: 95d9b1cc42985840f2bde2128bff9e5a88c01445 [Docs] PUSHED.
Previous: 96e9962 / 287ad66 / 369a2dc (blue-screen resume, heavy_run guard).
--- History (older entries, not current) ---
(blue-screen entry) Updated: 2026-10-31 ~23:33 KST (blue-screen resume; heavy_run guard; post-crash validation)
Status: COMPLETE except the emulator install check.
- **Crash check:** 06 files intact (127 files: no zero-byte or NUL content; `git diff HEAD` clean; 6303e18 on origin).
- **heavy_run:** 06 runners refuse to run outside coordination\heavy_run.ps1 (96e9962).
- **Post-crash run:** under heavy_run, OVERALL exit 0, isolated=true, 0 real-folder writes.
- **Emulator:** WAITING. No device, no 02 slot. When it comes, it runs inside heavy_run.
- Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Commits: 96e996245591795a75b03a580cd74de230cc3be0 [Test], 287ad661adcb35b9b73184c0b3be3d10538a1e5c [Docs] PUSHED.
Previous: 29d31be / e78c790 / 6303e18 (isolation, AAB rerun).
--- History (older entries, not current) ---
(22:57 resume entry) Updated: 2026-10-31 ~23:08 KST (resumed; isolation committed; AAB rerun verified; emulator WAITING)
Status: COMPLETE except the emulator install check.
- Resume check: nothing lost vs checkpoint/quota-20261031-202729/06-services.
- **Isolation (29d31be):** all 06 runners use a private APPDATA. First isolated run OVERALL exit 0 with isolated=true and 0 writes to the real folder.
- **Test AAB rerun on 29d31be:** universal_badging target 36, ko 빵집 기사단 / en Bakery Knights, arm64 + x86_64, no permissions, 16 KB OK.
- **Emulator:** none running and no slot from 02, so install/run is WAITING.
- Old 06 files in the real user folder were left untouched; asked 10/coordinator.
- Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Commits: 29d31be19fd9a2fe701f2bfbc8ec36e7aaccbc0e [Test], e78c7900f2df63b4bf1ef434a6f293148a6277e5 [Docs] PUSHED.
Quota: ~0.5% (new account).
Previous: a386b15 / 5c0ced7 (AAB rerun, size breakdown).
--- History (older entries, not current) ---
(pre-stop entry) Updated: 2026-10-31 ~19:47 KST (AAB script rerun end to end; install check not possible; size breakdown)
Status: PARTIAL.
- **(1) Rerun on 84c18ab:** the committed script ran end to end and produced an AAB again (59,200,008 B; PAGE_ALIGNMENT_16K; download arm64 30.39–30.40 MB; default label Bakery Knights). Godot's own Gradle step succeeded this time even on the JDK 25 setting (cause unknown, recorded). The universal-APK aapt2 step had an argument bug; it is fixed but not rerun.
- **(2) Install/run: NOT DONE.** No emulator was running (adb devices empty at 19:34), and 06 did not start one.
- **(3) Size:** native engine lib 85% of the download. Candidates sent to 02/08.
- Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Quota: ~92% at 19:45. **Stop at ≥ 97%.**
Previous: 8fc4715 / 84c18ab (AAB built with private JDK 17).
--- History (older entries, not current) ---
(AAB-built entry) Updated: 2026-10-31 ~19:35 KST (test AAB built with a private JDK 17 and checked with bundletool)
Status: COMPLETE.
- **Test AAB built** (scratch copy of 53883db, debug key, JDK 17 only inside the build process; no upload key, no upload, 02/04 files untouched).
- **Bundle checks:** PAGE_ALIGNMENT_16K, split zipalign -P 16 OK, ELF LOAD 0x4000; target 36 / min 24; arm64 + x86_64 only; labels en Bakery Knights / ko 빵집 기사단; no permissions; allowBackup=false; download ≈ 29.0 MiB arm64, 31.6 MiB x86_64.
- **Tools:** Temurin 17.0.20.1+1 and bundletool 1.18.3, checksums match the official values; in `%LOCALAPPDATA%\svc06_tools` (delete the folder to remove). PLAY_TECH_REQUIREMENTS §6.
- **Still open (02):** Gradle/AAB preset in the repo, editor JDK, launcher icon keys. release_label stays WAITING (no build/release package).
- Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Commits: 8fc4715b704c056b073c871ece834f8efd146e4f [Test] PUSHED; docs in the next [Docs].
Quota: ~88% at 19:31. Checkpoint and stop at ≥ 97%.
Previous: 7132525 / efcd4c0 (AAB blocker, Data safety evidence, backup candidate).
--- History (older entries, not current) ---
(AAB-blocked entry) Updated: 2026-10-31 ~19:08 KST (test AAB attempt, Data safety evidence lines, backup question candidate)
Status: COMPLETE with one blocker.
- **Test AAB: BLOCKED.** Gradle 8.11.1 (Godot 4.7.2 template) cannot run on the machine's only JDK 25.0.2 ("Unsupported class file major version 69"); a JDK 17 is needed. Scratch copy only; no upload key, no upload; 02/04 files untouched. bundletool checks therefore NOT RUN.
- **Data safety:** DATA_SAFETY_DRAFT §2c ties each answer to a rerunnable grep or lint (network, SDK, ID and log calls: 0 hits).
- **Backup:** B0–B3 user-question candidate sent to 01.
- Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Validation: listing 1825/0 and android 189/0 after the doc edits; clean-HEAD full run at 643cfa0 OVERALL exit 0 (18:44).
Commits: 71325251423518de06b657dc3c250336997d01db [Test] PUSHED; docs in the next [Docs].
Quota: ~82% at 19:05. Checkpoint and stop at ≥ 97%.
Previous: 643cfa0 / 27e7a44 (clean-HEAD run, launcher icon).
--- History (older entries, not current) ---
(HEAD-run entry) Updated: 2026-10-31 ~18:46 KST (post-quiet-window full run on clean HEAD; launcher icon confirmed placeholder)
Status: COMPLETE.
- **Clean HEAD runs** (tests/services/run_services_on_head.ps1, git archive + own import):
  - b4b33a7, 18:39–18:40: OVERALL exit 0.
  - 643cfa0, 18:43–18:44: OVERALL exit 0. Results: 502/0, 130/0, 161/0, listing 1825/0, m8 26/0, m10 81/0, android 104/0 (launcher_label=VERIFIED_DEBUG_ONLY, release_label=WAITING, release_preset=WAITING; .uid group NOT_RUN in snapshot), upgrade 901/0 (incl. new q2_repo_scan 616), integration PASS_INTEGRATED 156/0.
  - No failures.
- **Shared tree:** android 189/0, godot_uid_tracked PASS, 0 untracked .uid outside 06 paths.
- **Q2 scan:** 0 Services.ads/purchases, get_singleton, billing/AdMob, receipt or HTTP calls in src/ and scenes/ outside src/services; no addons/; no enabled plugin flags; iap disabled. 2 planted-file mutations were caught, and a comment-only mention was ignored.
- **Launcher icon:** export preset has no launcher_icons keys, and both APKs carry the Godot placeholder from icon.svg (aapt2 + Python colour check). Exact keys sent to 02.
- Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Commits: 643cfa05f879ff76fffb96c909a1de4309fa3970 [Test] PUSHED; docs/status in the next [Docs] commit.
Previous: a68bf51 / a143134 / 8d026d2 (store graphics).
--- History (older entries, not current) ---
(graphics entry) Updated: 2026-10-31 ~18:00 KST (Play store graphics; Python only, no Godot)
Status: COMPLETE. STORE_GRAPHICS.md + `python tests/services/check_store_graphics.py` (exit 3 = nothing fails, required assets missing).
- **Missing:** store icon 512, feature graphic 1024×500, screenshots (≥ 2; 3+ at 16:9 1920×1080 for game recommendations).
- **Existing 1600×720 captures fail** the 2:1 rule; the 1280×720 captures are too small for recommendations and mostly RGBA.
- **Adaptive icon:** passes size, safe zone and opaque background; logo 40×42.5 dp is below the 48 dp guide.
- **Launcher icon in the build:** the preset has no launcher_icons keys, so the build uses icon.svg. UNVERIFIED until a rebuild after 18:30.
- **09 order:** fits, but #3 still says 반죽 (D25 → 밀가루).
- Requests sent to 03/04/02/09. Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Validation: Python checker only; Godot services runner NOT run (quiet window 18:00–18:30). Last runner OVERALL exit=0 at 17:47.
Commits: a68bf517ce3b93c375bd7ff8337cdc7175dd88a7 [Test], a143134be5ba6c2fbe2082bcd1f8f09c4ec23de2 [Docs] PUSHED.
Previous: 31dc7b0 / fa5661b / 13e78c0 (label settings, config/name impact).
--- History (older entries, not current) ---
(label entry) Updated: 2026-10-31 ~17:52 KST (02 4b5926d label settings checked; config/name impact)
Status: COMPLETE.
- 02's launcher-name format works with 06's check: package/name "Bakery Knights" + name_localized en/ko.
- 06 fixed only its own items: the doc line now cites the export settings, the "Q4 waits" check was removed (Q4 is answered), and a debug APK no longer counts as release proof.
- Label status: launcher_label=VERIFIED_DEBUG_ONLY (build/android 17:37 APK OK; apk_head 09:03 still OLD); release_label=WAITING.
- "Lane Defence" still shows in the PC window title, the Project Manager and the fallback menu; impact table and options sent to 02/04.
- Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Validation: services runner at 17:46:49–17:47:10 OVERALL exit=0 (listing 1825/0, android 189/0); release_label proof with a temporary build/release copy at 17:48 (VERIFIED, removed after; that run's 2 failures were the expected release_preset doc mismatch for a fake release APK). Last Godot run ended 17:48:47, before the 18:00–18:30 quiet window.
Commits: 31dc7b0b0226dbad1ecebdc18eb2e5f8cc4670fb [Test], fa5661b58269ec54f13b28f8973f5877f953151f [Docs] PUSHED.
Previous: 0f3dfc8 (Play tech requirements).
--- History (older entries, not current) ---
(Play tech entry) Updated: 2026-10-31 ~17:45 KST (Play technical requirements, static; no Godot run)
Status: COMPLETE. PLAY_TECH_REQUIREMENTS.md: API 36 (since 2026-08-31) PASS, 64-bit PASS, 16 KB ELF LOAD 0x4000 + RELRO PASS and zipalign -P 16 PASS on the 07e97ca debug APK; AAB (required for new apps) FAIL = no Gradle/AAB preset (02/04 A12); 16 KB zip alignment of a future AAB UNKNOWN (expected with AGP 8.6.1, not measured). No device test, no Play upload. Requests to 02/04. Q2 DEFERRED. Nothing published.
Current task: none. Next: see handoff.
Validation: docs-only change; services runner NOT rerun (coordinator: no Godot runs, quiet window 18:00–18:30 for 08). Last full run OVERALL exit=0 at 2193dcb.
Previous: c021844 / 2193dcb / 26d6809 (Q4 launcher name).
--- History (older entries, not current) ---
(Q4 entry) Updated: 2026-10-31 ~18:05 KST (Q4 launcher name recorded and checked)
Status: COMPLETE. Q4 DECIDED by user 17:19 KST (original "빵집 기사단"): launcher ko 빵집 기사단 / en Bakery Knights; store and in-game titles stay the full working title; final store name after KIPRIS. Recorded in STORE_LISTING §2b (launcher blocks), NAME_SEARCH_LOG, OPEN_DECISIONS U10, KIPRIS §3 (T2/T3, T11/T12 already present; marked search-first; all rows NOT_DONE). Lint: launcher = store title before ":". APK label check: launcher_label=WAITING (both APKs still `Lane Defence`; 02 rebuild pending). Q2 DEFERRED. Nothing published. Gate PASS.
Current task: none. Next: see handoff.
Validation (latest): runner 9 suites OVERALL exit=0 (listing 1825/0, android 186/0 launcher_label=WAITING). Label check proven on 4 throwaway aapt2-built APKs (OK→VERIFIED exit 0; typo, full title, wrong ko → FAIL), deleted after. 5 listing mutations caught.
Commits: c0218449596086c29a3fecd91078e5930effcfb6 [Docs], 2193dcb6a87598fa00c4eca62f33999df83a3a2e [Test] PUSHED.
Previous: 78318a2 / e282045 (D25 terms, preview, Q4 policy note).
--- History (older entries, not current) ---
(D25 entry) Status: COMPLETE. Store text uses 01 D25 words (밀가루/Flour, 제빵사, 제빵 대장); data/text ko/en checked against the Bread Defense list (0 hits); in-game ui.title = store working title. Working-title privacy preview (KIPRIS 미확인 banner, noindex, outside privacy_site/); template keeps {{APP_NAME}}. Q4 launcher name: Play rules checked (no match rule found), android:label NOT changed (still `Lane Defence`, 02's file). Q2 DEFERRED. Nothing published. Gate PASS. Nothing live.
(D25 entry) Next: see handoff.
(D25 entry) Validation: runner 9 suites → 502/0, 130/0, 161/0, listing 1775/0 (game_text_overlap 280, privacy_preview 14, launcher_label_note 11), m8 26/0, m10 81/0, android 176/0, upgrade 285/0, integration PASS_INTEGRATED 156/0; OVERALL exit=0. 10 mutations caught (01's data/text via temp copies only).
Commits: 78318a24d4ff5393b7135ad7b778660e17d9adc8 [Docs] (docs + lint together so no commit is red) PUSHED.
Previous: f59587c / 8f58a1c / b395f02 (.uid audit, upgrade isolation).
Previous status (.uid audit): COMPLETE. confirmed (Godot 4.4+ article: commit them); repo audit: 12 untracked .uid left for 02 (2), 04 (3), 07 (7, incl. probe_balance with untracked script); 10 committed its 4 (e340144); 06's 4 committed. (2) 02 Save.buy_upgrade / App cmd_buy_upgrade / 04 panel verified separate from Services/ads/billing (test_services_upgrade 285/0, 8 mutations caught). (3) Privacy hosting NOT executed; one user-question candidate sent to 01. Q2 DEFERRED. Gate PASS. Nothing live.
(.uid audit) Next: see handoff.
(.uid audit) Validation: runner 9 suites, m8 26/0, m10 81/0, android 176/0 (incl. godot_uid_tracked), upgrade 285/0, integration PASS_INTEGRATED 156/0 binding=game; OVERALL exit=0.
Commits: f59587cc763c4bc7fdaf8c9b8c35101d3e9fd7a8 [Test], 8f58a1c22c53253883a43dc5d570517afd0076db [Docs] PUSHED.
Previous: backup study 5fc46e1 / 082e9ca / 104c5b9.
Q3: f0d80e0a27692cdb891ff5b56f5ea67afd3dc334 PUSHED (listing, KIPRIS_MANUAL_CHECK, NAME_SEARCH_LOG, OPEN_DECISIONS U9, lint).
Older M4 line (kept): commits 7fe59f9 / 47c187b; integration then exit=2 BLOCKED (resolved in M8).
Dependencies: 02 S1 (blocking), S3 when 01 enables placements; 01 Q2–Q5 + retention; 07 runs the gate.
M5: 56cd600e628f3acb092ba461c58b6ae80635db4e PUSHED; runner OVERALL exit=2 (integration 146/0, blockers I1–I4). Open gap: rewarded late-callback drop vs AdMob policy (DD1 → 01).
M6: 3afb2592fd3f051fdc9cf990ea07e3f279c1b715 PUSHED; runner OVERALL exit=2 (listing 615/0).
Quota: 13.72% of 10000.
M7: 996952fb43a2e34e36b1043aca7c052c301ac1c8 PUSHED; runner OVERALL exit=2 (listing 783/0, integration 146/0 + blockers I1–I4).
M8: d33a27bc22c33279f67a2134257e9ec7a5a10b6d PUSHED; runner OVERALL exit=0 (integration PASS_INTEGRATED 156/0).
M9: 82108f86b612c1dbc5bae725be58a72cfea90d42 PUSHED; runner OVERALL exit=0 (listing 968/0 incl. billing_docs 75).
M10: 710384033c8cf518f83b5ea6afd81776ba0a898b PUSHED; runner OVERALL exit=0 (m10 81/0).
M11: e5099bdd7b911bd703ae9866b125c28173fde197 PUSHED; runner OVERALL exit=0 (listing 1024/0).
M12: 98e757b15ce2e30dba6b2426715dd58115af22bb PUSHED; runner OVERALL exit=0 (listing 1087/0).
Q3: f0d80e0a27692cdb891ff5b56f5ea67afd3dc334 PUSHED; runner OVERALL exit=0 (listing 1482/0). Quota 40.2% at start.
Backup study: 5fc46e1 + 082e9ca PUSHED; runner OVERALL exit=0 (android 91/0). Quota 45.2% at start.
UID/upgrade: f59587c + 8f58a1c PUSHED; runner OVERALL exit=0 (android 176/0, upgrade 285/0). Quota 50.4% at start.
