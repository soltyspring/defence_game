# 04-client → 07-qa
Date: 2026-10-31 09:20 +09:00

## QA-B001 / QA-B002: FIXED, retested with your flow suite on a clean HEAD archive
- Fix 70b7409: every 04 back handler calls `UiScreen.claim_back()` (the first handler in a frame wins). Result and round-select navigation is emitted deferred, outside the notification walk. The HUD ignores back and snapshot/engine pause after `battle_ended` until the next `battle_started`.
- Your rerun mode `-Head -Only flow` refused to start, because `build/qa07/.run.lock` was held by your own running job at 09:10–09:15. I did not touch it. I ran the identical suite (`res://tests/acceptance/acceptance.gd --only=flow`) myself on a `git archive HEAD` copy with its own `--import`.
  - At 70b7409: FLOW-13B PASS, FLOW-23 PASS, FLOW-23B PASS. FLOW-04B FAILED (raw engine toast id `counterattack`).
  - Fixed in 0d8cc5b: `toast.counterattack` ko/en text, plus the HUD never shows a raw id (unknown keys are suppressed and logged).
  - At 0d8cc5b: **PASS=44 FAIL=0** (build/qa/flow_head_0d8cc5b/).
  - Please confirm with your own `-Head` run when your lock is free.
- Own regression: tests/ui `test_back_once_and_result_pause` uses your live-index walk (`_window_walk`), covers A/B, checks that a second separate press still works, and checks pause after the battle ends.

## QA-R4 / QA-R5: secondary-monitor launcher with project path
`tools/build/visible_launch.ps1` (70b7409) now accepts `-ProjectPath <dir>`. Example against your snapshot:
`.\tools\build\visible_launch.ps1 -ProjectPath $env:TEMP\qa07_head -Script res://tests/integration/test_ui_integration.gd -Resolution 1280x720 -UserArgs '--shot-dir=<abs dir>','--tag=head','--tile=4','--boss=boss_warlord','--locale=ko','--safe=34,0,34,0' -EvidenceDir <abs dir>`
It picks a non-primary monitor (exit 3 = none, so it opens nothing), verifies the HWND with MonitorFromWindow, makes only the game window topmost, and writes launch_*.json, godot_*.log (`--log-file`) and the shots. Verified at 09:08 on DISPLAY2 against a HEAD snapshot: build/qa/real5/headsnap_ko_*.png.

## Your typography observations (09:00)
- Dot glyphs instead of unit icons, and ♦ + cost on skills: this was the stale `ui_main` import in the SHARED dev tree. The 04 guard then draws vector fallbacks. In a fresh HEAD snapshot (own import) the real icons render: build/qa/real5/headsnap_ko_3d_skilltip.png shows unit portraits on cards and skill icons. Skill NAMES are shown in a press tooltip (the 48 px buttons have no room); the same frame shows "내려찍기".
- "Archer/Shield/Raider" fill ~90 of ~98 px: these fit by measurement, and en has 0 ellipsis in the worst layout. Tight but not clipped.
- Red bar edge above the result panel: this is the enemy base HP bar (top HUD) under the dim layer, not a result-panel artefact.
- QA-W003 `ui.star_*`: these keys have UI fallbacks in src/ui/ui_text.gd and are now also in data/text (01 67bf9ca), so no raw ids are shown.

## 15:50 QA-B009 / QA-B010 + theme A + integer scale (HEAD 5a2099d … abe2303)
- **QA-B009 root cause found and fixed (5a2099d):** `UiStyle.fit_label` checked `font_sources[&"num"]` before the numerals font had been loaded. On a fresh font state it ellipsized instead of stepping down to Galmuri9 10. In the game this also hit the first drawn button. Fixed: the font is loaded first, and a cold == warm regression test was added. On a HEAD snapshot your `--only=theme,flow` now gives **TH-FIT-HUD-KO PASS and TH-FIT-HUD-EN PASS**.
- **QA-B010 is fixed by layout, not shorter text (5a2099d, 38b4d9d):** round tiles wrap names to 2 lines at 12 px (`TouchButton.wrap_lines = 2`); a 1-line 10 px fallback is used only if 2 lines do not fit, and the ellipsis only after that. Your TH-FIT-ROUND check still measures ONE line with `fit_label`, so it reports '곰팡이 성벽을 부숴라'→'곰팡이 성벽…' although the tile draws it in full on 2 lines. Please measure with the same helper the tile uses: `UiStyle.fit_lines(txt, tile_w, UiStyle.FONT_S, 2)` and check `not result.truncated`. My test does this at 83 px and 97 px for all 10 rounds, ko and en: 0 truncated. Visible: build/qa/real6/ko_2p5x_2_round_select.png (ko 2-line tiles), real7/en_2p5x_2_round_select.png.
- Integer scale (02 141d226) verified on DISPLAY2 against a fresh HEAD snapshot: a 1600×900 window gives an 800×450 view, and **0.0% irregular glyph runs** in HUD, round select and result at 1×/2×/2.5×, ko and en (build/qa/real7/). This needed a 04 harness fix (231cfda): `--safe=` now applies insets to the live view; the old fixed rect left the HUD at y≈360 in an 800×450 view.
- TH-COL-PROTAN/DEUTAN: art colours (03), not 04.
- Note: the shared working tree has 02's uncommitted src/core/app.gd WIP that breaks App.boot. Run HEAD-snapshot mode until 02 commits.

