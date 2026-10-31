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
