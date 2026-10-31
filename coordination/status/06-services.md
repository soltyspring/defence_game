# 06-services status
Updated: 2026-10-31 (M11)
Status: M11 COMPLETE (Data safety "No" confirmed for the disabled build vs 04 APK check; legal display proposal to 04; Q2 option costs to 01). Gate PASS (exit 0, binding=game). Nothing live; disabled mode; Q2 pending.
Current task: none. Next: see handoff.
Validation: `pwsh -File tests/services/run_services_suites.ps1` → test_services 502/0, m2 130/0, m3 161/0, integration exit=2 BLOCKED_NOT_INTEGRATED (71 passes, 0 failures, blockers I1–I4); OVERALL exit=2. Simulated integration run exit=2 with I2 PASS_SIMULATED, I3/I4 PASS. 4 gate mutations each caught (exit 1), files restored.
Commits: 7fe59f926674961e1e7c872294ca6044009e04d0 (gate code/tests/contract docs) PUSHED origin/main; diff vs origin empty. Docs/requests/handoff: 47c187bd2e39947a0584b893878dc3cb91e778eb PUSHED origin/main.
Dependencies: 02 S1 (blocking), S3 when 01 enables placements; 01 Q2–Q5 + retention; 07 runs the gate.
M5: 56cd600e628f3acb092ba461c58b6ae80635db4e PUSHED; runner OVERALL exit=2 (integration 146/0, blockers I1–I4). Open gap: rewarded late-callback drop vs AdMob policy (DD1 → 01).
M6: 3afb2592fd3f051fdc9cf990ea07e3f279c1b715 PUSHED; runner OVERALL exit=2 (listing 615/0).
Quota: 13.72% of 10000.
M7: 996952fb43a2e34e36b1043aca7c052c301ac1c8 PUSHED; runner OVERALL exit=2 (listing 783/0, integration 146/0 + blockers I1–I4).
M8: d33a27bc22c33279f67a2134257e9ec7a5a10b6d PUSHED; runner OVERALL exit=0 (integration PASS_INTEGRATED 156/0).
M9: 82108f86b612c1dbc5bae725be58a72cfea90d42 PUSHED; runner OVERALL exit=0 (listing 968/0 incl. billing_docs 75).
M10: 710384033c8cf518f83b5ea6afd81776ba0a898b PUSHED; runner OVERALL exit=0 (m10 81/0).
M11: e5099bdd7b911bd703ae9866b125c28173fde197 PUSHED; runner OVERALL exit=0 (listing 1024/0).
