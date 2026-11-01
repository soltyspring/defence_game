# 06-art-ui handoff
Updated: 2026-11-01 ~09:22 KST. Session: this Kiro window (former 06-services). Usage > 93 %: a 97 % stop can come any minute.
Processed: up to the 09:0x dispatch (03 U3 card review); 03 U3 (cb64e7f), 07 293d51c (U1 PASS), coordinator 08:35 (docs/art/branding/**
and docs/art/evidence/branding/** are 06's). No Godot / heavy_run job of mine is queued or running.

## Last pushes (git ls-remote checked)
- e3a7756 launcher icon fix + store 512 / feature graphics regenerated; aaf556a HUD edge variants + 09 W-2; d00b0ca title T1–T4 PASS;
  ef42b73 status/handoff; **bacb018** 03 U3: tank crop proposal (`ui.CARD_CROP_U3`, off by default) + ranged comparison + evidence.

## QA-B021 reopened (07 09:1x) — f43e1a6
- Cause: 04's icon modulate α .45 for disabled buttons (touch_button.gd), not a 06 frame. Reproduced on 07's e8c6d96 frames (error 0).
- α .70 (04's uncommitted value) → r08/r10 0 failing pairs (shape 13.4; 14.6 with tank T1). Asked 04 R7 to commit it; told 07.
  Then 07 rejudges U1 on that 04 SHA. No 06 atlas change needed for this. S1 (state cue) still < 15 → needs body frames (C), tied to U4.

## Open items (in order)
1. **HUD 3:1 — unresolved, waiting on 09 (W-2).** On 92a1718 ground every option (incl. 04's current HUD) is 2.56–2.66:1; best 06-only
   variant E1 2.92 and it hurts Z3/S1. Asked 09: ground band under the HUD (screen y ≥ 296) mean L* 23.4 → ≥ 39 (#07070c outline) / ≥ 43 (K).
   When 09 answers: `python tools/art/ui_art/bg_swap.py --sha <09 SHA> --out build/ui06/bg_<sha>` (11 s), then
   `hud_mock.py --frames build/ui06/bg_<sha> --layers build/ui06/bg_<sha>/layers --tags ko,en` for 04-now, B, C (+ `UI_CARD_CROP_U3=1`),
   same table as `docs/art/ui/HUD_ATTENTION_CRITERIA.md`.
2. **03·04 name approval** for ui_main: 04 approved sizes (card 50×56 / 44–48×56, tray 290×64 / 260–290, skill 48 / 44, chip 180×40,
   pause 40–48, NEW econ frame). 03 has not approved NEW names (`hud_tray`, `btn_skill`, `chip_resource`, `btn_round`, `card_<uid>_off`,
   econ frame) nor the `ink` key. After approval: draw at those sizes, apply `CARD_CROP_U3` into `CARD_CROP`, rebuild ui_main in a clean
   HEAD copy (must stay 256×256, 08 U8-1), `ui_audit.py --criteria`, commit, ask 07.
3. **07 judgement:** U1 PASS on adc0965/02ec60f accepted. Next 07 request = after item 2's rebuild (fixed set ART_BASELINE §4).
4. en run of the new-ground tables (not done).
5. Small: 10 v0.34 add `-c core.eol=lf` to `tools/art/ui_art/ui_capture.ps1` archive.

## Rules I keep
Godot only via `coordination/heavy_run_detached.ps1` after a syntax check (headless unless a capture is needed, DISPLAY2, one job).
Never build.py in the shared tree. Q2 deferred: no shop/ad art. No human play test, no real-phone check yet.