## 16:05 Re-verification request: theme A UI (HEAD 528d065 or later)
Please run `-Head -Only theme,flow` and, for visuals, `tools/build/visible_launch.ps1 -ProjectPath <your HEAD snapshot> -Script res://tests/integration/test_ui_integration.gd -Resolution 640x360|1280x720 -UserArgs '--shot-dir=<abs>','--tag=<t>','--tile=4','--boss=boss_warlord','--locale=ko|en','--safe=34,0,34,0'`.
04 evidence (DISPLAY2, fresh HEAD snapshot with its own import, 03 2b350c4 + 01 14b01e2/5930430): build/qa/themeA/{ko,en}_{1x,2x}_*.png
- Icons and faction colours: theme A unit portraits on cards, bakery castle/red roof, mold boss bar "곰팡이 장군". No `[UiStyle] … stale` warning and no atlas load errors in the logs. Integration 32/32 in all 4 runs.
- Names: all card names fit at 12 px (제빵사/식빵병/롤빵병/통식빵/프레첼, Baker/Toast/Roll/Loaf/Twist). Round tiles: long names on 2 lines (e.g. "곰팡이 성벽을 부숴라", "Break the Mold Wall"), 0 truncated.
- Pixel regularity at 2×: 0 odd glyph runs in round select, HUD (en) and result. The ko boss frame has 4 odd runs out of 4104; these are unrelated to the UI text. Most likely bright sprite pixels, but I have not confirmed this.
- Fixed in 995628a (same scene re-captured, ko_2x_v2_3c_boss.png): the theme A boss warning was shown 3× (hint + toast + banner) because the texts now differ. Now it is the hint + "보스" banner only.
- Please re-check: TH-FIT-ROUND with `UiStyle.fit_lines(.., 2)` (your 43b4692 notes the 2-line rule), and the FLOW suite (no flow changes since 0d8cc5b).
- Not testable yet: the first-wave-broken banner (needs 02 `wave_cleared`, 04 R13). 04 unit tests cover it with a simulated signal only.

## 16:25 Re-verification request: QA-J3 + upgrade screen (HEAD 6051b3c)
Evidence (DISPLAY2, fresh HEAD snapshot, notches 34/34): build/qa/upg/{ko,en}_{1x,2x}_*.png and mock_ko_2x_*.png.
- QA-J3: the worker button is an octagon with cut corners and a gold top band; unit cards stay rectangles (the shape differs, not just a badge). The HUD shows "반죽"/"Dough" and "기력"/"Energy" next to the icons. Field priority is amount > name > income, so at en 1× the income rate is hidden; the name is never dropped. Tests check the name is shown in the 640+notch layout ko/en, with no overlap with the amount or income.
- Upgrades: "강화" button on the menu (row of 3), round select (header) and result (4th button). The panel lists only unlocked targets (r ≤ unlocked_round), Lv x/y, next cost (red if unaffordable), and effect "+8% +8%". Real engine: buttons disabled + "※ 강화 기능 준비 중입니다", because Save.buy_upgrade does not exist yet (02 R14). With a contract-faithful fake Save (tests/ui): ok / not_enough_coins (shows missing amount) / max_level (no call) / save_failed ("골드와 레벨은 그대로입니다") give different text, colour AND glyph (● ▲ ※ ×).
- Please check: TH/visual checks of the new panel at 1× (rows 40 px, buttons ≥ 40), back closes the panel before the screen (claim_back + modal check), no premium currency/ad wording (Q2 보류).
- Not testable until 02 R14: a real purchase, rollback on a failed save, double-tap.

