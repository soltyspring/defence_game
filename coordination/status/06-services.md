# 06-services status
Updated: 2026-10-31 (Q3 follow-up)
Status: Q3 FOLLOW-UP COMPLETE. Working title (user 16:19 KST) in the store listing; Bread Defense wording blocked by lint; KIPRIS class 9/41 manual procedure ready, **search NOT DONE** (person needed). Q2 DEFERRED (16:09). Gate PASS (exit 0, binding=game). Nothing live; disabled mode; no monetization UI.
Current task: none. Next: see handoff.
Validation (latest): `pwsh -File tests/services/run_services_suites.ps1` → 502/0, m2 130/0, m3 161/0, listing 1482/0 (competitor_overlap 279, kipris_manual_check 222), m8 26/0, m10 81/0, integration PASS_INTEGRATED 156/0 binding=game; OVERALL exit=0. 16 listing mutations each caught (exit 1), files restored.
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
