# Visual checks on the secondary monitor (owner: 07-qa)
Run 2026-10-31 16:02 +09:00. Build: clean `git archive` of committed HEAD **0590e7a** in `%TEMP%\qa07_head` (02's broken work-tree `src/core/app.gd` is not in it). Launcher: 04's `tools/build/visible_launch.ps1 -ProjectPath` (QA-R5, delivered). Script: `tests/acceptance/capture_visual.gd`. Desktop Windows, NVIDIA RTX 2070 SUPER, Compatibility renderer. **Not a phone; not Android certification.**

Placement evidence (launcher JSON, `evidence/visual-0590e7a/launch_*.json`): all 4 windows verified on `\\.\DISPLAY2` (non-primary, work area -1920,174..0,1206), never on the main monitor.
| Tag | Locale | Window | Scale (stretch `canvas_items`, integer) | Result |
|---|---|---|---|---|
| ko_1x / en_1x | ko / en | 640×360 at -1280,510 | 1× | EXIT_0 |
| ko_2x / en_2x | ko / en | 1280×720 at -1600,330 | 2× | EXIT_0 |
Logical view was 640×360 in all four (report `view`). Save isolated at `user://qa07/visual_save.json` (all rounds unlocked for the round-select capture).

## C1 Round names on 2 lines inside the round-select tile (QA-B010 follow-up) — PASS
- Rendered: `evidence/visual-0590e7a/{ko,en}_{1x,2x}_2_round_select.png`. Every name is complete; wrapped names: KO 곰팡이 성벽을 / 부숴라, 부풀어 터지는 / 효모; EN Spores / Incoming, The Mold / General, Break the Mold / Wall, Mold / Onslaught, The Rot / Overlord.
- Geometry (from `*_report.json`, TouchButton's own rules): tile 103×148 logical; two-line name block 60–88 px; big number ends at 30 px; star row starts at 112.5 px → 24 px clearance above the stars, 30 px below the number. 0 of 10 tiles fail in any of the four runs.
- Limit: these captures use the full 640×360 safe area. The narrowest notch layout (34+34 px insets, 83 px label width) is covered only by the headless TH-FIT-ROUND check, not by a rendered frame. "Break the Mold" fills ~97 of ~97 px at 1×: no margin left for longer translations.

## C2 Disabled services: no ad / purchase UI — PASS (for screens reachable today)
- `Services` autoload present, `mode = "disabled"`, `diagnostics().live` = real_ads false, real_billing false, remote_analytics false, trusted_verifier false (all 4 runs).
- Text scan of every visible Label / Button / TouchButton on menu, round select, settings, battle HUD and result for 광고/구매/상점/결제/보석/젬/패키지/ad/ads/shop/store/purchase/gem/iap/restore/remove ads: **0 hits** in ko and en, 1× and 2×.
- Rendered: `{ko,en}_2x_3_settings.png` (frame rate, SFX, music, damage numbers, screen shake, credits, close; no store/restore), `{ko,en}_2x_6_result.png` (menu / retry / next; no "double reward" ad button).
- Limit: a scan of visible text only; an icon-only ad button would not be caught. Screens that do not exist yet (shop, upgrades) are not covered.

## Caveat for the gameplay frames
`capture_visual.gd` drives r01 with the 02 scripted bot (casual policy) by stepping the simulation up to 30 s and 60 s inside one frame. Transient UI (toasts 1.6 s, banners 1.8 s, timed tutorial hints) therefore all appear at once in `*_r01_t30/t60.png`. Those frames are valid for static layout, framing and colours, **not** for message timing or overlap.

## C3 Narrowest layout, rendered (34 px notch both sides) — PASS
Run 2026-10-31 16:12, clean HEAD **5c08bb4**, `tests/acceptance/capture_narrow.gd` via `visible_launch.ps1 -ProjectPath`, `SafeArea.override_insets = (34,0,34,0)` with the unsafe strips painted opaque black. Configs: ko/en × 640×360 (1×) / 1280×720 (2×); all 4 windows on `\\.\DISPLAY2`, EXIT_0. Evidence `evidence/visual2-5c08bb4/`.
- Screens: menu, round select, r08 HUD (worker + 5 cards + 3 skills, the narrowest card slot), r08 result.
- Every visible TouchButton: `last_text_truncated == false` and its rect inside the safe area → **0 problems** in all 4 configs (`*_narrow_report.json`).
- Round select: names wrap to 2 lines inside the narrower tiles (`en_1x_2_round_select.png`); no ellipsis.
- Card labels with theme A names (Baker/Toast/Roll/Loaf/Twist/Oven, 제빵사/식빵병/롤빵병/통식빵/프레첼/화덕포) are complete (`en_2x_3_r08_hud.png`).
- Base HP numbers drawn in full: player "2000/2000", enemy "2400/2400" (hud_top.base_labels equals the full text in all 4).
- Art changed after this run (7705aec); layout code did not. Limit: insets are emulated; a real cutout shape and the Android gesture area are untested.

## C4 r08 crowd in real time (no fast-forward)
`tests/acceptance/capture_crowd.gd`, `--autoplay --round=r08`: App runs the 02 competent bot at the normal fixed step, so game time follows wall time (drift ≤ 0.13 s until a pause). Every rendered frame logs visible HUD messages (toast, tutorial hint, wave banner, skill tip) with text-tight rectangles, units, projectiles, damage numbers. 2× (1280×720), secondary monitor.
| Run | HEAD / art | Locale | Valid duration | Peak units | Max projectiles | Max damage numbers | Max messages at once | Message rect overlaps |
|---|---|---|---|---|---|---|---|---|
| visual2 ko | 5c08bb4 (pre-7705aec) | ko | 172 s (round lost) | 35 | 3 | 21 | 3 (≈1.5 s at 20 s) | 0 |
| visual2 en | 5c08bb4 | en | 196 s (round lost) | 32 | 3 | 21 | 2 | 0 |
| visual3 ko | 3b2d830 (new art) | ko | 99 s, then paused* | 19 | 1 | 4 | 2 | 0 |
\*At wall 99.5 s the game window lost focus (other desktop windows) and the HUD auto-paused (`ko_2x_t101.png`). This is the intended lifecycle pause, observed on a real focus loss; data after 99.5 s is discarded.
- Messages: **PASS** — up to 3 messages coexist briefly but never overlap; each is readable in the frames.
- Ally vs enemy, new art (`evidence/visual3-3b2d830/ko_2x_peak.png`): allies gold/yellow, Mold Legion grey-teal, enemy base grey; also separable in the simulated protan/deutan/tritan frames (`*_peak_{protan,deutan,tritan}.png`, `tests/acceptance/cvd_sim.gd`, Machado 2009). Supports QA-B011 closure.
- **QA-B012 (P3, 02)** damage numbers: drawn with `ThemeDB.fallback_font` at 8 logical px (battle_view.gd `_draw_text`), not the bundled pixel font; up to 21 alive at once; stacked numbers merge ("1212" over the hero in `visual2…/ko_2x_t046.png`) and sit on the unit HP bars.
- **QA-B013 (P3, 04 HUD + 02 unit bars)** under protan/deutan simulation the green player-base bar and red enemy-base bar (and unit HP bars) become the same olive/yellow (`ko_2x_peak_deutan.png`). Side is still given by position and VS, so not a blocker.
- Bot result: the competent bot lost r08 in both full runs (known OPEN since D18, r04–r10 balance). Not a UI finding.

## M8 run — clean origin/main HEAD 68866e9 (includes 04 6051b3c QA-J3 + upgrade screen, 03 7705aec art)
Script `tests/acceptance/capture_m8.gd` via `visible_launch.ps1 -ProjectPath %TEMP%\qa07_head`; all windows on `\\.\DISPLAY2`, EXIT_0 (`evidence/visual4-68866e9/launch_*.json`). Configs: ko/en × 1×/2× with 34+34 px notch (masked black) + ko 2× full width. CVD frames via `cvd_sim.gd`.

### C5 QA-J3 worker vs soldier card, resource names — PASS
- Worker button `shape = econ` (clipped octagon corners, brown fill, gold top strip) vs soldier `shape = rect` (blue-grey), same 50×56 size (`*_m8_report.json` j3). The shape difference survives the deutan/protan simulation (`ko_2x_notch_3_r01_hud_t02_{deutan,protan}.png`), so it does not rely on colour.
- HUD shows the resource names: ko **반죽 / 기력**, en **Dough / Energy** (top-left, `ko_2x_notch_3_r01_hud_t02.png`, `en_1x_notch_3_r01_hud_t02.png`); `tut_buy_worker` uses the same word.
- Limit: no human tested whether the shape alone is understood (D11).

### C6 Upgrade screen, disabled services (Q2 보류) — PASS, one text-ownership finding
- Opened from the main menu in all 5 configs. `purchase_available() == false`; all 5 buy buttons disabled (grey); notice **"※ 강화 기능 준비 중입니다"** / **"※ Upgrades are coming soon"**; panel and buttons inside the safe area at 34+34 notch; no truncated labels.
- Monetization text scan (광고/구매/상점/결제/보석/젬/패키지/광고 제거/ads/shop/store/purchase/gem(s)/iap/remove ads/restore) on menu, upgrade panel and HUD: **0 hits**. Prices are in-game coins only.
- **QA-B014 (P3, 01)**: the 10 `ui.upgrade*` keys used by upgrade_panel.gd are not in `data/text/ko.json` / `en.json` (DATA-13/14 FAIL at 68866e9); the screen renders only because of 04's built-in fallback table.
- Observation: disabled buttons still show bright gold prices, which reads as "buyable but not now". Acceptable with the notice; no bug filed.

### C7 Working title (Q3) — NOT_IMPLEMENTED, projected to clip in English
- In-game title at 68866e9 is still `ui.title` = "레인 디펜스" / "Lane Defence" (`*_1_menu.png`). `project.godot` `config/name = "Lane Defence"`.
- Projection with the committed menu code (FONT_XL bold, centred in the safe area): **"Bakery Knights: Mold Defense" = 588 px** vs safe width **572 px** at 34+34 notch → would overflow by 16 px; fits at full 640 px with 26 px margins. **"빵집 기사단: 곰팡이 디펜스" = 456 px** fits both.
- 360 dp height / 640 logical width is the layout measured here (canvas_items 640×360). Waiting for 01 (text) and 04 (menu title layout); final store name needs a human KIPRIS check of classes 9/41 (Q3).

### C8 r08 crowd, new art, real time — PASS (messages), J1 still open
- 240 s continuous at 2× (`--autoplay --round=r08`, competent bot, normal fixed step). One real window focus loss at 85.08 s triggered the HUD auto-pause; the harness resumed 2 ms later and logged it (`focus_log`); max wall−sim drift 0.11 s, so the run stays real time. Run condition: launcher keeps the game window topmost on DISPLAY2; other worker terminals on the primary monitor were active, which is the likely focus thief.
- 14 389 frames: peak 34 units, max 7 projectiles, max 24 damage numbers, max 2 HUD messages at once, **0 message overlaps**.
- At the peak-unit frame (`ko_2x_crowd_peak.png`, sim 160 s) only allies and the player base are on screen: the 34 units are spread over the lane and every enemy is off camera.

## M9 run — clean origin/main HEAD 97c8b9c (17:11–17:19), import guard on (`import_missing_after_guard=0`, 0 failed resource loads)
The earlier attempt at 16ea2c2 (run 20261031-165935) is **void**: its snapshot import produced 3 of ~195 imported files, so fonts/atlases/audio fell back (116 "Failed loading resource" lines). The runner now re-imports until every `.import` target exists and refuses to run otherwise (`tools/qa/run_acceptance.ps1`). Earlier HEAD runs were checked: 0 failed loads in all of them.

### C9 QA-B014 — 10 keys VERIFIED, 1 new key missing
- `-Head` run 20261031-171211: the 10 `ui.upgrade*` keys added by 01 in c15e43a are present in ko+en. DATA-13/14 still FAIL on one key: **`ui.upgrade_save_uncertain`** (upgrade_panel.gd, added by 04 after c15e43a) → **QA-B016 (P3, 01 text, cc 04)**.

### C10 QA-B013 HP bars under CVD — PARTIAL
- HUD top bars: the enemy base bar is striped; under deutan/protan the striped enemy bar vs the solid player bar is clear (`evidence/visual5-97c8b9c/ko_2x_crowd_t025_deutan.png`). PASS.
- World-space bars are still hue-only: the unit HP bars above units and the enemy base's own bar become the same olive under deutan, with no stripe (`zoom_units_deutan.png`, `zoom_basebar_deutan.png`, 4× nearest zoom). QA-B013 stays OPEN for the battle_view bars (02 draws them).
- Same frame: damage numbers still use the fallback font and overlap ("85" over "5") → QA-B012 unchanged.

### C11 Working title (Q3) and QA-B015 — VERIFIED by render
- The menu now draws 03's title logo instead of the `ui.title` text (the key still reads "Lane Defence" / "레인 디펜스"). English logo on 2 lines **"Bakery Knights / Mold Defense"**, Korean **"빵집 기사단 / 곰팡이 디펜스"**; complete and inside the safe area at 640×360 with 34+34 notch at 1× and 2×, and at full width (`*_1_menu.png`). The 588 px one-line overflow predicted in C7 does not occur because 04 wraps after the colon (7461636). QA-B015 VERIFIED.
- Remaining: `project.godot` `config/name` and `ui.title` still say "Lane Defence" (OS app label, other screens); store name waits for the human KIPRIS check (Q3).

### C12 Upgrade screen now active — PASS (no monetization)
- `purchase_available()` is now true (02's `Save.buy_upgrade` landed): buttons enabled, no "coming soon" notice. Currency is in-game coins only; 0 monetization words on menu, upgrade panel and HUD in all 4 configs (Q2 보류 respected).

### C13 r08 crowd at 97c8b9c — 120 s real time, no pause (`focus_log` empty), 0 message overlaps, peak 29 units.

## M10 run — clean origin/main HEAD 09508b1 (includes 01 a262640, 04 8104970, 02 4b5926d), 17:30–17:36
Import guard 0 missing, 0 failed loads. Lock-screen guard: mean brightness of every capture sampled; none below 8/255 (no black frames, PC was not locked). All windows on `\\.\DISPLAY2`, EXIT_0 (`evidence/visual6-09508b1/launch_*.json`).

### C14 `ui.title` text fallback (forced) and logo, 34+34 notch — PASS
- `--force-text-title` sets 04's `TitleBlock.force_text` (8104970); `title_block.last_mode == "text"` confirmed.
- en: "Bakery Knights:" 36 px bold **312 px** + "Mold Defense" 24 px **174 px**, both ≤ 572 px safe width, 1× and 2× (`en_{1x,2x}_notch_text_1_menu.png`).
- ko: "빵집 기사단: 곰팡이 디펜스" one line, 36 px bold **456 px** ≤ 572 px, 1× and 2×.
- Without forcing, the logo is drawn (`*_notch_logo_1_menu.png`); both fit. `ui.title` now holds the Q3 working title in ko/en (a262640).

### C15 Resource term "밀가루 / Flour" consistency — FAIL (one string)
- HUD resource label: **밀가루 / Flour** (`ko_1x_notch_text_3_r01_hud_t02.png`); data: `res.supply`, `unit.worker.desc`, `tut_buy_worker`, `toast.not_enough_gold` all use 밀가루 / flour.
- Upgrade screen row 5 still reads **"보급 증가" / "Supply Boost"** (`upgrade.supply_regen`, `*_notch_text_2_upgrades.png`), the old resource word. → **QA-B018 (P3, 01)**.
- Observation: at 1× with notch the HUD top-left drops the "+x/s" income rate (shown at 2×/full width); appears to be 04's width fallback, not filed.
- Monetization words: 0 on menu, upgrade panel, HUD in all 6 configs (Q2 보류).

## C16 APK launcher label (Q4) — PASS on the existing debug APK
`tools/qa/check_apk_label.ps1` (aapt2 `dump badging`, build-tools 36.1.0) on `build/android/defence-debug.apk` (59 290 830 bytes, modified 17:37:43): default **"Bakery Knights"**, `ko` **"빵집 기사단"**, all other 87 locales "Bakery Knights"; exit 0 (`evidence/apk-label/defence-debug_20261031-1737.txt`).
Limits: the APK was built by 02 from its working tree at 17:37, before the label commit 4b5926d (17:42); 07 did not export from HEAD (avoids import/export collisions with 02/04). This is a file read, not a launcher on a phone. Package id is still `com.soltyspring.lanedefence` (cannot change after first store upload; flagged to 01/02).

## M12 run — clean origin/main HEAD fca9346 (includes 03 11ceacb/e3c4621/6949499, 04 a6369ba/baa1672/1d1e4e3, 02 09508b1/4b5926d, 01 7b93d1f), 18:32–18:40
`-Head` run 20261031-183232: PASS 152 · FAIL 0 · NOT_TESTED 2; import guard 0 missing, 0 failed loads; services exit 0. Captures on `\\.\DISPLAY2`, EXIT_0; brightness guard: **0 black of 50** frames (PC not locked). Executed per RETEST_PLAN_1830.md.

### V1 Sky share — PASS (03's line) and near the coordinator's 18 %
`tools/qa/frame_metrics.py --rev fca9346` (exact sky-layer palette of this revision):
| Frame | full frame | band y 12–83 % |
|---|---|---|
| r01 t≈2 s ko 2× notch | **17.0 %** | 15.7 % |
| r01 t≈2 s ko 1× notch | 17.0 % | 15.7 % |
| r08 t 26 s ko 2× | 21.5 % | 21.1 % |
| r08 t 156 s ko 2× | 20.8 % | 20.1 % |
Old meadow baseline with the same method: 39.5–46.1 % full frame. Sky share roughly halved; ≤ 35 % in every frame.

### V2/V3 Village identity and nest — PASS (visual)
Wheat-field village with bakery houses and windmills (`ko_2x_notch_3_r01_hud_t02.png`); enemy base is a dark mould mound with a cave mouth facing left and four spore stalks (`ko_2x_crowd_t026.png`, zoom `zoom_nest.png`). Under deutan the nest stays a dark mass against the light village (`zoom_nest_deutan.png`). QA-J1 identity part satisfied; the J1 enemy-visibility part still has no target (r01 casual bot: objects 5.0–8.0 % of the view; enemies on screen 0 at t = 7–22 s, 1 at 27 s, 4 at 32 s after a262640 moved the first wave earlier; `ko_2x_notch_m8_report.json` j1).

### V4 Damage numbers (QA-B012) — FAIL, reopened with a new cause
- `capture_crowd.gd` r08, 185 s real time, no pause: `battle_view._placed_text` showed up to **14** numbers drawn in one frame and **1 133** overlapping rectangle pairs summed over 11 089 frames.
- Cause (code, 09508b1 `_draw_text`): each number's rect is `NUM_PX + 1` = 11 px tall but the stagger step is `NUM_PX` = 10 px, so after one step the new rect still overlaps the old one by 1 px and is shifted again; the 6-step guard is therefore used up after about 3 stacked numbers and the 4th and later are drawn overlapping.
- New readability problem on the new background: numbers are light grey/white with a 1 px shadow and fade, drawn over light village walls ("2", "25" in `zoom_nums.png`, 4× zoom); contrast is low in normal vision and in deutan (`zoom_nums_deutan.png`).
- Pass: `damage_number_overlaps == 0` over the same 180 s run and numbers legible over the village (dark outline or plate).

### V5 World HP bars under CVD (QA-B013) — still PARTIAL
HUD bars stay separable (striped enemy bar). World bars: in `zoom_nums_deutan.png` the ally bar and the enemy unit bars have the same olive fill; only the fill length differs. No pattern or luminance step. Unchanged by 1d1e4e3 (that commit striped the HUD bar).

### V6 Title — PASS
Logo mode, ko/en, 1×/2× with 34+34 notch (`*_notch_1_menu.png`); 0 monetization words on menu, upgrades, HUD.

### V8 Launcher label — WAITING (QA-W004)
Only `build/android/defence-debug.apk` from 17:37 exists (pre-4b5926d work tree). No APK with a named commit SHA, so not judged.

## M14 (2026-11-01 01:32) — QA-B012 retest after 02 52f9fa3, clean HEAD 278d52b
Run: inside `coordination/heavy_run.ps1` with the full `-Head` run. `visible_launch.ps1 -ProjectPath %TEMP%\qa07_head -Script res://tests/acceptance/capture_crowd.gd -Resolution 1280x720 -UserArgs '--autoplay','--round=r08','--seconds=185','--every=10','--locale=ko','--tag=ko_2x'`.
- Placement: the window was on `\\.\DISPLAY2` (secondary) at -1600,330, EXIT_0, private APPDATA.
- Frame check: no black frames (mean brightness 137–139, near-black share 3.8 %).
- Same pass rule as V4. Evidence: `evidence/visual8-278d52b/`.
### V4 Damage numbers (QA-B012) — PASS, VERIFIED
- `damage_number_overlaps` = **0** over 11 095 frames and 185 s real time (fca9346: 1 133). Wall clock minus sim time stayed ≤ 0.12 s, with no pause.
- Up to 9 numbers were drawn in one frame, 20 343 number-frames drawn in total. `damage_numbers_dropped` (02's new `texts_dropped`) = 0, so no number was hidden to avoid an overlap.
- Legibility (`zoom_nums_t051.png`, 4× nearest crop of `ko_2x_t051.png`): "8" and "15" over the light cream village wall are readable. The new 1 px dark outline separates them from the wall. Stacked numbers keep a gap and do not sit on the HP bars. Fading numbers are faint, as intended.
- Limits: desktop 2× frame judged by eye by 07. Physical size on a phone (04 ZOOM_PREVIEW: Galmuri9 10 px digits 1.43–1.63 mm) is a separate question for J1/E2, not part of this pass rule. CVD was not re-checked; that is QA-B013 (world bars), still PARTIAL.
