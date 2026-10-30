# Bug register (owner: 07-qa)
Severity: P0 crash/data loss/cannot progress · P1 core feature broken, no workaround · P2 wrong behaviour with workaround · P3 cosmetic.
Status: OPEN → FIX_CLAIMED (owner says fixed) → VERIFIED (same scenario re-run PASS) / REOPENED.
Evidence run IDs refer to `build/qa07/<run>/acceptance_report.json` (local, git-ignored); the summary of each cited run is committed under `docs/verification/runs/`.

| ID | Sev | Owner | Status | Check | Summary |
|---|---|---|---|---|---|
| QA-B001 | P2 | 04 (cc 02) | OPEN | FLOW-23, FLOW-23B | One Android back press is handled again by the screen mounted during the same notification walk |
| QA-B002 | P3 | 04 (cc 02) | OPEN | FLOW-13B | HUD pause menu is shown underneath the result panel |
| QA-B003 | P2 | 02 | OPEN | SAVE-05/06 | Save migration keeps wrong-typed `stars`/`best_time`; next `record_result` hits a script error and the result is not saved |

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

## Observations (not defects; routed for decision)
| ID | Owner | Note |
|---|---|---|
| QA-O001 | 01 (cc 02) | Scripted-bot win rate, 20 seeds each (probe_winrate.gd, 2026-10-31): r01 casual 17/20, competent 17/20; r02 20/20 and 20/20; **r03 casual 10/20, competent 11/20**. The r03 step is steep relative to r01–r02, and the "competent" bot is no better than casual (it wins later: r01 median ≈ 155 s vs ≈ 118 s). Bot behaviour is not human evidence; flagged as a difficulty-curve hypothesis to test. |
| QA-O002 | 02 | Interrupted rename (main missing, valid newer `.tmp`, older `.bak`) restores `.bak`; the verified `.tmp` is discarded (SAVE-03). Acceptable, loses the last write. |
| QA-O003 | 02 | A save written by a newer build (version 99) loads and keeps progress, but is rewritten as version 1 on the next save (SAVE-08). Downgrade policy unspecified. |

## Verified (resolved before or during first acceptance)
- Android back in battle toggles pause exactly once (FLOW-12 PASS; 02 added `_ui_handles_back`).
- P0 sprite names, projectile/fx kinds, biome id and card/skill icons all resolve at runtime (ART-03..08 PASS at run 20261031-072353. Files read at about 06:45 had mismatched ids, e.g. data `anim_set` "melee_basic" vs manifest "unit_melee_basic" and round biome "biome_01" vs manifest "meadow"; owners changed them before the first automated run, so no bug was filed.)
