# 06-services status
Updated: 2026-10-31 16:58 KST (backup/restore study)
Status: BACKUP STUDY COMPLETE (desk study, **no device test**). Current build: allowBackup=false (Godot template), no dataExtractionRules/fullBackupContent, hasFragileUserData=false → save survives updates only. Options B0–B3 to 01 (06 rec. B0 now, B1 with Gradle). Data safety/privacy: no contradiction. Release preset: WAITING (04 R12-2 → 02). Q2 DEFERRED. Gate PASS. Nothing live.
Current task: none. Next: see handoff.
Validation (latest): runner → 502/0, m2 130/0, m3 161/0, listing 1483/0, m8 26/0, m10 81/0, android 91/0 (release_preset=WAITING, 2 APKs checked, aapt2 yes), integration PASS_INTEGRATED 156/0 binding=game; OVERALL exit=0. 12 android-check mutations each caught (exit 1); 02's export_presets.cfg never edited (temp copy via --presets=).
Backup: 5fc46e1854460885150ce773a355d7bc0f0f892d [Docs], 082e9ca45def5f0255cdd707de1f74eda59886a1 [Test] PUSHED.
Previous: Q3 follow-up f0d80e0 / c1ce3f5.
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
