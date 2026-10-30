# Failure triage (owner: 07-qa)
Updated 2026-10-31 08:55 +09:00. Scope: desktop headless Godot 4.7.2 on Windows. **Not Android release certification** (PLAT-03 NOT_TESTED; adb shows only `emulator-5580`).

## Two run conditions (never mixed)
| Condition | Command | What it tests |
|---|---|---|
| **HEAD** | `.\tools\qa\run_acceptance.ps1 -Head` | clean `git archive` of the committed HEAD in `%TEMP%\qa07_head`, own import; current `tests/acceptance/*.gd` overlaid. A FAIL here is a **committed defect**. |
| **Workspace** | `.\tools\qa\run_acceptance.ps1` | the shared working tree including every worker's uncommitted WIP. A FAIL only here is **work-tree contamination** (WIP), not a product defect yet. |

Runs: HEAD e9dfaa4 = `20261031-083824` (all suites) + `20261031-085129` (flow re-run after harness fix). Workspace = `20261031-085305` (HEAD e9dfaa4 + 20 dirty src/data paths). Earlier HEAD 462991a = `head-462991a`.

## The 12 committed failures at HEAD e9dfaa4
Same 12 IDs as at HEAD 462991a. None was fixed by the commits in between (0333cd3, 5d61d0d, c49de70, 183e4a6, e9dfaa4).
| # | Check | Bug | Owner | Cause (mechanism) | Reproduce | Expected |
|---|---|---|---|---|---|---|
| 1 | DATA-13 | QA-B008 | 01 (cc 04) | `toast.counterattack/save_recovered/round_locked` and (HEAD only) `ui.star_win/star_base_hp/star_base_hp_any/star_time/star_time_any` used in src but absent from committed `data/text/ko.json` | `-Head -Only data` | every `ui.*`/`toast.*` key in src exists in ko.json |
| 2 | DATA-14 | QA-B008 | 01 | same keys absent from en.json | `-Head -Only data` | same for en.json |
| 3 | FLOW-04B | QA-B008 | 01 (cc 04) | HUD falls back to the raw key; label reads `counterattack` | `-Head -Only flow` | localised text for all engine toast keys |
| 4 | SAVE-05 | QA-B003 | 02 | `Save._migrate` fills only missing keys; wrong-typed `stars` (Array) and `best_time` (null) are kept | `-Head -Only save` | stars/best_time/settings are Dictionaries, coins ≥ 0 |
| 5 | TP-02a | **QA-B004 P1** | 02 | `save_progress` deletes the valid `.bak` and renames the unreadable main into `.bak` | `-Head -Only faults` | a valid backup exists after recovery + one save |
| 6 | TP-02b | **QA-B004 P1** | 02 | kill after bak rename, before final rename → main missing, `.bak` corrupt, verified `.tmp` ignored → fresh progress, `recovered=false` | `-Head -Only faults` | progress kept (unlocked ≥ 2) |
| 7 | TP-06 | QA-B006 | 02 | `_migrate` forces `version = 1`; next save rewrites a v99 file | `-Head -Only faults` | newer-version file byte-identical |
| 8 | TP-13a | QA-B007 | 02 | no range clamp on load | `-Head -Only faults` | unlocked ≤ rounds+1, coins ≤ 999999, stars int 0..3 |
| 9 | TP-14b | QA-B005 | 02 (cc 04/01) | write failure sets only `last_error`; no toast/signal | `-Head -Only faults` | player is told (e.g. `toast("save_failed")`) |
| 10 | FLOW-13B | QA-B002 | 04 (cc 02) | `App._show_result` sets `sim.paused=true`; HUD maps snapshot `paused` to its pause overlay after `battle_ended` hid it | `-Head -Only flow` | `hud.pause_layer.visible == false` under result |
| 11 | FLOW-23 | QA-B001 | 04 (cc 02) | back handler navigates synchronously inside `Window::_propagate_window_notification`; the newly mounted screen receives the same press | `-Head -Only flow` | one back on result → round select only |
| 12 | FLOW-23B | QA-B001 | 04 (cc 02) | same, round select → menu also toggles menu quit dialog | `-Head -Only flow` | menu shown, quit dialog hidden |
Plus SAVE-06 BLOCKED by #4 (would hit a script error).
Counts at HEAD e9dfaa4 after the harness fix below: **PASS 120 · FAIL 12 · NOT_IMPLEMENTED 1 · NOT_TESTED 2 · BLOCKED 1**, services suites exit 0 (computed from 083824 with FLOW-22 replaced by the 085129 re-run).

## Work-tree contamination (workspace only; not filed as product bugs)
| Warning | Owner | Seen in | Status |
|---|---|---|---|
| QA-W001 | 01 | R1-LOSS, R2-LOSS FAIL in workspace 20261031-085305 (idle player base 1310/1500 and 1365/1500 at the 900 s limit) | still present in uncommitted r01–r10 edits; HEAD passes. Becomes a product bug if committed as is |
| QA-W002 | 02 | FLOW-03 (battle.gd failed to compile, `_cue()` undefined) in workspace 20261031-080624 | **resolved**: 02 committed the audio-cue integration in e9dfaa4; HEAD and workspace both start battles; AUD-02 now PASS |
| QA-W003 | 01 | DATA-13/14 in workspace list only the 3 toast keys; HEAD also lists 5 `ui.star_*` keys | 04 committed result.gd using `ui.star_*` (183e4a6) while the text keys exist only in 01's uncommitted ko/en files. Commit-ordering gap: HEAD shows raw `ui.star_*` ids until 01 commits |

## Harness defect found and fixed by 07 (not a product failure)
- FLOW-22 failed at 083824 because the scripted competent bot lost r03 three times (bot win rate at HEAD e9dfaa4: r03 10/20 competent, 14/20 casual; r01 15/20, 18/20; r02 20/20 both; `probe_winrate.gd --seeds=20`). A navigation test must not depend on a ~50% bot. `suite_flow.gd::_win_current` now, after three bot losses, ends the retried battle by destroying the enemy base and marks the result `forced_win=true` (shown in the FLOW-22 title). Re-run 085129: FLOW-22 PASS with `forced_win=false`. Bot difficulty remains observation QA-O001.

## Re-verification rule
When 02, 03 or 04 claim a fix (save, back navigation, fonts/icons/clipping), 07 re-runs **the same check IDs under the HEAD condition** after the fix is committed, and records the run ID here and in HOSTILE_REVIEW §5. Uncommitted fixes are not verified.
