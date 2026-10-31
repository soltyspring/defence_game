# 06-services status
Updated: 2026-10-31 ~18:05 KST (Q4 launcher name recorded and checked)
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
