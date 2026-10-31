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
| QA-B012 | P3 | 02 | VERIFIED 278d52b (fix 52f9fa3; capture_crowd r08 185 s: damage_number_overlaps 0 over 11 095 frames, 0 dropped, max 9 drawn; outlined numbers readable on light walls, evidence/visual8-278d52b). History: REOPENED fca9346 (1133 pairs; 10 px step vs 11 px rect); 07's 01:1x status line "code unchanged" was stale (true at 3e355a8, not after 52f9fa3) | VISUAL C4/V4 | Damage numbers: fallback font 8 px, up to 21 at once, stacked numbers merge and overlap HP bars |
| QA-B013 | P3 | 04 (cc 02) | PARTIAL fca9346 (HUD PASS; world bars hue-only) | VISUAL C4 | Green/red base and unit HP bars indistinguishable under protan/deutan simulation |
| QA-B014 | P3 | 01 | VERIFIED 97c8b9c for the 10 keys (c15e43a); new key split to QA-B016 | DATA-13/14 | 10 ui.upgrade* keys missing in data/text ko+en (renders only via 04 fallback) |
| QA-B015 | P2 (pre-check) | 04 (cc 01) | VERIFIED 97c8b9c (2-line title logo fits at 34+34 notch, 1x/2x, ko/en) | VISUAL C7 | Q3 EN title 'Bakery Knights: Mold Defense' 588 px > 572 px notch safe width at menu title font |
| QA-J3 | P2 | 04 | VERIFIED 68866e9 (C5) | VISUAL C5 | Worker vs soldier card + resource names |
| QA-B016 | P3 | 01 (cc 04) | VERIFIED 09508b1 (DATA-13/14 PASS) | DATA-13/14 | ui.upgrade_save_uncertain used in upgrade_panel.gd, missing in data/text ko+en |
| QA-B017 | P3 | 01 (cc 04) | OPEN (code reading, I) | wave HUD | Pressure waves (D18/D21) are excluded from the wave counter by contract, so after 'wave 3/3' more enemies arrive with no announcement or timer |
| QA-J2 | P2 | 01 | CLOSED by D24(a) (rule PASS 97c8b9c) | probe_r01_risk | r01 is a tutorial; idle loses <=300 s, active players win |
| QA-B018 | P3 | 01 | OPEN | VISUAL C15 | upgrade.supply_regen still '보급 증가' / 'Supply Boost' after the resource rename to 밀가루 / Flour |
| QA-W004 | — | 02/04 | WAITING | C16 | Re-read APK label on an APK exported from a committed HEAD (current debug APK predates 4b5926d) |
| QA-T001 | — | 07 | FIXED 2026-10-31 19:58 | probe_balance | 07 harness defect: bot called with dt=1/60 while calls were ~0.09 s apart (bot ~5x slow); produced the casual 0/10 rows at fca9346. Fixed; --legacy-dt control shows the effect (r05 casual LOW 0/10 legacy vs 8/10 fixed, same build) |
| QA-B019 | P3 (latent) | 01 (cc 04) | VERIFIED 278d52b (DATA-13/14 PASS, run 20261101-012951; fixes 01 4882771 key added, 04 1850c3f marker uses a fixed "m" and no key) | DATA-13/14 | `ui.distance_m` used by src/ui/threat_marker.gd:67 (04, 31164c8) was missing in data/text ko+en. Now unused by src; the ko/en entry stays (harmless) |
| QA-T002 | — | 07 | FIXED 23:4x; sim-only re-run on the same snapshot 43/43 PASS (BD-SPLASH player [37.5], enemy [0.0]) | BD-SPLASH | 07 test defect: the first BD-SPLASH used only a competent-bot run, in which the player tower never fired (player bolt list empty), so the check failed without a sim defect. Now: idle run for player bolts, competent run for enemy bolts |
| QA-T003 | — | 07 | FIXED 00:57; r10 low2r re-run 01:04 | run_d28.ps1 | 07 script defect: the local `$budgets` overwrote the `-Budgets` parameter (PowerShell names are case-insensitive), so every round after the first ran 'low' only and the r10 low2r D28 row was skipped. r01–r09 needed only 'low' |
| QA-B020 | P2 | 03 + 09-art-world | OPEN ad47eda (ART_BASELINE C3/W2) | art baseline | Hero blends into the street: hero ΔL* vs the pixels behind it 12.1 / 8.7 / 5.1 / 15.8 / 10.3 across the 5 battle scenes. Pass ≥ 15 in all |
| QA-B021 | P2 | 06-art-ui | OPEN ad47eda (ART_BASELINE U1) | art baseline | Card icons look alike on screen: closest pair mean-colour ΔE 0.6 (식빵병/통식빵), shape distance 5.0–9.2. Pass: each pair ΔE ≥ 10 normal and ≥ 8 deutan, or shape ≥ 12 |
| QA-B022 | P2 (provisional, J1 target missing) | 03 (cc 01, 02) | OPEN ad47eda (ART_BASELINE C1) | art baseline | Soldiers are 3.5–4.4 mm tall on a 393 dp phone (median visible height 20.5 px r06, 24.5 px r08). 07 line ≥ 5.0 mm until 01 sets J1 |
| QA-B023 | P3 | 03 (+ 09 for C5) | OPEN ad47eda (ART_BASELINE C2/C4/C5) | art baseline | Units against the lane: 11–67 % of units ΔL* < 15 (pass ≤ 10 %); r08 closest ally–enemy pair deutan ΔE 11.9 (pass ≥ 12); boss over the nest ΔL* 11.0 (pass ≥ 15) |
| QA-B024 | P3 | 03 | OPEN ad47eda (ART_BASELINE A1/A1c/A5) | art anim | e_brute (멧돼지) slides instead of walking: walk edge travel/bob 0 px, 14 % of the silhouette changes between walk frames, death silhouette change 21.5 %; tank walk motion 1 px. Pass A1 ≥ 2 px, A1c ≥ 20 %, A5 ≥ 40 % |
| QA-B025 | P3 | 02 (fade) + 03 (timing) | OPEN ad47eda (ART_BASELINE A6/A6b) | art anim | Deaths fade before they play: the linear 0.7 s fade hides the second half of 0.62–1.0 s death animations; readable only 0.25–0.50 s and 40–80 % of frames. Pass A6 ≥ 0.4 s and A6b ≥ 60 % of frames |
| QA-B026 | P2 | 02 (field) + 04 (marker) (cc 01 D39) | OPEN e2404af (code reading; LAYOUT L6) | layout | Off-screen threat markers are never shown: hud.gd reads `snapshot.threat`, which no engine code or INTERFACES.md provides (04→02 R16 still open). 01 D39 relies on these markers for the zoom's shorter warning time. Pass: an alive enemy beyond the right camera edge shows the right marker (L6), marker not under other HUD (L6o) |
| QA-B027 | P3 | 04 | OPEN ad47eda (LAYOUT L4) | layout | Touch targets too close: worker card to first unit card 4 px (0.69 mm, 4.4 dp) in every battle scene; menu 라운드 선택 / 강화 6 px (6.6 dp). Pass: every gap ≥ 7.3 view px (8 dp, Android spacing guidance) |
| QA-W005 | — | 07 | RESOLVED 23:44 (run 20261031-234416); old files deleted 2026-11-01 02:20 after the user's yes (214 files, save hashes unchanged) | runner | Before this change 07 runs used the REAL user folder (10 v0.26/v0.28): 214 files, 996,211,578 B under `qa07\`, 19 × 52 MB TP-13 quarantine copies. Runner now isolates every Godot child (proof: 3 own logs, real `qa07\` and save hashes unchanged, 0 new real logs). Old files deleted by the coordinator with clean_real_qa07.ps1 -Apply after the user approved (USERDATA_POLICY.md) |
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
| QA-O004 | 01/02 | r01 HUD 'wave 0/3' vs 6 waves in data: by contract (INTERFACES v1.4, D21: pressure waves excluded from waves_total). Not a defect; consequence filed as QA-B017 |
| QA-O005 | 02 | Damage numbers on the enemy base stack into a column up to ≈ 8 rows (52f9fa3 place_text moves up to 8 × 12 px): art-baseline frames 6_r10_boss and 7_result at ad47eda. 0 overlaps, so QA-B012 holds; tall columns of the same number may read as clutter. Observation only |
| QA-O006 | 02 (cc 03) | Every unit atlas has a 2-frame `hit` animation (and the hero a `cast` animation), but battle_view `_anim_name()` maps only walk/attack/death/idle, so they are never drawn; the on-screen hit is the 0.12 s flash (ART_BASELINE §5). Wire them or stop drawing them. Observation only |
| QA-O003 | 02 | Superseded by QA-B006 (TP-06 asserts byte-identical preservation as requested by 10-research-systems). |

## Verified (resolved before or during first acceptance)
- Android back in battle toggles pause exactly once (FLOW-12 PASS; 02 added `_ui_handles_back`).
- P0 sprite names, projectile/fx kinds, biome id and card/skill icons all resolve at runtime (ART-03..08 PASS at run 20261031-072353. Files read at about 06:45 had mismatched ids, e.g. data `anim_set` "melee_basic" vs manifest "unit_melee_basic" and round biome "biome_01" vs manifest "meadow"; owners changed them before the first automated run, so no bug was filed.)