## 16:45 Re-verification request: gate flake root cause + working title (HEAD 2177a45)
- **14-failure flake root cause (reproduced):** running tests/ui on a snapshot WITHOUT a completed `--import` gives exactly 14 FAILs (all font checks: bundled source, flags, glyph coverage, fit_label cold/warm). This matches the unexplained run at 1215516. 5 sequential runs with import: 0 fails. A second, separate race: the atlas-guard test used a fixed `user://atlas_guard_test` dir, and user:// is shared by every run of this project, so one of 3 parallel runs failed "PNG changed after import". Fixes (3aed626): per-process user:// paths in tests/ui and the integration save; tests/ui prints `ENV_NOT_IMPORTED` and fails one explicit check when imports are missing; the gate verifies every .ttf/.png import output exists after `--import` (3 tries) and refuses to run tests otherwise. After the fix: 5 parallel tests/ui + 3 parallel integration runs, all clean. Tool: `tools/build/flake_probe.ps1 -Sha <sha> -Runs 5 -Parallel 3`. Your runner may hit the same shared-user:// issue if it runs parallel suites.
- **Working title (7461636, 2177a45):** the main menu shows the title block. It uses 03's logo frames (ui_title) when present (uncommitted 03 WIP at 16:41; the captures show the logo), else ui.title text in 1 line or split after ":" into 2 lines at Bold 36/24. Captures on DISPLAY2, HEAD snapshot, notches 34/34: build/qa/title/{ko,en}_{1x,2x}_1_menu.png; integration 35/35 ×4. The text-fallback path is verified by tests only (no capture, because the logo exists in the snapshot).
- Please check: menu title at 640+notch ko/en 1×/2× (no clipping), and whether your parallel suites need per-process user:// paths too.

## 17:05 Corrections + re-verification request (HEAD after 5eab876)
- Correction to my 16:45 note: 03's ui_title logo was ALREADY committed (19245a5) when I captured. It was not uncommitted WIP. Also correction: "Bakery Knights: Mold Defense" is the working English title (English counterpart of the user's Q3, same as 06 store copy), not a placeholder. The final name still waits for KIPRIS.
- Correction to commit 5eab876's subject: the "8 read as 3" was my misreading. r05 enemy base HP really is 1300 in data (c15e43a). The backing plate under the HP digits is kept for legibility over the new stripes, but the stated cause was wrong.
- **QA-B013 (1d1e4e3):** the enemy base bar and boss bar fill now carry dark 1 px vertical stripes every 3 px (stripe luminance step ≥ 0.15). The player bar stays solid, and the HP digits sit on the same dark plate on both bars. Simulated with YOUR `tests/acceptance/cvd_sim.gd` (read-only use) on build/qa/logo_cvd/ko_2x_v2_3c_boss.png → cvd_ko_2x_v2_{protan,deutan,tritan}.png. In the protan/deutan frames the player bar is solid and the enemy/boss bars are striped, so they are separable by pattern. Please re-run your B013 check.
- **Logo on the real title (19245a5):** HEAD snapshot on DISPLAY2, ko/en 1×/2×: the 2-line logo frame at integer scale 2 in the 640-wide view (×4 device px at 2×), above the subtitle, inside the safe area (build/qa/logo_cvd/{ko,en}_{1x,2x}_1_menu.png); integration 35/35 ×6.
- 08 H15: the HUD now redraws only on change (identical snapshots: 12 → 0 redraws per snapshot). Please watch for any stale HUD value in your flow captures (e.g. a cooldown or gold number not updating). Tests cover gold and worker changes.

## 17:26 Re-verification request: real upgrade purchase, wave_cleared banner, QA-B015, B013 (HEAD 7ed4a5f)
- **Upgrade purchase (97c8b9c):** the panel sends `Events.cmd_buy_upgrade(id,to_level)` and shows `Events.upgrade_result` (02 4d77225). Real engine on DISPLAY2: ok with a double tap (one purchase, Lv 1→2), not_enough_coins (nothing charged), max_level (no request sent). Evidence: build/qa/b015_cb2470a/*_2b_upgrade_ok / 2c_upgrade_coins / 2d_upgrade_max.png. Please re-check the double tap and back-closes-panel on your side.
- **First-wave banner (97c8b9c):** shown on the real `wave_cleared` (02 22d99ea). r01 HUD wave total = 3 (pressure waves excluded). In r01 the first `wave_cleared` now fires at t≈45.0 s without player action. Evidence: *_3e_wave_cleared.png.
- **QA-B015 (8104970 hook `--title-text`):** text mode now really renders. en 640+notch: "Bakery Knights:"@36 + "Mold Defense"@24 (2 lines, widths 312/174 in a 556 slot). en 640 without notch and 800 wide: 1 line @36 (588 px). ko: 1 line @36 (456 px). Logo mode 640+notch ko/en: 2-line logo. Read back by eye, no clipping: build/qa/b015_cb2470a/{en,ko}_{640,640_notch,1280_notch,1600_notch}_text_1_menu.png and {en,ko}_640_notch_logo_1_menu.png. Note: my earlier build/qa/b015/ set was taken at 97c8b9c, before the hook existed, so its "text" frames are actually the logo. Do not use it.
- **QA-B013:** unchanged since 1d1e4e3 / 5eab876. Please re-run your CVD check if not done yet.
- Integration flake fixed in 7ed4a5f: a visible run stalls if the window loses focus during the wave fast-forward (App pauses the battle). If your runner reuses `test_ui_integration.gd` visibly, this was the cause of a one-off "wave_cleared fired at t=-1.0 s".
