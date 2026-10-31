# Failure triage (owner: 07-qa)
Updated 2026-10-31 09:18 +09:00. Scope: desktop headless Godot 4.7.2 on Windows. **Not Android release certification** (PLAT-03 NOT_TESTED; adb shows only `emulator-5580`).

## Two run conditions (never mixed)
| Condition | Command | Meaning of a FAIL |
|---|---|---|
| **HEAD** | `.\tools\qa\run_acceptance.ps1 -Head` | clean `git archive` of committed HEAD in `%TEMP%\qa07_head` (own import, current tests overlaid) → **committed defect** |
| **Workspace** | `.\tools\qa\run_acceptance.ps1` | shared tree with every worker's uncommitted WIP → only here = **work-tree contamination** |

## Current: HEAD 5426645, run 20261031-091441
PASS 137 · FAIL 6 · NOT_IMPLEMENTED 1 (MON-04) · NOT_TESTED 2 (AUD-03, PLAT-03) · BLOCKED 0; services suites exit 0. Summary: runs/head-5426645.md.
| Check | Bug | Owner | Cause | Reproduce | Pass criterion |
|---|---|---|---|---|---|
| DATA-13, DATA-14 | QA-B008 P2 | 01 | `toast.counterattack/save_recovered/round_locked/save_failed/save_read_only` used in src, absent from data/text ko+en | `-Head -Only data` | both PASS; FLOW-04B stays PASS |
| TH-FIT-HUD-EN | QA-B009 P2 | 04 (cc 01) | 5-card rounds r08–r10 leave a 36.7 px label slot; EN names 37–42 px | `-Head -Only theme` | every drawn card/skill label fits, no ellipsis (KO and EN) |
| TH-FIT-ROUND-EN | QA-B010 P2 | 04 (cc 01) | 83 px round tile; 7/10 EN names longer | `-Head -Only theme` | no ellipsis (KO and EN) |
| TH-COL-PROTAN, TH-COL-DEUTAN | QA-B011 P2 (proxy) | 03 | archer vs Warlord mean colour ΔE 1.18 / 2.24 after CVD simulation | `-Head -Only theme` | ΔE ≥ 2.3, or a CVD-simulated HEAD battle frame showing the marker separates them |

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
| FLOW-04B raw "counterattack" | 04/01 | 5426645 | FLOW-04B (DATA-13/14 still open) |

## Work-tree contamination
| Warning | Owner | Status |
|---|---|---|
| QA-W001 idle player survives r01/r02 with uncommitted round data | 01 | open in workspace; HEAD PASS |
| QA-W002 `_cue()` undefined broke battle.gd | 02 | resolved e9dfaa4 |
| QA-W003 `ui.star_*` text only in WIP | 01 | resolved (committed) |

## 07 harness corrections (not product defects)
- FLOW-22 depended on a ~50% bot win on r03 → forced win after 3 losses, flagged `forced_win` (e0ad672).
- TP-13a used 999 999 as the coin cap; data/meta.json gold max is 9 999 999 → check now reads meta.json.
- TH-FIT-HUD first measured skill names that the committed HUD does not draw (icon + cost on a < 54 px button) → check mirrors `TouchButton.show_name` and lists icon-only buttons in evidence.

## History
- HEAD 462991a (head-462991a): 12 FAIL. HEAD e9dfaa4 (20261031-083824/085129): same 12 FAIL.
