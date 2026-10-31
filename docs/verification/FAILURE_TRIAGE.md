# Failure triage (owner: 07-qa)
Updated 2026-10-31 09:18 +09:00. Scope: desktop headless Godot 4.7.2 on Windows. **Not Android release certification** (PLAT-03 NOT_TESTED; adb shows only `emulator-5580`).

## Two run conditions (never mixed)
| Condition | Command | Meaning of a FAIL |
|---|---|---|
| **HEAD** | `.\tools\qa\run_acceptance.ps1 -Head` | clean `git archive` of committed HEAD in `%TEMP%\qa07_head` (own import, current tests overlaid) → **committed defect** |
| **Workspace** | `.\tools\qa\run_acceptance.ps1` | shared tree with every worker's uncommitted WIP → only here = **work-tree contamination** |

## Current: HEAD fca9346, run 20261031-183232 (import guard 0 missing)
PASS 152 · FAIL 0 · NOT_TESTED 2 (AUD-03, PLAT-03) · BLOCKED 0; services exit 0. Non-automated open findings: QA-B012 (reopened), QA-B013 (world bars), QA-B017, QA-B018, QA-J1 (visibility target), D28 5/9 FAIL, QA-W004 waiting (OPEN_DEFECTS.md).

## Verified fixed (same check IDs, HEAD condition)
| Bug | Fix commit | Verified at | Checks |
|---|---|---|---|
| QA-B004 P1 backup rotation data loss | 08ef082 (02) | e5bd4aa, 5426645 | TP-02a, TP-02b (TP-01 still PASS) |
| QA-B003 save types | 08ef082 | e5bd4aa | SAVE-05, SAVE-06 |
| QA-B005 silent save failure | 08ef082 | e5bd4aa | TP-14b |
| QA-B006 newer-version rewrite | 08ef082 | e5bd4aa | TP-06 |
| QA-B007 no clamp | 08ef082 | e5bd4aa (after 07 corrected its own coin cap to data/meta.json 9 999 999) | TP-13a |
| QA-B001 back handled twice | 04 (between e9dfaa4 and e5bd4aa) | e5bd4aa, 5426645 | FLOW-23, FLOW-23B |
| QA-B002 pause overlay under result | 04 | e5bd4aa, 5426645 | FLOW-13B |
| FLOW-04B raw "counterattack" | 04/01 | 5426645 | FLOW-04B |
| QA-B008 toast keys | 14b01e2 (01) | abe2303 | DATA-13, DATA-14 |
| QA-B009 EN card label clipping | 5a2099d / 14b01e2 (04/01) | abe2303 | TH-FIT-HUD-EN (KO also PASS) |
| QA-B010 round name clipping | 5a2099d (04: 2-line tiles) | abe2303 | TH-FIT-ROUND-KO/EN (check mirrors `wrap_lines=2` via `UiStyle.fit_lines`; 3 KO and 7 EN names wrap; 2-line vertical fit not rendered by 07) |

| QA-B011 CVD colour proxy | 7705aec (03) | 3b2d830 | TH-COL-NORMAL/PROTAN/DEUTAN/TRITAN |

| QA-B016 ui.upgrade_save_uncertain text | 01 | 09508b1 | DATA-13/14 |

## Work-tree contamination
| Warning | Owner | Status |
|---|---|---|
| QA-W001 idle player survives r01/r02 with uncommitted round data | 01 | resolved: D18 late waves committed (cbfb0a8); R1/R2-LOSS PASS at HEAD 2884231 |
| QA-W002 `_cue()` undefined broke battle.gd | 02 | resolved e9dfaa4 |
| QA-W003 `ui.star_*` text only in WIP | 01 | resolved (committed) |

## 07 harness corrections (not product defects)
- FLOW-22 depended on a ~50% bot win on r03 → forced win after 3 losses, flagged `forced_win` (e0ad672).
- TP-13a used 999 999 as the coin cap; data/meta.json gold max is 9 999 999 → check now reads meta.json.
- TH-FIT-HUD first measured skill names that the committed HUD does not draw (icon + cost on a < 54 px button) → check mirrors `TouchButton.show_name` and lists icon-only buttons in evidence.

## History
- HEAD abe2303 (20261031-154903): 2 FAIL (TH-COL-PROTAN/DEUTAN).
- HEAD 2884231 (20261031-153757): 6 FAIL; HEAD 231cfda (154410): 4 FAIL before 07 mirrored the 2-line tile rule.
- HEAD 5426645 (20261031-091441): 6 FAIL (same IDs; QA-B011 pair archer vs boss_warlord).
- HEAD 462991a (head-462991a): 12 FAIL. HEAD e9dfaa4 (20261031-083824/085129): same 12 FAIL.
