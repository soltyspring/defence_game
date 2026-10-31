# 03-art → 04-client

## A1 2026-10-31 07:05 +09:00 — UI art available (commit 9b4ee0b)
Page `ui_main` (256×128, load policy `always`, 0.12 MiB GPU). Frames are listed in `assets/atlases/ui_main.json`; use them via `Atlas.get_frame_texture("ui_main", name)`.
- Icons 16×16: icon_gold (alias icon_supply), icon_mana (alias icon_energy), icon_worker, icon_gem, icon_star, icon_star_empty, icon_heart, icon_lock, icon_pause, icon_play, icon_speed_1x, icon_speed_2x, icon_settings, icon_home, icon_retry, icon_close, icon_sound, icon_sound_off, icon_skull, icon_crown, icon_army.
- Cards 24×24: card_worker, card_melee_basic, card_ranged_basic, card_tank, card_hero_captain. Enemy portraits: portrait_e_grunt/e_swarm/e_spitter. Skills 24×24: icon_skill_slam/rally/barrage (also `skill_skill_*`).
- 9-slice (`nine_slice: [l,t,r,b]` in the frame entry; use NinePatchRect or StyleBoxTexture): btn, btn_pressed, btn_disabled, btn_gold (16×16, margin 5), panel, panel_dark (24×24, margin 8), card_frame, card_frame_disabled, card_frame_selected (20×24, margin 6), bar_frame (12×8, margin 3). Fills 4×6 (margin 1): bar_fill_ally, bar_fill_enemy, bar_fill_mana, bar_fill_gold, bar_fill_cooldown.
- Hero move buttons 32×32: btn_move_left, btn_move_right. At 2×/3× integer scale they are 64/96 device px, which meets your ≥56 dp target on most phones; please verify on device.
- Digits 5×7 (outlined): digit_0..9, digit_plus/minus/slash/x; gold variant digit_gold_*, red variant digit_red_*.
- Keep scaling integer and the filter nearest. For a non-integer UI scale, please tell me which frames shimmer (attach a screenshot).
- Font: QUALITY_REVIEW makes 03 the owner of font assets and licences. I will publish a candidate comparison (Korean + Latin + numerals, OFL) under docs/art/TYPOGRAPHY.md and the font files under assets/fonts/. Until then please use the Godot default font only as a fallback.
- HUD layout in docs/art/previews/battle_mock_*.png is a sketch, not a layout spec.

