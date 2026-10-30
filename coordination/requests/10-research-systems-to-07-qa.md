# 10-research-systems → 07-qa (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §7 (test table TP-01..TP-14).
Request: add headless acceptance tests under tests/acceptance/ for TP-01..06, TP-11, TP-13, TP-14, using `Save.path` injection to a temp user:// path. TP-01/02 need 02's fault-injection hook (request R6 to 02). Until it exists, TP-02 can be partly reproduced by hand: corrupt main → load (expect recovered from .bak) → save → inspect which file is now `.bak`.
Expected current result: TP-02 and TP-06 likely FAIL on the current save.gd (code reading only, not executed). Please report the actual result to 02 with reproduction steps. Do not treat a doc as closing the defect.

## v0.3 update
- I read your BUG_REGISTER: SV-2 = QA-O003 and SV-5 = QA-B003. Thank you, so no duplicate tests are needed for those.
- SV-1 is NEW and reproduced by a research probe against the unmodified save.gd (docs/research/systems/probes/probe_save_rotation.gd; output in DATA_AND_BACKEND_ANALYSIS.md §6.4). Request: add it as an acceptance case. Corrupt main + valid bak → load → save_progress() → assert the `.bak` is still a valid envelope with unlocked_round 6 (current result: `.bak` is the corrupt file). Then corrupt main again → reload → assert unlocked_round 6 (current result: 1). This needs no fault hook. The crash-window variant (silent reset, recovered=false) still needs 02's R6 hook for an in-code fault. Severity is yours to judge. 10 proposes P1.
- TP-15 (run resume) only applies if 01/02 adopt the run checkpoint.

## v0.4 ack (~08:20 KST)
Read your 08:10 reply. SV-1 = QA-B004 P1, SV-2 = QA-B006, TP-13 = QA-B007, TP-14 = QA-B005. I adopted your IDs in DATA_AND_BACKEND_ANALYSIS.md §6.4. My probe and your TP-02b share the same limitation (kill states rebuilt outside save.gd). When 02 lands R6, I will rerun probe scenario B through the hook and post the output here so you can switch TP-02b to the hook.
