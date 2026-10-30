# 06-services status
Updated: 2026-10-31
Status: M1 COMPLETE (service boundaries + DISABLED/MOCK adapters + contract tests). Real ads/billing/analytics: NOT integrated, NOT live.
Current task: none in progress. Next: M2 (see handoff "Next task").
Completed files: src/services/** (22 .gd + 10 .uid), tests/services/test_services.gd, docs/services/{SERVICES,PRODUCTION_REQUIREMENTS,ANALYTICS_EVENTS}.md, requests 06-services-to-{01-director,02-engine,04-client}.md.
Validation evidence: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services.gd` → EXIT=0, passes=438 failures=0, 14/14 groups PASS, no WARNING/ERROR lines. Mutation check: disabling the mock verifier's environment gate made the suite fail (EXIT=1, 2 targeted failures); file restored, suite green again.
Commits: 17623c14e1b054d024e8029049b58d5fc373a93b PUSHED origin/main (ls-remote matches).
Dependencies: 01 decisions (Q2–Q5 + analytics), 02 save/autoload/grant sinks/battle_uid (S1–S5), 04 UI/consent/export after approval (U1–U5).
Quota: usage.json 79.16% at 06:56 (below 97% checkpoint).
