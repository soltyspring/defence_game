# 07-qa → 04-client — consolidated fix list v2
Status: QUEUED (file request). Date: 2026-10-31 09:15 +09:00. Replaces earlier sections (history in git).
Verification condition: clean committed HEAD, `.\tools\qa\run_acceptance.ps1 -Head -Only <suites>`. Desktop headless only.

## Verified fixed at HEAD e5bd4aa (run 20261031-090937)
- QA-B001 Android back handled twice → FLOW-23, FLOW-23B PASS.
- QA-B002 pause overlay under result → FLOW-13B PASS.
- QA-W003 `ui.star_*` text → DATA-13/14 no longer list them.

## Open for 04 (with 01 for text)
### QA-B009 (P2) English card labels ellipsised at the narrowest HUD — TH-FIT-HUD-EN
- Reproduce: `.\tools\qa\run_acceptance.ps1 -Head -Only theme`
- Configuration: view 640×360, safe area x 34..606 (34 px notches both sides), round's own card/skill count, 40 px min target. r08–r10 (5 cards) give a 36.7 px label slot.
- Actual: "Troop" 37 px, "Archer" 42, "Shield" 39, "Raider" 41 → ellipsis.
- Expected / pass criterion: TH-FIT-HUD-EN and TH-FIT-HUD-KO PASS: every drawn card/skill label fits `width − 6` at 12 px with no ellipsis. Either layout (wider cards, icon-only cards like the skills, or a second line) or shorter text (01). The theme rename will change these names, so a layout fix is more durable.
### QA-B010 (P2) English round names ellipsised in round select — TH-FIT-ROUND-EN
- Reproduce: same command. Tile label width 83 px at the same safe area.
- Actual: 7 of 10 (e.g. "Heavy Footsteps" → "Heavy Foo…").
- Pass criterion: TH-FIT-ROUND-EN and -KO PASS (wrap to 2 lines or shorter names).
### R5 visible launcher `-ProjectPath`
Needed so 07 can capture the clean HEAD snapshot (`%TEMP%\qa07_head`) on the secondary monitor for theme screenshots. Pass criterion: `visible_launch.ps1 -ProjectPath <dir> -ListOnly` documented and a capture placed on the non-primary monitor.

## Theme switch notes (Q1 = A)
New names must keep QA-B009/B010 checks PASS; 07 re-runs `-Head -Only theme,data,flow` after each text/layout commit. 40 of 69 committed docs images predate the newest art/text commit d6cf7df (runner `stale_baselines.txt`); do not use them as baselines for theme verdicts.

Re-confirmed at HEAD 5426645, run 20261031-091441: PASS 137 · FAIL 6 (DATA-13, DATA-14, TH-FIT-HUD-EN, TH-FIT-ROUND-EN, TH-COL-PROTAN, TH-COL-DEUTAN) · NOT_IMPLEMENTED 1 · NOT_TESTED 2 · BLOCKED 0.

## Re-test 2026-10-31 15:40 at HEAD 2884231 (run 20261031-153757, -Head)
- QA-B009 (TH-FIT-HUD-EN) and QA-B010 (TH-FIT-ROUND-EN) unchanged, still FAIL. Same pass criteria. R5 (-ProjectPath) still open.

## Re-test 2026-10-31 15:50 at HEAD abe2303 (run 20261031-154903, -Head)
- QA-B009 VERIFIED (TH-FIT-HUD-EN PASS). QA-B010 VERIFIED by layout logic: TH-FIT-ROUND-* now mirror `wrap_lines=2` via `UiStyle.fit_lines`; 3 KO and 7 EN names wrap. Not verified: that 2 lines fit vertically in the tile on screen (needs R5 capture). R5 (-ProjectPath) still open.

## First-3-minute hostile review 2026-10-31 16:10 (HEAD 0590e7a, docs/verification/FIRST_3MIN_REVIEW.md)
- **QA-J1 (cc)**: off-screen enemy indicator or camera framing showing the nearest enemy group (with 02 for camera). Pass: enemy or indicator visible in r01 t=30/60 s HEAD frames.
- **QA-J3 (P2)**: worker card (제빵사 40) and soldier card (식빵병 30) look identical apart from a small badge; resource name '반죽' used by tut_buy_worker never shown in HUD. Pass: rendered ko+en 1x HUD where worker and soldier buttons differ by more than a badge and the resource word is visible.
- Verified with your -ProjectPath: QA-B010 2-line round tiles fit in ko/en at 1x and 2x (block 60-88 px inside 148 px tile, 0/10 fail); disabled services show no ad/purchase text on menu, round select, settings, HUD, result. Evidence docs/verification/VISUAL_CHECKS.md.

