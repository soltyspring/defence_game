# Bug register (owner: 07-qa)
Severity: P0 crash/data loss/cannot progress · P1 core feature broken, no workaround · P2 wrong behaviour with workaround · P3 cosmetic.
Triage of every current FAIL (owner, cause, command, expected; HEAD vs workspace): [FAILURE_TRIAGE.md](FAILURE_TRIAGE.md).
Status: OPEN → FIX_CLAIMED (owner says fixed) → VERIFIED (same scenario re-run PASS) / REOPENED.
Runs named `head-<sha>` / made with `run_acceptance.ps1 -Head` test a clean `git archive HEAD` snapshot (other workers' uncommitted WIP excluded). Plain timestamp runs test the shared workspace. Evidence run IDs refer to `build/qa07/<run>/acceptance_report.json` (local, git-ignored); the summary of each cited run is committed under `docs/verification/runs/`.

| ID | Sev | Owner | Status | Check | Summary |
|---|---|---|---|---|---|
| QA-B001 | P2 | 04 (cc 02) | VERIFIED e5bd4aa (FLOW-23/23B PASS, run 20261031-090937) | FLOW-23, FLOW-23B | One Android back press is handled again by the screen mounted during the same notification walk |
| QA-B002 | P3 | 04 (cc 02) | VERIFIED e5bd4aa (FLOW-13B PASS) | FLOW-13B | HUD pause menu is shown underneath the result panel |
| QA-B003 | P2 | 02 | VERIFIED e5bd4aa (SAVE-05/06 PASS) | SAVE-05/06 | Save migration keeps wrong-typed `stars`/`best_time`; next `record_result` hits a script error and the result is not saved |
| QA-B004 | **P1** | 02 | VERIFIED e5bd4aa (TP-02a/b PASS, fix 08ef082) | TP-02a, TP-02b | After one recovery from `.bak`, the next save rotates the corrupt main into `.bak` and deletes the only good copy; a kill during that save resets progress to fresh with `recovered=false` |
| QA-B005 | P2 | 02 (cc 04) | VERIFIED e5bd4aa (TP-14b PASS) | TP-14b | A failed save (storage full / unwritable) is silent: `save_progress` returns false, only `last_error` is set, no toast/signal |
| QA-B006 | P3 | 02 | VERIFIED e5bd4aa (TP-06 PASS) | TP-06 | A save from a newer build (version 99) is rewritten as version 1 on the next save (replaces QA-O003) |
| QA-B007 | P3 | 02 | VERIFIED e5bd4aa (TP-13a PASS after 07 check fix, run 20261031-091123) | TP-13a/c | No range clamp on load (`unlocked_round`=1e12 unlocks everything, coins 9 999 999 999, stars "x"/99 kept); no size guard (50 MB save parsed in 6.8 s on desktop) |
| QA-B008 | P2 | 01 (cc 04) | VERIFIED abe2303 (DATA-13/14 PASS, fix 14b01e2) | DATA-13/14, FLOW-04B | Engine toast keys `counterattack`, `save_recovered`, `round_locked` have no `toast.*` text in ko/en; HUD shows the raw id "counterattack" in battle (r01 triggers it at 50% enemy base hp) |
| QA-B009 | P2 | 04 (cc 01) | VERIFIED abe2303 (TH-FIT-HUD-EN PASS) | TH-FIT-HUD-EN | English card labels ellipsised at the narrowest HUD (36.7 px slot, r08–r10) |
| QA-B010 | P2 | 04 (cc 01) | VERIFIED abe2303 (TH-FIT-ROUND PASS, 2-line wrap; render not checked) | TH-FIT-ROUND-EN | 7/10 English round names ellipsised in round select (83 px tile) |
| QA-B011 | P2 (proxy) | 03 | VERIFIED 3b2d830 (TH-COL-* PASS, closest ΔE 19–25 after 7705aec; CVD-simulated r08 frame separable) | TH-COL-PROTAN/DEUTAN | Ally vs enemy colour separation under CVD |
| QA-B012 | P3 | 02 | OPEN | VISUAL C4 | Damage numbers: fallback font 8 px, up to 21 at once, stacked numbers merge and overlap HP bars |
| QA-B013 | P3 | 04 (cc 02) | OPEN | VISUAL C4 | Green/red base and unit HP bars indistinguishable under protan/deutan simulation |
| QA-W001 | — | 01 | RESOLVED 2884231 (D18, cbfb0a8; R1/R2-LOSS PASS) | R1-LOSS, R2-LOSS | Workspace run 20261031-074155 only: with 01's uncommitted round edits (enemy_ai disabled), an idle player in r01/r02 no longer loses (base 1310/1500, 1365/1500 at the 900 s limit). Committed HEAD 462991a passes R1/R2-LOSS. Blocks commit of that data change unless intended |
| QA-W002 | — | 02 | RESOLVED 2026-10-31 (e9dfaa4) | FLOW-03 | Uncommitted `_cue()` call broke battle.gd compile in workspace run 20261031-080624. 02 committed the audio cue integration in e9dfaa4; battles start at HEAD and in workspace; AUD-02 PASS |
| QA-W003 | P2 at HEAD | 01 (cc 04) | RESOLVED (ui.star_* committed) | DATA-13/14 | Committed result.gd (183e4a6) uses `ui.star_win/star_base_hp/star_base_hp_any/star_time/star_time_any`; the text exists only in 01's uncommitted ko/en edits, so HEAD shows raw ids |

## QA-B001 — Android back is consumed twice (P2, owner 04, cc 02)
- Repro (run 20261031-072353): finish any round → result screen → press Android back once. Or: open round select → press back once.
- Expected: result → round select (result.gd intent); round select → main menu, quit dialog closed.
- Actual: result → round select → **main menu** (`screen_changed` = `["round_select","menu"]`); round select → main menu **with the quit dialog open** (`quit_layer.visible=true`).
- Mechanism: Godot 4.7.2 delivers back via `Window::_propagate_window_notification` (scene/main/window.cpp, verified at tag 4.7.2-stable), which walks children by live index. `result.gd`/`round_select.gd` `_notification` emit `cmd_open_screen` synchronously, `App.show_screen` appends the new screen to the UI layer, and the walk then delivers the same back press to the new screen.
- Player impact: back skips a screen; on round select a single back opens "quit game?". Every Android device.
- Suggested fix: handle back once per press (e.g. `call_deferred` the navigation in UI `_notification`, or a per-frame back latch in App/`_ui_handles_back`). Acceptance: FLOW-23 nav `["round_select"]` with `round_select.gd` mounted; FLOW-23B nav `["menu"]`, quit dialog hidden.

## QA-B002 — pause overlay under result (P3, owner 04, cc 02)
- Repro: win or lose → result screen shown → inspect HUD under the result.
- Expected: HUD pause layer hidden (HUD hides it on `battle_ended`).
- Actual: `hud.pause_layer.visible == true` while the result is up.
- Mechanism: `App._show_result` sets `battle.sim.paused = true` directly; the battle keeps publishing `hud_snapshot` with `paused=true` at 10 Hz and `hud._on_snapshot` maps it to `_on_paused(true)`, re-showing the pause overlay after `_on_battle_ended` hid it.
- Impact: "Paused" title and Resume/Retry/Settings/Menu buttons are drawn under the semi-transparent result dim (input is blocked by the result root). Visual clutter on every result.
- Fix options: HUD ignores snapshot `paused` after `battle_ended` (04), or App stops publishing/marks snapshots as ended (02). Acceptance: FLOW-13B PASS.

## QA-B003 — wrong-typed save fields survive migration (P2, owner 02)
- Repro (SAVE-05): checksum-valid envelope with payload `{"version":1,"unlocked_round":"abc","coins":-50,"stars":[3,2],"best_time":null,"settings":"loud"}` → `Save.load_progress()`.
- Expected: every field coerced to its schema type (stars/best_time/settings → Dictionary, coins ≥ 0, unlocked ≥ 1).
- Actual: `unlocked_round`, `coins`, `settings` are fixed, but `stars` stays Array and `best_time` stays null. `record_result()` then calls `progress.stars.get(...)` / `progress.best_time.get(...)` → script error, the win is not recorded or saved.
- Source of such files: older builds, manual edits, cloud/device restore, partial migrations.
- Fix: in `Save._migrate`, replace any key whose type differs from `fresh()` with the default (and drop non-numeric star values). Acceptance: SAVE-05 PASS and SAVE-06 (record_result persists stars/unlock) PASS.

## QA-B004 — backup rotation destroys the only good copy (P1 data loss, owner 02)
Evidence run 20261031-074155 (suite_faults.gd). Reported independently by 10-research-systems as SV-1 (code reading); this is the executed reproduction.
- Steps: save twice (main = B, .bak = A) → corrupt main → `load_progress()` (recovers A from .bak, `recovered=true`) → `save_progress()`.
- Expected: a valid backup still exists after the save.
- Actual: `save_progress` deletes the valid .bak and renames the corrupt main into .bak (TP-02a: .bak invalid). A second corruption of main now loses everything. If the process dies after the bak rename and before the final rename (state rebuilt from real save output), reload gives **fresh progress, unlocked_round 1, recovered=false**: the player loses all progress and is not told (TP-02b).
- Fix direction: never rotate an unreadable main into .bak (validate main before rotating, else keep the current .bak); on load, also consider a verified `.tmp`. Acceptance: TP-02a and TP-02b PASS; TP-01 stays PASS.

## QA-B005 — silent save failure (P2, owner 02, cc 04)
- Steps: make `<save>.tmp` unwritable (TP-14 uses a directory with that name) → change progress → `save_progress()`.
- Actual: returns false, previous file intact (TP-14a PASS), but nothing reaches the player (no `toast`/signal). On a full phone the player keeps playing and loses the session's progress on exit.
- Fix: emit e.g. `Events.toast("save_failed", {})` (and keep retrying on next save); 04 shows it. Acceptance: TP-14b PASS.

## QA-B008 — raw "counterattack" text in battle (P2, owner 01, cc 04)
- Steps: start r01, bring the enemy base below 50% (`enemy_base_spawns_on_hp`) → battle.gd emits `toast("counterattack")`. FLOW-04B emits each engine toast key into the live HUD.
- Actual: HUD toast label shows `counterattack` (no `toast.counterattack` in data/text, 04 fallback table lacks it). `toast.save_recovered` and `toast.round_locked` are also missing (not visible today: no HUD is mounted when they fire).
- Fix: add the three `toast.*` keys to ko.json and en.json. Acceptance: DATA-13, DATA-14, FLOW-04B PASS.

## Observations (not defects; routed for decision)
| ID | Owner | Note |
|---|---|---|
| QA-O001 | 01 (cc 02) | Scripted-bot win rate, 20 seeds each (probe_winrate.gd, 2026-10-31): r01 casual 17/20, competent 17/20; r02 20/20 and 20/20; **r03 casual 10/20, competent 11/20**. The r03 step is steep relative to r01–r02, and the "competent" bot is no better than casual (it wins later: r01 median ≈ 155 s vs ≈ 118 s). Bot behaviour is not human evidence; flagged as a difficulty-curve hypothesis to test. |
| QA-O002 | 02 | Interrupted rename (main missing, valid newer `.tmp`, older `.bak`) restores `.bak`; the verified `.tmp` is discarded (SAVE-03). Acceptable, loses the last write. |
| QA-O003 | 02 | Superseded by QA-B006 (TP-06 asserts byte-identical preservation as requested by 10-research-systems). |

## Verified (resolved before or during first acceptance)
- Android back in battle toggles pause exactly once (FLOW-12 PASS; 02 added `_ui_handles_back`).
- P0 sprite names, projectile/fx kinds, biome id and card/skill icons all resolve at runtime (ART-03..08 PASS at run 20261031-072353. Files read at about 06:45 had mismatched ids, e.g. data `anim_set` "melee_basic" vs manifest "unit_melee_basic" and round biome "biome_01" vs manifest "meadow"; owners changed them before the first automated run, so no bug was filed.)
