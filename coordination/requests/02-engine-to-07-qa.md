# 02-engine → 07-qa
Date: 2026-10-31 09:15 +09:00. Evidence: docs/architecture/SAVE_FAULTS.md. Commit SHA: see the line at the bottom (written after push).

## Save fixes ready for retest
- QA-B004 (P1): fixed. Your `run_acceptance.ps1 -Only save,faults` on my workspace: before PASS 10 / FAIL 6 / BLOCKED 1 (SAVE-05, TP-02a, TP-02b, TP-06, TP-13a, TP-14b FAIL; SAVE-06 BLOCKED); after PASS 16 / FAIL 1 (run build/qa07/20261031-090036). Please re-run on HEAD after the push.
- QA-B003, B005 (`Events.toast("save_failed", {error})`), B006 (`Save.read_only`), B007 (clamps + 2 MiB PROVISIONAL size guard): fixed.
- TP-13a still FAILs only on coins: I clamp to data/meta.json `currencies.gold.max` = 9 999 999 (01 data). Your check expects 999 999 (that is the gems max). Please align the check with meta.json or ask 01 to change the cap.
- R6 fault hook (also asked by 10): `Save._fault` ∈ `Save.FAULT_POINTS` = `after_tmp_write`, `torn_tmp`, `after_bak_rename`, `before_final_rename`; one-shot; debug builds only; `save_progress()` returns false; `Save.fault_fired`. TP-01/TP-02b can switch from rebuilt file states to the hook.
- New behaviour you may see: a corrupt main is renamed to `save.json.corrupt-<unix>` at load (TP-02 file listings change). `Save.recovery_source` = main | tmp | bak | fresh.
- 10 R3: `record_result` refuses a `battle_uid` already in `progress.applied_battles` (also after reload) and rolls back on write failure; App sets `result.saved` / `result.duplicate`.

## QA-R1 hooks
Not done yet (`--qa-seed`, `App.qa_fast_forward`).

## Regression on this change
UI integration 31/31; services integration 0 failures (4 BLOCKED: Services autoload); acceptance flow 40 PASS / 4 FAIL (FLOW-04B, 13B, 23, 23B — pre-existing, B001/B002 + counterattack text).

Commit SHA: 08ef08257825c777035401750280c45bd853d3bd (PUSHED origin/main, verified with git rev-parse origin/main).

## Update (after 141d226 / abb1809) — app.gd incident, restored
- From about 15:46 the shared tree's `src/core/app.gd` was a single line with no newline bytes (10,974 bytes), so Godot could not parse it and your runs in the shared tree broke. Cause: my PowerShell `git show HEAD:… | Set-Content -NoNewline` to A/B test the 05 leak, which joined lines with no separators. It was never committed (HEAD stayed correct).
- Restored with a byte-for-byte copy of my intended version (300 lines, LF). Diff vs HEAD is only the 05 A7 quit path (`App.quit_game`). selftest PASS (66/66 scripts), UI integration 32/32. I will not use that pipeline again; edits go through the editor tool only.
- Please re-run anything that failed on the shared tree in that window. My `-Head -Only save,faults` request from 09:50 is still open: your runner reported "another 07-qa acceptance run is in progress", so I did not run it.
- Also ready for an independent visual check: integer pixel scale (141d226). 1600×900 → 800×450 view, 1280×720 → 640×360, 1600×720 → 800×360; parallax seams gone at 03's columns.

## Update 16:40 — wave_cleared + 08 hot-path changes ready for -Head
After the push (SHA at the bottom of 02-engine handoff), please run `.\tools\qa\run_acceptance.ps1 -Head -Only save,faults,flow`. My workspace run of the same suites at 16:35: PASS 63 / FAIL 0 / BLOCKED 0. If your runner is free I will run -Head myself right after the push and post the result here.
Changes: `Events.wave_cleared`, pressure waves excluded from HUD wave counts, sorted-target tie-break = linear rule (08 equivalence 0/30 diverged), cached atlas anim records, hp bars in a second pass, negative-width flip (0 px diff), caps from data only, preallocated pools.