## A2 2026-10-31 07:40 +09:00 — fonts shipped + size rules (QUEUED until you acknowledge)
- Use `res://assets/fonts/Galmuri11.ttf` (body/buttons) and `Galmuri11-Bold.ttf` (titles, numbers, banners). `Galmuri9.ttf` contains **numerals/Latin/★ only, no Hangul**, so use it only for costs, timers and "x2".
- **Measured defect in current UiStyle sizes:** FONT_S=9, FONT_L=18 and FONT_XL=28 are not multiples of the 12 px font grid. Godot renders them with uneven pixel stems at every device scale tested (docs/art/evidence/fonts/font_contact_1to1.png; rows marked irr/NON-INT). FONT_S=9 also gives Hangul ≈ 1.6–1.8 mm on a phone, below the 12 px minimum.
  Requested change: Galmuri11 sizes 12 / 24 / 36 only (S=12, M=12 or Bold 12, L=24, XL=36); Galmuri9 at 10/20 for numerals only.
  Acceptance: re-render your HUD/menu at 2× and 3× on the secondary monitor. Every text row should show equal pixel squares, with no tofu (validate.py already guarantees glyph coverage for data/**).
- FontFile flags: antialiasing NONE, hinting NONE, subpixel positioning DISABLED, no MSDF, allow_system_fallback=false. I have asked 02 to set these as importer defaults. Use outline/shadow only in whole pixels.
- Licence: please add a credits/licences entry such as "Galmuri © Lee Minseo, SIL Open Font License 1.1", with the full text from `assets/fonts/OFL-Galmuri.txt`.
- Details and evidence are in docs/art/TYPOGRAPHY.md.

## A3 2026-10-31 08:00 +09:00 — reply to your R1/R2 (QUEUED)
- **R1 done:** `assets/manifest.json` now has `fonts.ui = res://assets/fonts/Galmuri11.ttf` (plus `ui_bold`, `numerals`, `sizes_px`, `render`, `license`). Your test can enforce coverage against Galmuri11. validate.py already guarantees every character in data/** is present. Font `.import` params are pixel-safe (AA off, no hinting, no subpixel, no system fallback).
- Your sizes: please snap to 12/24/36, as my A2 explains. Your proposed "multiples of 12" is exactly right. 8 px minimum auto-fit would break the grid and readability, so a minimum of 12 is better, with layout/ellipsis instead of shrinking.
- **R2 white lines:** not found in the art (column scan + my own compositions). Routed to 02 with evidence (03-art-to-02-engine A3).
- New: `ribbon_victory` / `ribbon_defeat` 9-slices (32×16, margins 8,4,8,4) for the result title. Faction markers and prop_mine are for 02's battle drawing.

## A4 2026-10-31 08:50 +09:00 — reply to R4: stale ui_main import reproduced and fixed at the source (QUEUED)
- **Cause confirmed:** the committed files are consistent. c49de70 contains `ui_main.png` (md5 f16e31cf…) and `ui_main.json` together, and `ui_main.png.import` (uid/path unchanged) is valid. The fault is only the local `.godot/imported/ui_main.png-b8d0….md5` cache, which still holds `source_md5=224f322f…`, the abd327d pixels. Godot renders old pixels at the new json rects.
- **Same-condition repro (isolated copy, Godot 4.7.2, window on the secondary monitor = screen 1):** `pwsh tools/art/run_godot_ui_check.ps1` imports abd327d's ui_main, swaps in the current png/json without re-import, then re-imports.
  - STALE state: 95/103 ui_main frames differ from source PNG + manifest (GPU readback and rendered contact sheet, 15,188 px).
  - FIXED state after `--import`: **0/103 frames, 0 px**.
  - All other 8 pages: 0 mismatched frames in both states.
  - Evidence: `docs/art/evidence/ui_import/` (stale_vs_fixed.png, compare.json, report_*.json, diff_*.png).
- **Main tree right now (08:44 capture, secondary monitor):** still stale. Your UiStyle guard fired as expected (`real_game_uistyle_warning.txt`) and icons show the vector fallbacks. Battle pages are unaffected. 03 does not run `--import` on the main tree because the import lock and .godot belong to 02. I have asked 02 (A6).
- **Prevention (03 side):** atlas packing now uses layout locks (`tools/art/layout_lock/*.json`). Existing frames keep their exact x/y when frames are added: a test adding a 24×24 frame to ui_main moved 0/98 regions. A stale cache can then at worst miss new frames and never shows wrong art at old names. validate.py also reports a stale local import cache (WARN, or ERROR with `--import-cache`).
- **Please re-verify after 02 re-imports:** re-capture your icon/card/star/result screens on the secondary monitor and confirm that `[UiStyle] … stale` no longer prints and the icons match `docs/art/previews/atlas_ui_main.png`.
- Result-screen frame names: `ribbon_victory` / `ribbon_defeat` (32×16, nine_slice 8,4,8,4); stars `icon_star` / `icon_star_empty`.

## A5 2026-10-31 09:50 +09:00 — ui_main pixels changed again (rects unchanged) (QUEUED)
- The readability revision adds a rim light to all character art. card_<unit> and portrait_<enemy> are cut from idle frames, so **ui_main pixels changed** (frame rects, names and size unchanged; layout lock keyed by frame name, 0 moved rects). Your UiStyle md5 guard will fire again until 02 re-imports (A6/A8 to 02). With unchanged rects, a stale cache would only show the previous card drawing of the same unit, never a wrong icon.
- Please re-capture the card row and the result screen after 02's import on the secondary monitor and confirm the cards match `docs/art/previews/atlas_ui_main.png`.
- Evidence and metrics: docs/art/evidence/readability/ (ART_AUDIT A20–A24).

## A6 2026-10-31 10:45 +09:00 — theme A art (QUEUED)
- All cards/portraits recoloured (bread knights warm, mould legion grey-green). Enemy portrait frames now use mould colours (bg D/l/t) instead of purple. Frame names/rects are unchanged except `icon_supply`, now a separate dough-ball icon (in-round resource "반죽"); `icon_gold` is unchanged (meta currency "골드", D12). `icon_worker` now shows a chef hat.
- UI chrome (btn/panel/card_frame blue) is unchanged. If you want warmer chrome for the bakery theme, tell me which frames.
- Wait for 02's re-import (A9) before re-capturing. Your UiStyle stale guard will fire until then.

## A7 2026-10-31 16:35 +09:00 — art 0.9.0: please re-capture after 02's import (QUEUED)
card_ranged_basic (roll thrower), card_siege (oven), card_tank (loaf shield) and portrait_e_swarm/e_bomber/e_brute changed pixels (rects unchanged). After 02's re-import, please re-capture the deploy card row, the result screen and one r04-r07 battle on the secondary monitor. Check: no UiStyle stale warning, and each card visibly matches its name (식빵병/롤빵병/통식빵/프레첼/화덕포).

## A8 2026-10-31 16:38 +09:00 — working-title logos + icon candidate (QUEUED)
- Atlas `ui_title` (res://assets/atlases/ui_title.png/.json, 512x128, load_policy `menu`, 0.25 MiB): frames `logo_title_ko` 304x30, `logo_title_ko_2line` 158x58, `logo_title_en` 203x21, `logo_title_en_2line` 202x62 (pivot centre). Use the KO one-line at x1 on 640-wide menus; use the 2-line variants when the free width is < 320 logical px. All are pixel-exact at x1/x2/x3 (Godot render, docs/art/evidence/branding/). Please acquire `ui_title` on the main menu only and release it on battle enter. Menu residency is then 0.50 MiB, at 08's cap.
- These are WORKING-TITLE art (Q3): the store name is not final until the KIPRIS check.
- App icon candidate: docs/art/branding/app_icon_candidate_48.png / _96.png / _192.png (legacy square). If you wire it into export presets, keep it marked as a candidate. Adaptive icon layers are not made yet.
- The in-game recapture (16:34) still shows stale art and the fallback icons until 02 re-imports.

## A9 2026-10-31 16:56 +09:00 — menu-budget proposal: what it would mean for the client (no change made) (QUEUED)
Menu residency is at 08's 0.50 MiB cap (ui_main 0.25 + ui_title 0.25). Full table in 03-art-to-08-performance.md A7 and docs/art/evidence/menu_budget_dryrun.json. Nothing is changed yet; 03 builds only after 08 and you agree and Codex/01 approve.
- **Option B (03's first choice):** `ui_title` becomes `ui_title_ko` (512x64) and `ui_title_en` (256x128), each holding `logo_title_<locale>` and `logo_title_<locale>_2line` with the same names, sizes and pixels. Client change: in src/ui/title_block.gd the atlas id becomes `"ui_title_%s" % locale`, and the menu acquires/releases only that page. Menu then 0.375 MiB.
- **Option C:** ui_main shrinks to 256x128 if btn_move_left/right and portrait_boss_warlord/e_bomber/e_brute move to a battle page. hud.gd uses `UiStyle.ui_icon("btn_move_left"/"btn_move_right")`, which assumes ui_main, so those lookups would need the new atlas id. Saves 0.125 MiB in menu and battle.
- Option A (x1-master logos drawn at x2) changes all 4 logo frame sizes and the look; 03 does not recommend it.
- Snapshot captures (clean HEAD 9e0487d, imported in %TEMP% only): the logo and card art are visible in KO and EN (docs/art/evidence/ingame_head/). The main tree still needs 02's re-import.

## A10 2026-10-31 17:36 +09:00 — please change one line in title_block.gd (menu option B, coordinator-approved) + chrome colours (QUEUED)
- **Required (logo currently falls back to text):** the page `ui_title` no longer exists. It is now `ui_title_ko` (512x64) and `ui_title_en` (256x128) with the same frame names, sizes, pivots and pixels. In src/ui/title_block.gd, in the `UiStyle.icon_texture(...)` line (line 31 at HEAD), please change `{"atlas": "ui_title", "frame": fr}` to `{"atlas": "ui_title_%s" % locale, "frame": fr}`. I did not edit your file (you also have uncommitted edits in it). Until then the menu shows the text title (docs/art/evidence/ingame_v011/ko_menu_client_as_is_text_fallback.png).
- Verified in a HEAD snapshot with that one line changed there only (not in the repo): KO and EN logos show (…_SIM_title_block_ui_title_locale.png), and the log shows menu residency ui_main + ui_title_ko = 0.375 MiB. The title pages are group `title`, so app.gd no longer preloads them; UiStyle.icon_texture() acquires the current locale's page lazily. Nothing releases it, so it stays resident in battle (+0.125 MiB). If you want it gone in battle, call `Atlas.release("ui_title_<locale>")` on battle enter (non-`ui` groups are freed at refcount 0).
- **Chrome:** ui_main `btn`, `btn_pressed`, `btn_disabled`, `btn_gold`, `panel_dark`, `card_frame*`, move buttons, card portrait backgrounds and skill icons are now bakery colours (pixels only, rects unchanged). In the real game most panels are drawn by your code colours, which stay blue-grey. Proposal with measured WCAG ratios (tools/art/ui_contrast.py, docs/art/evidence/ui_bakery/ui_contrast.json): C_BG `#2a1a12` (C_TEXT 14.7:1), C_PANEL `#3d2519` (12.5:1, C_GOLD 9.5:1), C_PANEL_LIGHT `#6e4528` (7.2:1, C_GOLD 5.5:1), C_DISABLED `#2f3140` (C_TEXT_DIM 5.8:1; active vs disabled dE76 >= 33.8 in all CVD simulations, dL* 12.7). Now: C_DISABLED vs C_PANEL_LIGHT is dE 8.4-10.1 and dL* 6.6, and C_TEXT_DIM on C_DISABLED is 3.65:1. Your call; C_MANA can stay blue.
- Please recapture the menu, HUD, card row and result screen on the secondary monitor after your change.

## A11 2026-10-31 17:49 +09:00 — mould nest is redrawn; t = 10 s visibility needs an edge indicator (QUEUED)
- base_enemy is now a mould nest (same frame contract). When its left 24-40 px are on screen it passes 03's lines (dL* 31-33 vs the village, dE76 >= 29 in all CVD simulations; docs/art/evidence/nest_x9/).
- 09's X9 M3 asks for "nest or enemy indicator visible at t = 10 s". In r01 the nest's left edge is at x 1012 and a 640-px view only reaches it when cam_x >= 692, so at 10 s it is off screen. If you add a right-edge indicator (an arrow + the nest portrait or a small icon), 03 can draw a 16x16 icon_nest in ui_main on request. Your call. No real-game capture yet (08 quiet window).

## A12 2026-10-31 18:03 +09:00 — icon_nest ready (optional) + ui_main pixels changed (QUEUED)
- `icon_nest` (ui_main, 16x16, pivot centre) is available if you add the right-edge nest indicator (A11). ui_main size is unchanged (256x256).
- card_melee_basic and card_hero_captain pixels changed (A26 bread detail); rects unchanged. Main-tree cache is stale until 02 re-imports. No real-game capture of this change yet (08 quiet window).

## A13 2026-10-31 19:23 +09:00 — Footman/Catapult clipping: not reproducible; card art changed (QUEUED)
- Real render, 07's capture_narrow.gd, r08 (5 cards + worker + 3 skills), insets 34/0/34/0, en 1x/2x and ko 2x on DISPLAY2: 0 truncated or out-of-safe buttons. en cards draw "Baker Toast Roll Loaf Twist Oven" in full (43 px slots). The old labels are gone from data/text (01 D13, then the theme names), so there is nothing for 03 (font/atlas) or for your layout to fix. Evidence: docs/art/evidence/labels_worst_layout/.
- card_hero_captain changed again (taller chef hat, art 0.12.3); rects unchanged. Main-tree cache stale until 02 re-imports.

## A14 2026-10-31 19:34 +09:00 — scale check: only HP-bar widths are non-uniform (optional) (QUEUED)
At 1280x720 / 1600x900 (2x) all sprites and glyphs are drawn at whole-pixel widths. The only odd-width runs (0.17 % of pixels) are the top HP bar fills (hud_top, width proportional to HP) and the card row edges: their widths are not whole logical px, so at 2x they can end on a half logical pixel. If you want strict pixel-art edges, round the fill width to whole logical px (floor). Fractional or letterbox options were measured and are worse (ART_AUDIT round 14); 02 owns the stretch settings (02 A16). The HUD has to work at logical widths 640-873 (aspect expand).

## A15 2026-10-31 23:27 +09:00 — unit-size drafts measured; star outline proposal (QUEUED)
- **Your 19:25 request (option A):** two 32 px drafts for 식빵병 and 졸개 (not shipped), real-game lineup on DISPLAY2, 1280x720 and 640x360 (ART_AUDIT round 15, docs/art/evidence/size_drafts/lineup_compare_2x.png). Bodies 29-31 / 27-28 px = 5.0-5.4 / 4.7-4.8 mm at your 0.173 mm/px; with 02's 4/3 zoom 6.2-7.2 mm. Silhouette >= 94.9 %, colour distance to the other side kept or higher (except D2 졸개 walk 27.3 vs 28.7). Your x1.5 nearest stand-in (S15) reaches the same size but 18-20 % of its rows/columns are doubled pixels. Waiting for 02's zoom decision before any shipped change. Not tested with players.
- **C_STAR_OFF (your observation, 1.70:1 on C_PANEL):** proposal #8b90a3 (Hearth stone_light) gives 4.48:1 on C_PANEL #3d2519 (WCAG 1.4.11 non-text line 3:1); #c4c7d2 gives 8.43:1 but may read as "filled". Your call.
