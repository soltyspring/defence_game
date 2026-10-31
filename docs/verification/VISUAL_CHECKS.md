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