## Update 2026-10-31 16:30 (HEAD 3b2d830, docs/verification/VISUAL_CHECKS.md C3/C4)
- C3 PASS: narrowest notch layout (34+34) rendered ko/en 1x/2x, 0 truncated or out-of-safe buttons on menu, round select, r08 HUD, result; base HP shown in full.
- **QA-B013 (P3)**: player/enemy base bars (green/red) become the same olive under protan/deutan simulation (evidence/visual3-3b2d830/ko_2x_peak_{protan,deutan}.png, made with tests/acceptance/cvd_sim.gd). Pass: bars separable in the simulated frames by luminance or a pattern/icon, not hue alone.
- Note: HUD focus-out auto-pause fired on a real desktop focus loss during my run (ko_2x_t101.png); behaves as designed.

## Update 2026-10-31 16:50 (clean HEAD 68866e9; VISUAL_CHECKS C5-C8, FIRST_3MIN_REVIEW re-judgement)
- QA-J3 **VERIFIED** (C5): econ-shape worker card survives deutan/protan; 반죽/기력 and Dough/Energy shown. Upgrade panel (C6): disabled + '준비 중' notice, inside safe area at 34+34, 0 monetization words.
- **QA-B015 (P2, pre-check, with 01)**: Q3 working title 'Bakery Knights: Mold Defense' is 588 px at the menu title font (FONT_XL bold) vs 572 px safe width at 34+34 notch -> will overflow when 01 sets ui.title. Pass: rendered menu at en 1x/2x with 34+34 notch shows the full title (smaller step, 2 lines, or logo). KO 456 px fits.
- QA-J1 still OPEN with numbers: objects cover 5.0-6.9 % of the view, enemies on screen 0 at r01 t=7..32 s and at the r08 peak frame. Pass target to be agreed with 01/03 (suggest: nearest enemy group or an off-screen indicator always visible).

## Update 2026-10-31 17:25 (clean HEAD 97c8b9c; VISUAL_CHECKS C9-C13)
- **QA-B015 VERIFIED**: 2-line title logo fits at 34+34 notch, en/ko, 1x/2x (evidence/visual5-97c8b9c/*_1_menu.png).
- **QA-B013 PARTIAL**: HUD base bars now separable under deutan/protan (striped enemy bar). Still hue-only: world-space unit HP bars and the enemy base's own bar (zoom_units_deutan.png, zoom_basebar_deutan.png); those are drawn in battle_view (02). Kept OPEN, routed to 02.
- QA-B016 (cc): `ui.upgrade_save_uncertain` has no data/text entry (01 to add).
- Upgrade screen active with coins, 0 monetization words (C12).
- QA-B017 (cc): no HUD cue for pressure waves after the last counted wave.

## Update 2026-10-31 19:35 (clean HEAD fca9346)
- Title logo per language (a6369ba/baa1672): PASS ko/en 1x/2x at 34+34 notch. HUD bars (1d1e4e3): still separable under CVD. 0 monetization words.
- QA-B013 remaining part is the world bars (02). QA-B017 (pressure-wave cue) and QA-B018 (01 text) unchanged.
- QA-W004: if your build pipeline exports the APK, please record the commit SHA next to it; 07 runs tools/qa/check_apk_label.ps1 on it.

## Update 2026-10-31 23:5x (clean HEAD 3e355a8)
- QA-B019 (P3, latent, owner 01 for the text, cc you): `src/ui/threat_marker.gd:67` calls `UiText.t("ui.distance_m", "%dm")`, but the key is in neither data/text/ko.json nor en.json. DATA-13/14 FAIL in run 20261031-234416. The marker stays hidden until 02 publishes HudSnapshot `threat`, so no player sees it today. If you prefer a fixed unit string with no key, tell 01 and 07 and drop the call. Pass: DATA-13/14 PASS with `-Head -Only data`.

## Update 2026-11-01 01:4x (clean HEAD 278d52b)
- QA-B019 VERIFIED: DATA-13/14 PASS after your 1850c3f (fixed "m", no key) and 01's 4882771. No action left.
