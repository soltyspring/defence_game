# 04-client handoff
Updated: 2026-11-01 00:30 +09:00 (latest section: "2026-11-01 00:30 resume"; the "FINAL CHECKPOINT" text below is historical)
Session: sess_a24d01e7-e535-413c-9ff6-d5258090820b (Kiro CLI, claude-opus-5.5, trust-all; same window, resumed after account changes, the 20:27 quota stop and the 23:08 blue screen).
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
## 18:05 work during 08's quiet window (no Godot run 18:00–18:30; static checks with Python only)
- 03 A11 edge markers: src/ui/threat_marker.gd (pure `compute()` rules + drawing with vector stand-ins until 03 draws `icon_nest`/`icon_enemy_near`), HudLayout `threat_right/left` rects + validate(), HUD wiring (hidden until 02 publishes `snapshot.threat`, R16), mock engine fake `threat`, tests/ui `test_threat_marker`. Static Python port of the layout over the same 3000 configurations: 0 problems (build/qa/tmp/threat_layout_sim.py). Marker rects: 640 → right (592,222), 640+notch → (558,222), 800 → (752,222), 800×450+notch → (718,312); all 44×34.
- 03 A10 colours in ui_style.gd (C_BG/C_PANEL/C_PANEL_LIGHT/C_DISABLED, alphas kept), TouchButton default fill = C_PANEL_LIGHT; tests/ui `test_chrome_palette` pins 03's ratios (re-computed: 14.65/12.45/9.45/7.22/5.49/5.76).
- R15 check: 02 4b5926d set package/name + name_localized (config/name kept = desktop user:// unchanged). `check_launcher_label.ps1` config → OK; local APKs are old → WAITING until a rebuild. Release preset is on 02's open list.
- Everything above was NOT run in Godot at 18:05; it waits for 18:30 (gate + DISPLAY2 captures).
- **18:35 31164c8 (after the window):** gate UI 3387/0 (+33 checks: threat rules, layout at 640/640+notch/800/800×450+notch, HUD wiring, change-only redraw, palette ratios), integration 48/0. Enemy icon = existing `icon_skull` (no new 03 icon needed); nest = 03's `icon_nest`. DISPLAY2: real engine ko/en 640+notch/1280+notch/1600+notch 48/48 ×4 with the bakery colours; mock preview frames show the nest marker (29m), enemy ahead (50m) and enemy behind (left, 28m). build/qa/chrome_threat_fca9346/.
- Still open: markers in the real game need 02 R16 (`snapshot.threat`); APK label re-check needs a rebuild (config already OK); release preset (02).
## 18:55 store screenshots (06 a143134, 09 §32.1)
- `tests/integration/store_capture.gd`: real engine, staged by script, borderless fullscreen on DISPLAY2 → 1920×1080 = 640×360 ×3 (log `window=(1920,1080) view=(640,360) pixel_scale=3`), RGB8 PNG, black-frame guard. 6 scenes × ko/en from a HEAD f41fd12 snapshot → docs/qa/store_captures/ (+ README scene list). `tools/build/check_store_captures.py` (06's check_screenshot read-only + 1920×1080 + black frame): 12 files, 60 checks, 0 FAIL/INVALID; dark 0.0–3.4 %. All 12 checked by eye. No captions (01), not copied into docs/services/store_assets (06 owns it). Told 06 and 09.
- Weak points: small units (07 QA-J1), #4 column near the castle, army of 5 in #1/#2, markers not visible (02 R16).
## 19:25 lane occlusion + unit size (Codex review of 13aade1)
- 45c05f0 [Fix]: the bottom HUD covered 11–13 px of lane units only on desktop. Windows reports the taskbar work area as the display safe area (16 px bottom inset in fullscreen). safe_area.gd now applies the display safe area on mobile only (`from_display`, unit-tested). SafeArea.override_target test hook added. tests/integration/lane_occlusion_probe.gd measures this per frame. Before/after on DISPLAY2: three phone shapes (800×360, targets 48/44/42) and the 2.5× window (800×450) were 0 px before and after; desktop fullscreen 13/11 px → 0 px. A phone with a real bottom inset would still lose 12 px → 02 R17 (raise the ground row by the inset). docs/qa/LANE_OCCLUSION.md.
- Unit size: tools/build/unit_screen_size.py (alpha bbox from atlases, k=3 1080×2400 at 3.0/2.75/2.625). Soldiers 3.0–3.8 mm; 12 of 14 units are under the 6 mm working line. Requests: 03 (32 px bodies), 02 R17 (pixel-exact world zoom (k+1)/k). A+B gives 6.8–7.7 mm.
- Store set retaken from a 45c05f0 snapshot: HUD row top 300 in all 12 frames. #4 now shows a mid-screen fight (contact at 63 % of the r06 lane, 3 allies engaged). Checker 12 files / 60 checks / 0 FAIL/INVALID, dark ≤ 3.5 %. Viewed 6 of 12 by eye.
## 19:50 zoom preview (no decision) — docs/qa/ZOOM_PREVIEW.md
- tests/integration/zoom_preview.gd: runtime-only combos current / zoom 4/3 / zoom + ×1.5 units on one seeded r06 battle (snapshot 84c18ab, DISPLAY2, isolated APPDATA via new `visible_launch.ps1 -IsolateAppData`; real save hashes unchanged). Enemy visible before engaging 6.0 → 3.9 s; units on screen −10–15 %; both sides visible 73.6 → 72.5 %; soldier 3.6 / 4.9 / 7.3 mm.
- tools/build/text_screen_size.py: all Galmuri9 10 px numbers (HP, cost, income, army, badges, damage) are 1.43–1.63 mm (< 1.7 mm line); 12 px Hangul labels are 1.75–2.00 mm. The fix is a 04 task, not done yet (needs layout room).
- Requests: 02 R18, 03, 07, 01 R10 (difficulty impact of 2 s less warning). Nothing decided.
## 2026-11-01 00:30 resume after the 20:27 quota stop and the 23:08 blue screen (0x50)
- Loss check: `checkpoint/quota-20261031-202729/04-client` (a9636a2) has 0 file differences from HEAD in 04 paths. After the blue screen the 7 files I was editing were intact: 0 NUL, 0 U+FFFD, same last lines as HEAD, and only my intended diffs.
- New rule followed: every Godot run went through `coordination/heavy_run.ps1`, one at a time (lock waits of 11–17 min were normal).
  - Lesson: a scriptblock inherits heavy_run's `$ErrorActionPreference='Stop'`. Godot's harmless stderr line "Unicode parsing error … Unexpected NUL character" (4 per import, present since 17:18, not new corruption) then aborted my 23:53 import after 7 s.
  - Fix: set `$ErrorActionPreference='Continue'` inside the scriptblock. The aborted run left a START without END in heavy_run.log; the mutex was released.
- **be2abb3 [Fix]** user:// isolation for every 04 runner (10 v0.26/v0.28): common.ps1 Enter/Exit-IsolatedAppData + Get-IsolationProof; verify_and_publish (gate fails if not proven), run_tests, flake_probe, build_android_debug; visible_launch isolated BY DEFAULT (`-RealUserData` to opt out). Proof: real save.json/.bak hashes unchanged, real logs 5 → 5, test logs print the private user_data_dir.
- **d724b9a [Fix]** UI numbers Galmuri9 10 px → `UiStyle.NUM_READ` = Galmuri11 12 px (ink 11 px = 1.75 / 1.90 / 2.00 mm on 360 / 393 / 412 dp): base HP (bar 14 → 16 px), cap/income, army, card cost/badge, upgrade Lv/effect, menu version.
  - Gate (23:41 dry run): UI 3402/0 (layout matrix included, + test_readable_numbers), integration 49/0, isolated.
  - Published with Publish-Task directly; file hashes were identical to the gated snapshot.
  - DISPLAY2 capture (640×360 + notches, r05, 2×): digits 22 device px = 11 px ink; card name → cost gap 1 logical px. docs/qa/readable_numbers/.
  - Lane damage numbers (02 battle_view, Galmuri9 10) are still 1.43–1.63 mm → 02 R19.
- **1850c3f [Fix]** threat marker distance is the fixed "%dm" (07 QA-B019; 01 R9 withdrawn). Gate/APK snapshots use `git -c core.autocrlf=false -c core.eol=lf archive` (06/10 CRLF finding). Gate UI 3402/0, integration 49/0, isolated.
- Replies checked: 02 none to R16/R17/R18 (queued in its handoff); 01 none to R10; 03 A15 has 32 px drafts and waits for 02's zoom decision; my C_STAR_OFF note was wrong (unused constant; the hollow star uses C_TEXT_DIM, 6.37:1), corrected to 03.
- APK not rebuilt (no need; the LF fix applies to the next build).
## Exact next steps on resume (2026-11-01 00:30)
1. Wait for 02 R16/R17/R18/R19, 01 R10, 03 after R17. Run Godot only via heavy_run.ps1, with `$ErrorActionPreference='Continue'` inside the block.
2. When 02 adds `snapshot.threat`: one DISPLAY2 run of the integration test plus a marker frame.
3. Open 04 items from requests not done yet: menu toast/notice path (10 v0.21/v0.27, 01 R8 D32 `notice.content_migrated`), r05 defeat hint (01 R7 D31), HP-bar fill width rounding (03 A14, optional).
## Exact next steps on resume (19:50)
1. Read the replies to 02 R16/R17/R18, 01 R10 and 03 (unit size).
2. 04 task: raise the Galmuri9 10 px numbers to ≥ 1.7 mm (Galmuri9 20 or Galmuri11 12), check the layout matrix and captures.
3. If 02 adds `snapshot.threat`: verify the markers on the real engine (tests/ui + DISPLAY2 capture).
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

## Commit record 2026-11-01 00:35 (all on origin/main, checked with `git branch -r --contains`)
be2abb3 [Fix] user:// isolation for 04 runners · d724b9a [Fix] readable numbers (Galmuri11 12) · 1850c3f [Fix] marker "m" + LF snapshots · b659c97 [Docs] resume record and replies.

## 2026-11-01 07:4x resume after the 03:55 blue screen (0x3B) — notice/HUD closed, layout B
- Loss check (06:54): owned files intact (0 NUL, newline-terminated, only intended diffs). heavy_run.log: my only run without an END is 04-glyph-page-gate-probe-dc (START 03:53:21, pid 38012), voided by the coordinator's NOTE; its results were discarded. Other modified tests/acceptance and tests/performance files are 07's and 08's WIP (not mine, untouched).
- **Notice/HUD task closed.** D32 menu notice 2de6668 + ad47eda (16/16, now 17/17). R8 draw calls measured 132 → 129 (hud_top 56 → 53); target ≤ 100 not met. Cause (Godot 4.5 source, not proven by a run): glyph pages are max(px×8, 256)²; the 2× window draws 12 px text from the 24 px cache (~100 glyphs/page) and the HUD uses ~183 glyphs. My prewarm-order change cannot fit that, so it was not committed (patch: build/qa/tmp/glyph_order_wip.patch). Next test proposed to 08: `FontFile.oversampling = 1.0` + HUD-first order + pixel compare. Card button idle 5 (meets ≤ 5), cooldown 6.
- **e2404af [Docs]** 08 R8 numbers + cause; 02 R20 notice wiring. **a3bbc72 [Test]** 10 v0.33 P3: `.pre-*.json` leftovers removed and checked (gate UI 3414/0, integration 49/0, migration 17/0, isolated).
- **Layout B (user 02:24 "ui배치도 다른 게임 참고해서 진행해"):** docs/qa/UI_LAYOUT_REFERENCE.md. 5 lane-defence games (Battle Cats, Cat War2, Stick War: Legacy, Grow Castle, Age of War 2; PvZ partial), official Play screenshots kept outside the repo (%TEMP%\ui04_genre_ref), rules L1–L9, options A/B/C (tools/build/layout_options.py, docs/qa/layout_ref/), B chosen.
  - Code: hud_layout.gd (worker own group, GROUP_GAP 12; TOUCH_GAP 8 between all targets (07 L4/QA-B027); fit order: skill, then move buttons shrink before cards go under CARD_NAME_W 42, then cards, then group gaps 12 → 8, then stack; threat markers ≥ 44 px square in the top half; banner between markers; `lane_band()`; validate 07 L2/L4 + QA-J3 + 01 R10), threat_marker.gd (content centred in the plate), touch_button.gd (disabled icon α .70, 06 Ask B), main_menu.gd / round_select.gd (button and tile gaps 6 → 8 px), test_ui.gd (marker rule).
  - First gate (08:00) FAILED correctly: cards had shrunk to 41 px first, so 6 ko card names (36 px) overflowed at 640×360 both notches. Fixed by the fit order above.
- Not done (do not claim): real phone, human test (09 X7), 10's notice capture (3 texts), NinePatch frame wiring (waits for 06 redraw), glyph oversampling test, `inspect_apk.py` CR check.

## 2026-11-01 09:2x USER STOP ("이제 그만만들고 멈춰", "푸시하고 끝내", 09:17) — final state, supersedes the 07:4x section above
Session: sess_a24d01e7-e535-413c-9ff6-d5258090820b (Kiro CLI, same window). Stopped at a safe point: no file half-written, no Godot started by me in the foreground.
**Current task:** coordination/prompts/04-ui-layout-ref.txt (genre-referenced HUD layout, user 02:24). 04-notice-hud.txt is closed.

**Done and on origin/main (checked with git ls-remote):**
- 2de6668 + ad47eda: D32 menu notice (earlier). e2404af [Docs]: 08 R8 numbers 132 → 129, hud_top 56 → 53, cause = glyph-cache pages (from Godot source, not proven by a run); 02 R20. a3bbc72 [Test]: 10 v0.33 P3 leftover `.pre-*.json` removed and checked; gate UI 3414/0, integration 49/0, migration 17/0, isolated (log build/heavy/04-mig-leftover-gate-20261101-065822.log).

**Heavy runs (not killed, as instructed):**
- QUEUED, not started at 09:23: label `04-layout-b-gate2`, pid 45580, log `build/heavy/04-layout-b-gate2-20261101-080528.log`, job `build/heavy/04-layout-b-gate.ps1` (headless gate DRY RUN of the layout files; it publishes nothing). It copies the working-tree files at the moment it gets the lock.
- Finished: `04-layout-cmp-before-a3bbc72` (07 fixed set, ko/en 1x/2x, 34 px notches, harness = committed blob 7eccc60), exit 0, log build/heavy/04-layout-cmp-before-a3bbc72-20261101-072403.log, frames + table in build/qa/layout_cmp/a3bbc72/ (VOID against ad47eda as expected: other roles' changes; 07's L1–L8 rows filled: L3 44, L4 4 px, L7 12, L8 0).
- Finished and FAILED correctly: `04-layout-b-gate` 08:00 (6 ko card names overflow at 640×360 both notches: cards shrank to 41 px first). Fixed in the working tree since (fit order), not yet re-gated.

**Not verified, left in the working tree (NOT in main):**
- Layout B code: src/ui/hud_layout.gd (GROUP_GAP 12, TOUCH_GAP 8 for 07 L4/QA-B027, CARD_NAME_W 42 fit order: skills → move → cards → group gap 8 → stack; threat markers ≥ 44 px square in the top half (01 R10); banner between markers; lane_band(); validate 07 L2/L4 + QA-J3 + 01 R10), src/ui/threat_marker.gd (content centred in the plate), src/ui/touch_button.gd (disabled icon α .70, 06 Ask B), src/ui/main_menu.gd and src/ui/round_select.gd (gaps 6 → 8 px), tests/ui/test_ui.gd (marker rule).
- docs/qa/UI_LAYOUT_REFERENCE.md + docs/qa/layout_ref/ (block mock-ups A/B/C, options.json) + tools/build/layout_options.py (Python model, runs without Godot). The doc's §6 "results" (07 set after-capture, 08 draw calls) is still empty.
- tests/ui/drawcall_hud_probe.gd (v2 with --os/--shots; never run in this version).
- Request notes that mention the unpublished layout (placeholder `FEAT_SHA` still in them): coordination/requests/04-client-to-01-director.md (R11), 04-client-to-02-engine.md (R21), 04-client-to-06-art-ui.md (new, reply to R3), 04-client-to-07-qa.md (layout B note).
- Local only (git-ignored): build/qa/tmp/glyph_order_wip.patch (prewarm order, not committed on purpose), build/heavy/04-make-cmp-job.ps1 (04-labelled copy of art_compare's capture job).

**Exact next steps on resume:**
1. Read `build/heavy/04-layout-b-gate2-20261101-080528.log`. If it ran after 09:23, note that it gated the files present at that time; compare its `SNAP_HASH` lines with `Get-FileHash` of the 6 files. If they match and the log says GATE PASSED (UI/integration/migration all failed=0), the layout code is verified; otherwise rerun the gate once (detached) after fixing.
2. Publish the 6 code/test files as one [Feat] commit, then the doc + layout_ref + layout_options.py as [Docs]; replace `FEAT_SHA` in the 4 request notes with the real SHA (git ls-remote) and publish them.
3. After-capture: `.\build\heavy\04-make-cmp-job.ps1 -Sha <feat>` → start the printed job with heavy_run_detached.ps1 (label 04-layout-cmp-after-<sha>); then `.\tools\qa\art_compare.ps1 -Sha <feat> -Report -Tags ko_1x,en_1x,ko_2x,en_2x -Out build/qa/layout_cmp/<feat> -Baseline <folder with a3bbc72's art_metrics.json + cap/*.png>`; check L1/U2 ≤ +0.5 pp, L2 0, L3 ≥ 44, L4 ≥ 7.3, L8 0. Then 08 draw calls: `build/qa/tmp/drawcall_run_committed.ps1 -Rev a3bbc72` and `-Rev <feat>` (r08, -SkipMicro) in one detached job; HUD must not rise.
4. Fill §6 results in docs/qa/UI_LAYOUT_REFERENCE.md. Open items: 10's notice capture (3 texts), glyph oversampling test for 08 R8 (Pillow check: Galmuri11/Bold 12 and Galmuri9 10 rasters are identical to the ×2/×3 rasters for all 357 text characters, so `FontFile.oversampling = 1.0` should not change pixels; not run in Godot), NinePatch wiring after 06 redraws, `inspect_apk.py` CR check.
- Not done by anyone: real phone check, human test (09 X7). Decisions unchanged: Q1 A, Q2 on hold (no shop/ad UI), Q3/Q4 fixed, Q5 unanswered (D28 default only).
