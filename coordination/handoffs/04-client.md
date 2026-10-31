# 04-client handoff — FINAL CHECKPOINT (user-requested shutdown)
Updated: 2026-10-31 17:05 +09:00
Session: sess_a24d01e7-e535-413c-9ff6-d5258090820b (Kiro CLI, claude-opus-5.5, trust-all; same window throughout, resumed after two account changes).
State at checkpoint: work stopped at a safe point. The owned working tree is CLEAN (all 04 work committed and pushed). No 04-started Godot or emulator process is running. Nothing was left unverified or uncommitted.

## User decisions known to 04
- Theme: user chose A "빵집 기사단 vs 곰팡이 군단" (relayed by the coordinator 09:15). At the checkpoint, 01 had not yet recorded it (DECISIONS Q1 still PENDING) and data/text was unchanged. All other D* entries are DEFAULTS. No monetization decision; no ad/IAP UI by design.

## Delivered (all pushed to origin/main)
| SHA | What |
|---|---|
| e62fe86 | Mobile UI: main menu, round select, battle HUD, result, settings, multi-touch TouchButton, safe-area layout, mock adapter + preview |
| e4aa059, 8b24e59, 0333cd3 | Bundled Galmuri fonts (no OS fallback, pixel flags), 12/24/36 + 10/20 grid sizes, fixed-cell numerals, grid-safe English label fit |
| 183e4a6, 3fd301f, 22bdd9e | Tutorial hint (Events.tutorial_step), boss HP bar, result star-condition rows, stale-atlas-import guard (tested recovery; covers engine-supplied icons) |
| 5ba49a4 | Base HP "hp/max" numbers, star met/unmet by shape (filled/hollow), credits panel (OFL font credit), skill-name press tooltip, duplicate boss message fix, settings title clip fix |
| 70b7409 | 07 QA-B001 (one back press handled once: claim_back + deferred navigation), QA-B002 (no HUD pause menu under the result), visible_launch `-ProjectPath` (07 QA-R5) |
| 0d8cc5b | FLOW-04B: `toast.counterattack` ko/en; unknown engine toast keys are never shown raw |
| d7651af, 0b987c9, 997d0a4 | Tests/tools: tests/ui/test_ui.gd, tests/integration/test_ui_integration.gd (real engine; `--shot-dir/--tag/--tile/--locale/--safe/--boss`), tools/build/{common,run_tests,capture_ui,visible_launch,build_android_debug}.ps1, inspect_apk.py |
| 8915190 … 5426645 | Docs/requests: docs/qa/{QA_CHECKLIST,TYPOGRAPHY_QA,RELEASE_READINESS}.md, docs/mobile/BUILD_PLAN.md, requests to 01/02/03/07/09/coordinator |

## Actual validation (latest runs)
- tests/ui/test_ui.gd (headless): 3284 pass / 0 fail. Covers 3000 layout configurations, typography (230+ ko chars, 0 missing, 0 ko/en ellipsis), atlas guard, back-once/pause-after-end regressions.
- tests/integration/test_ui_integration.gd (real App/BattleSim): 31/31 headless; also 31/31 in visible DISPLAY2 runs (ko/en, 1×/2×, r05 boss).
- 07 acceptance `--only=flow` on a clean `git archive` of HEAD 0d8cc5b (own import): PASS=44 FAIL=0 (build/qa/flow_head_0d8cc5b). 07's own `-Head` rerun is not yet confirmed: their run lock was held by their job.
- Debug APK from an isolated HEAD copy (07e97ca): 59,106,028 B; no permissions; minSdk 24 / target 36; v2+v3 debug signature; 0 raw PNG/TTF/WAV; 10/10 atlas .ctex; 0 keys/passwords in the repo (build/qa/apk_head/).
- Evidence images are in git-ignored build/qa/{real,real2,real3,real4,real5,screens}.

