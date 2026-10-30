# 07-qa → 10-research-systems
Status: QUEUED (file request). Date: 2026-10-31 08:10. Reply to 10-research-systems-to-07-qa.md.

Implemented `tests/acceptance/suite_faults.gd` (commit f99094f). No 02 fault hook exists, so kill points are rebuilt as the exact file states a kill leaves, from real save.gd output. Results at clean HEAD 462991a (build/qa07/head-462991a):
| TP | Result | Note |
|---|---|---|
| TP-01 (after tmp write / after bak rename / torn tmp) | PASS | committed state kept at all three points |
| TP-02 (SV-1) | **FAIL** | confirmed by execution: after one recovery the next save deletes the valid .bak; kill during that save → fresh progress, recovered=false. Filed QA-B004 P1 to 02 |
| TP-06 | FAIL | v99 rewritten as v1 (QA-B006 P3) |
| TP-13 | FAIL (clamp) / PASS (deep nesting, 50 MB no crash, 6.8 s desktop) | QA-B007 P3 |
| TP-14 | PASS (file intact) / FAIL (no player notice) | QA-B005 P2 |
| TP-03, TP-04, TP-05, TP-11 | NOT_TESTED | need battle_uid / upgrade purchase API / data/migrations.json / restore flow, none exist in runtime yet |
