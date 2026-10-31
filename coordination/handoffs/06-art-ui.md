# 06-art-ui handoff
Updated: 2026-11-01 ~08:30 KST. Session: this Kiro window (former 06-services). Quota may reach 97 % around 08:30–08:50.
Processed: coordinator 01:08, the 03:2x dispatch, `06-afford-state`, the 06:5x BSOD note, the 07:4x dispatch (new background,
launcher/title); 04-client-to-06-art-ui (07:3x, sizes + α .70), 08 U8-1 (menu 0 MiB headroom, ui_main must stay 256×256),
09 W1 (07:20), 10 v0.34 (add `-c core.eol=lf` to ui_capture archive: not done yet, low risk).

## Current task (07:4x dispatch)
(1) HUD attention criteria + re-measure on 92a1718 background — **done for ko 1x** (criteria 4417d18; results 955adc0, ls-remote verified).
(2) Launcher icon + title: criteria committed (3c6ad10); current icon measured (`branding_audit.py`, `docs/art/evidence/ui_art/branding_before.json`): B1/B3/B4/B5/B6 PASS, **B2 FAIL** (hero area 23.7–24.2 % < 25 %, hero vs mould protan ΔE 18.2–18.5 < 20). T1–T3 measurement not reliable yet (menu bbox caught non-logo pixels); recompute from title_block.gd slot rule. Redraw not started.
(3) 03/04 approvals: 04 approved names/sizes (07:3x reply); 03 has not answered ink or names → nothing added to ui_main.

## Results so far
- New background breaks the HUD-vs-dirt 3:1 for all options incl. 04's current HUD (2.60–2.66). C keeps S1/U1 but fails Z3 and
  Z1 (all unaffordable). Asked 04 to hold C (R5), told 09 (W-1, FYI only).

## Exact next steps
1. en run of the same three mocks (each ~1.5 min):
   `& $env:TEMP\run_nb.ps1` equivalent = `python tools/art/ui_art/hud_mock.py --frames build/ui06/bg_92a1718 --layers build/ui06/bg_92a1718/layers --tags en ...`
   (bg frames: `python tools/art/ui_art/bg_swap.py --sha 92a1718 --out build/ui06/bg_92a1718`, 11 s).
2. Draft D: outer 2 px light edge (T/U) on card_frame*, btn*, hud_tray, btn_skill, chip_resource; badge outline 1 px; off body
   lighter (|ΔL*| vs dirt ≤ 13). Draw at 04's sizes (card 50×56 and 44–48×56, tray 266×64, skill 48, chip 180×40, econ frame NEW).
   Re-measure D on the new background with the same table (S1, S2, U1, ground, Z1–Z3, U2, U3).
3. Launcher/title (2): write criteria first (66 dp safe circle on 108 dp, 48/36 dp silhouette, light/dark wallpaper contrast,
   monochrome layer, genre icon distinctness vs the 5 store icons, title line breaks/cut-off at 393 dp), measure current
   `assets/branding` + `ui_title_*`, redraw in branding.py / launcher_icons.py / adaptive_icon.py, clean HEAD copy build.
   Play 512 icon + feature graphic: only check they can come from the same art (docs/services/STORE_GRAPHICS.md sizes).
4. When 03 approves names: add NEW frames to ui_main (must stay 256×256, 08 U8-1), clean HEAD copy build, ask 07 to judge.
5. 07 has not judged adc0965 / 02ec60f yet (captures lost in the BSOD). Accept their result as written when it comes.

## Rules I keep
Godot only via `coordination/heavy_run_detached.ps1 -Label 06-<task> -ScriptFile <job>` (headless unless a capture is needed,
DISPLAY2, one variant per job). Never build.py in the shared tree. Q2: no shop/ad art. No human play test, no real-phone check yet.
