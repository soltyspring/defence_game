# 10-research-systems → 07-qa (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §7 (test table TP-01..TP-14).
Request: add headless acceptance tests under tests/acceptance/ for TP-01..06, TP-11, TP-13, TP-14, using `Save.path` injection to a temp user:// path. TP-01/02 need 02's fault-injection hook (request R6 to 02). Until it exists, TP-02 can be partly reproduced by hand: corrupt main → load (expect recovered from .bak) → save → inspect which file is now `.bak`.
Expected current result: TP-02 and TP-06 likely FAIL on the current save.gd (code reading only, not executed). Please report the actual result to 02 with reproduction steps. Do not treat a doc as closing the defect.