## 15:50 resume (after the 09:25 checkpoint)
- Loss check: checkpoint/quota-20261031-092323/04-client has 0 file differences from origin/main in 04 paths; e02ba03 is in main; the owned tree was clean. Nothing lost.
- Theme A text (01 14b01e2) is in use: cards are 제빵사/식빵병/롤빵병/통식빵/프레첼 (Baker/Toast/Roll/Loaf/Twist). ui.title stays provisional per 01.
- 5a2099d: fit_label cold-font bug (root cause of 07 QA-B009) fixed; round tiles wrap to 2 lines (QA-B010); `UiStyle.prewarm_fonts()` added (08 R5).
- 231cfda: the `--safe=` harness option now uses live insets (an integer-scale 800×450 view had exposed a stale fixed rect).
- 38b4d9d: tiles prefer a 12 px 2-line wrap over the 10 px cut. **This pushed a test file with a parse error** (I published without gating on the test result). Fixed in abe2303. The HEAD snapshot then gave UI 3297/0 and integration 32/32.
- Verified on DISPLAY2 against fresh HEAD snapshots (own import, so icons are correct): 1600×900 → 800×450 view, 0.0% irregular glyph runs at 1×/2×/2.5×, ko/en (build/qa/real6, real7). 07 theme+flow on HEAD: TH-FIT-HUD ko/en PASS; TH-FIT-ROUND fails only because 07 measures 1 line (asked 07 to use fit_lines); TH-COL = 03.
- The shared tree currently has 02's uncommitted src/core/app.gd WIP (breaks App.boot), so run integration on HEAD snapshots until 02 commits.
## 16:05 milestone (theme A verification, D16 banner, pre-push gate)
- New rule, enforced by a tool: publish only via `tools/build/verify_and_publish.ps1` (HEAD snapshot + overlay of the listed files, then test_ui + integration must pass; full logs in build/qa/gate/). Negative test: an injected parse error was blocked. One unexplained gate failure (14 UI fails at 1215516) did not reproduce in 2 clean reruns at the same SHA; logs are now kept for any recurrence.
- 319e0d1 gate script; 0590e7a first-wave-broken banner (inert until 02 adds `wave_cleared`, R13); 995628a boss warning shown once (key-based dedupe, since theme texts differ).
- Theme A verified on DISPLAY2 from fresh HEAD snapshots (03 2b350c4 + 01 text): icons/colours correct, no stale warnings, names fit (cards 12 px, round tiles 2 lines), integration 32/32 ×6 runs. build/qa/themeA/.
- Waiting: 02 R13 (`wave_cleared`), 01 R5 (`banner.first_wave_cleared` text), 07 re-verification (requested 16:05).
## 16:25 milestone 6051b3c (upgrade screen + QA-J3); user decision Q2 = "보류"
- User: monetization on hold, so no ad-reward, shop, gems or remove-ads UI. Respected; the test asserts no premium/ad wording in the panel.
- New src/ui/upgrade_panel.gd (modal from menu, round select and result). It calls only `Save.buy_upgrade(id, to_level)` (02 R14, 10's contract) and is inactive with a notice until 02 adds it. Each result has its own text, kind and glyph. Verified: tests/ui (fake Save: ok, not_enough_coins, max_level, save_failed, inactive); real engine on DISPLAY2 ko/en 1×/2×: inactive notice, integration 35/35 ×4 (build/qa/upg/).
- QA-J3: octagon "econ" worker button; HUD resource names (반죽/기력). Asked 01 to retheme "보급 증가" (R6).
- Waiting: 02 R13 (wave_cleared), R14 (buy_upgrade); 01 R5/R6 texts; 07 re-verification (16:05, 16:25).
## 16:45 milestone: flake root cause, working title (Q3), Android label proposal
- Flake: reproduced the 14 FAILs exactly by running without a completed import. Also found a parallel-run race on shared user://. Fixed in 3aed626 (per-process paths, explicit ENV_NOT_IMPORTED check, the gate verifies imports with 3 retries). 5 sequential + 5 parallel UI runs and 3 parallel integration runs are now clean (tools/build/flake_probe.ps1, logs build/qa/flake/).
- Title: src/ui/title_block.gd (7461636, 2177a45). The 03 logo (committed 19245a5) is used, else text in 1 line or 2 lines split after ":". English "Bakery Knights: Mold Defense" is the working English title (Q3 counterpart, same as 06 store copy). Stale "레인 디펜스" is replaced by the working-title fallback until 01 updates ui.title (R7). Captured ko/en 1×/2× on DISPLAY2 (build/qa/title). Q2 = 보류 (no monetization UI). Q3 working title only, final name after a human KIPRIS check.
- Android label: proposal sent to 01 (R7), not decided (A: "빵집 기사단"/"Bakery Knights").
## 17:05 milestone (08 H14/H15/H16, 07 QA-B013, logo check)
- 1d1e4e3: change-only redraw. Redraws per snapshot: identical 12 → 0; changing 12 → 1.55 (tests/ui/redraw_probe.gd, before = c15e43a). Exact-string prewarm (banner Bold 24 etc.); binary-search ellipsis; enemy/boss bar stripes for colour-blind players.
- 5eab876: plate under the HP digits. **Its subject's cause ("8 read as 3") was my misreading.** The data says 1300 (c15e43a); corrected in a code comment (e4c48b9) and in the 04→07 note.
- Gate hardening: a fixed %TEMP%\ui04_gate dir was half-deleted while another process held a file, so tests were "File not found" (17:01; nothing was published). The gate now uses a unique dir per run and checks the snapshot is complete (environment failure = exit 2, distinct from test failure).
- Logo (19245a5) verified at integer scale on DISPLAY2 ko/en 1×/2×; CVD sims via 07's cvd_sim.gd (build/qa/logo_cvd).
- Waiting: 02 R13/R14; 01 R5–R7; 07/08 re-verification.
## 17:26 milestone (dependencies resolved: 02 4d77225 / 22d99ea, 10 e340144)
- 97c8b9c: upgrade panel calls `Events.cmd_buy_upgrade(id,to_level)` and waits for `Events.upgrade_result` (fallback `Save.buy_upgrade`). The UI never edits Save.progress. Codes map to the 4 message kinds (ok/already_applied → good; not_enough_coins/locked → warn; max_level → info; save_failed/save_uncertain/read_only/unknown_id/invalid_level/no_reply → error). A 400 ms lock (`BUY_LOCK_MS`) makes a double tap one call. Real engine on DISPLAY2: ok once with the second tap ignored (Lv 1→2), not_enough_coins charged nothing, max_level sent no request.
- 97c8b9c: the first-wave banner listens to the real `wave_cleared`. r01 HUD wave total is 3 (pressure waves excluded). After 01's a262640 the first `wave_cleared` fires at t≈45.0 s with no player action (was ≈67.5 s before a262640).
- 8104970: `--title-text` forces the text fallback and the log prints the drawn lines. QA-B015 captures from a cb2470a snapshot on DISPLAY2 (build/qa/b015_cb2470a/*_1_menu.png), all read back and checked by eye, no clipping:
  - en 640+notch (slot 556): "Bakery Knights:"@36 (312 px) + "Mold Defense"@24 (174 px). Same at 1280+notch (2×).
  - en 640 no notch (slot 624): 1 line @36, 588 px. en 1600+notch (800 wide, slot 716): 1 line @36.
  - ko all widths: 1 line @36, 456 px.
  - Logo mode 640+notch ko/en: 2-line logo at integer scale, above the subtitle.
  The earlier build/qa/b015/ set was taken at 97c8b9c (before the hook), so it does NOT show text mode. Ignore it.
- 7ed4a5f: 1 of 13 visible runs failed the wave_cleared check. Cause: App pauses the battle on APPLICATION_FOCUS_OUT and `sim.step()` returns while paused, so the fast-forward loop ran out of guard frames at t=36.7 s. The test now resumes the battle if it was paused and logs it. Verified with an injected focus-out (headless, 44/44) and 5 visible runs (44/44). Gate: UI 3354/0, integration 44/0.
- Not done: 03's per-locale title pages (`ui_title_ko`/`ui_title_en`) are only in the shared tree as uncommitted 03 WIP (committed `ui_title` is shown as deleted there). title_block.gd still reads `ui_title`. Switch after 03 commits. (Superseded 17:45: 03 committed 11ceacb; switched in a6369ba.)
## 17:45 milestone (Q4 launcher name, title pages per locale, stale-title fix)
- **Correction:** my 17:26 notes said data/text `ui.title` was still "레인 디펜스". Wrong: 01's a262640 (included in cb2470a) already set "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense". baa1672 removed the stale-name override in title_block.gd; the menu reads `ui.title`; FALLBACK_KO/EN now hold the working title for a missing key. `upgrade.supply_regen` "보급 증가" is really still open (01 R6).
- **Q4 (user, 17:19 KST):** launcher ko "빵집 기사단", en "Bakery Knights"; in-game/store titles unchanged. 4915682: `tools/build/check_launcher_label.ps1` (config + aapt2 labels of real APKs; OK / WAITING / MISMATCH; self-test 14/14; no Godot needed). Today: WAITING. `build_android_debug.ps1 -ProbeQ4Label` exported an APK from an isolated copy with the proposed keys: ko '빵집 기사단', other 88 slots 'Bakery Knights' → OK (build/qa/apk_q4probe). Keys + desktop user:// options + release preset sent to 02 (R15).
- **R12 re-audit (probe APK, HEAD 5357ca3):** OFL text and fonts_provenance.json are shipped. Still shipped: src/ui/mock/*, ui_preview, src/core/diag/*, services mocks. bot_player.gd must stay (battle.gd preloads it); my earlier R12-2 was wrong there.
- **a6369ba:** logo from `ui_title_<locale>` (03 11ceacb removed `ui_title`, so HEAD showed the text title from 17:36 to 17:44). Menu holds only that page, released in battle. DISPLAY2 ko/en 1×/2× + notch: logo drawn, refs 1 → 0, integration 48/48 ×4 (build/qa/title_v011_0f3dfc8).
- First wave_cleared ≈45 s stays an 01 decision (D16 upper edge).
- Not done: 03's chrome colour proposal (all screens, contrast tests), after 08's 18:00–18:30 quiet window (no Godot/editor/emulator by 04 in that window).
## Unfinished / open (not done, do not claim)
1. Theme-A labels: waiting for 01 to commit data/text. Then: run test_ui (typography gate) + worst-layout ko/en visible captures.
2. 2.5× (non-integer) pixel text irregular (57–68% odd runs): waiting for 02 `scale_mode="integer"` (04 R9).
3. Shared dev-tree import stale (ui_main, char_*_adv, char_boss_*): waiting for 02 `--import` (R11). Fresh snapshots render correctly.
4. OFL licence text not in the APK; release preset should exclude mock/diag code and ship arm64 only (R12).
5. APK not installed by 04 on any emulator (02 owns LaneDefence_Phone; slot requested in R12). No physical device; no release key/AAB (user actions).
6. Not implemented: 2× speed UI, flash-limit/hold-toggle settings. Upgrade purchases work on the real engine since 97c8b9c; not tested on a device.
7. Launcher label: WAITING for 02 (R15), then rebuild and `check_launcher_label.ps1` must say OK. Chrome colours (03 A10) not done.

## Exact next steps on resume
1. Read coordinator-to-04-client.md, DECISIONS.md, 02-engine-to-04-client.md (R9/R11/R12 replies), 01-director-to-04-client.md (theme labels).
2. If 01 committed theme text: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/ui/test_ui.gd` (expect 0 ko/en ellipsis). Then on DISPLAY2: `.\tools\build\visible_launch.ps1 -Script res://tests/integration/test_ui_integration.gd -Resolution 1280x720 -UserArgs '--shot-dir=<abs>','--tag=themeA_ko','--tile=4','--boss=boss_warlord','--locale=ko','--safe=34,0,34,0'` (repeat with en, and at 640x360).
3. If 02 set integer scale / re-imported: the same command at `-Resolution 1600x900` → expect an 800×450 view and 0% odd glyph runs; check icons in the shared tree (no `[UiStyle] … stale` warning in godot_*.log).
4. If 02 gives an install slot: `.\tools\build\build_android_debug.ps1`, then install/start/screencap on their AVD only in the agreed slot; record the result in docs/qa/RELEASE_READINESS.md A13.
5. Commit only verified owned files with tools/build/verify_and_publish.ps1 (it runs both suites on a HEAD snapshot, then calls Publish-Task.ps1).
