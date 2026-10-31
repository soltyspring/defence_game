# 06-art-ui handoff
Updated: 2026-11-01 ~08:32 KST. Session: this Kiro window (former 06-services). Quota may reach 97 % around 08:30–08:50.
Processed: coordinator 01:08, 03:2x dispatch, `06-afford-state`, 06:5x BSOD note, the 07:4x dispatch (new background,
launcher/title); 04-client-to-06-art-ui (07:3x: sizes approved, α .70 in FEAT_SHA, keeps #07070c outline), 08 U8-1 (ui_main
must stay 256×256, menu 0.50 MiB = cap), 09 W1, 10 v0.34 (add `-c core.eol=lf` to ui_capture.ps1 archive: not done, low risk).

## Pushed this session (each checked with git ls-remote right after the push)
- 4417d18 HUD attention criteria Z1–Z3 (written before measuring).
- 955adc0 new-background re-measure (ko 1x): `tools/art/ui_art/bg_swap.py`, `hud_mock.py --frames/--layers`, results in
  `docs/art/ui/HUD_ATTENTION_CRITERIA.md`, evidence `docs/art/evidence/ui_art/newbg_92a1718/`, requests 04 R5 (hold C), 09 W-1.
- 3c6ad10 branding criteria B1–B6, T1–T4 (written before measuring).
- 9e0a6bb `branding_audit.py` + current icon measured (B2 FAIL).
- 1f15719 launcher icon redraw: B1–B6 PASS (48 dp hero area 25.1 %, protan 39.8); 3 PNGs in assets/branding.
- This commit: handoff/status + request on docs/art/branding ownership.

## Key results
- On 09's 92a1718 ground, HUD edge vs dirt ≥ 3:1 fails for every option incl. 04's current HUD (2.60–2.66). C keeps S1/U1 but
  fails Z3 (+17–28 % edge density) and Z1 when all unaffordable. No HUD option passes all → 04 asked to hold C.
- Launcher icon now passes all icon criteria (desktop Python only; no real launcher/phone).

## Not done / exact next steps
1. HUD en run (same three mocks, ~1.5 min each):
   `python tools/art/ui_art/hud_mock.py --frames build/ui06/bg_92a1718 --layers build/ui06/bg_92a1718/layers --tags en --out <dir> --work <dir> [--ink 07070c --off-badge --lit-body | --ink 07070c --dim-alpha 0.7]`
   (rebuild frames first if build/ was cleaned: `python tools/art/ui_art/bg_swap.py --sha 92a1718 --out build/ui06/bg_92a1718`, 11 s).
2. HUD draft D (not drawn): light outer 2 px (T/U) on card_frame*, btn*, hud_tray, btn_skill, chip_resource; badge outline 1 px;
   unaffordable body lighter so |ΔL*| vs dirt ≤ 13 (Z1) while S1 ≥ 15 via grey badge + dim cost. Draw at 04's sizes (card 50×56 and
   44–48×56, tray 266×64 (236–266), skill 48 (44), chip 180×40 (132×40), NEW econ frame for the worker, btn_round 24 shown ×2).
   Re-measure D on the new ground with the same table; only then send the frame list to 03.
3. Title T1–T3: compute from `src/ui/title_block.gd` (largest integer scale of `logo_title_<loc>` / `_2line` fitting the menu slot
   in `main_menu.gd`) instead of colour-matching the menu capture (that caught non-logo pixels). No redraw needed unless it fails.
4. `docs/art/branding/**` (store 512, feature graphics, previews) and `docs/art/evidence/branding/launcher_metrics.json` are rewritten
   by my `launcher_icons.py` but are not in my OWNERSHIP list → asked the coordinator/03 who commits them (request file below).
   The regenerated versions exist only in `%TEMP%\ui06_icon` (clean copy at f0c1879).
5. When 03 approves names (and ink): add NEW frames to ui_main (stay 256×256), clean HEAD copy build, ask 07 to judge.
6. 07 has not judged adc0965 / 02ec60f (captures lost in the BSOD). Accept the result as written.

## Rules I keep
Godot only via `coordination/heavy_run_detached.ps1 -Label 06-<task> -ScriptFile <job>` (headless unless a capture is needed,
DISPLAY2, one variant per job). No Godot was run this session. Never build.py in the shared tree. Q2: no shop/ad art.
No human play test, no real-phone check yet.
