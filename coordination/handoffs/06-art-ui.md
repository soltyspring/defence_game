# 06-art-ui handoff
Updated: 2026-11-01 ~08:56 KST. Session: this Kiro window (former 06-services). Quota may reach 97 % around 08:50–09:10.
Processed: up to the 08:3x dispatch (HUD 3:1, store art, title); 03-art U3 (08:05 review: tank card loses the shield cross, ranged
card reads as "brown hood"), 04 reply (tray 290×64 at 800 wide), 07 293d51c (U1 PASS), coordinator 08:35 (docs/art/branding/** and
docs/art/evidence/branding/** are 06's).

## Pushed this round (git ls-remote checked after each push)
- e3a7756 launcher fix (66 dp circle, strict corner rule) + store 512 / feature graphics / adaptive / previews regenerated (clean HEAD copy).
- aaf556a HUD edge variants E1/E2 on the new ground + 09 request W-2 (ground band L* ≥ 39 / 43).
- d00b0ca title T1–T4 measured from the menu slot + title_block rule: all PASS.
- This commit: status, handoff, 04 R6 note.

## Open / exact next steps
1. 09 W-2 answer → when the ground band changes: `python tools/art/ui_art/bg_swap.py --sha <09 SHA> --out build/ui06/bg_<sha>`, then
   `hud_mock.py --frames build/ui06/bg_<sha> --layers build/ui06/bg_<sha>/layers` for 04-now, B, C (and E1) with ko and en;
   same table in `docs/art/ui/HUD_ATTENTION_CRITERIA.md`.
2. en run of the 92a1718 table (not done; ~1.5 min per variant).
3. 03 U3 review: add a `CARD_CROP` window for `tank` so the loaf shield + cross stays in the badge; consider ranged (roll + basket).
   Re-run `card_preview.py --criteria`, rebuild ui_main in a clean HEAD copy, send to 07.
4. 03 approval of NEW names (`hud_tray`, `btn_skill`, `chip_resource`, `btn_round`, `card_<uid>_off`, econ frame) and `ink`: then add to
   ui_main (must stay 256×256, 08 U8-1), clean HEAD copy build, ask 07 to judge. Draw at 04's sizes (tray 290×64 / 260–290).
5. 10 v0.34: add `-c core.eol=lf` to `tools/art/ui_art/ui_capture.ps1` git archive (low risk, not done).
6. Feature graphic for upload (`docs/services/store_assets/feature_<loc>.png`) is a frozen services path: not written.

## Rules I keep
Godot only via `coordination/heavy_run_detached.ps1 -Label 06-<task> -ScriptFile <job>` after a syntax check (headless unless a
capture is needed, DISPLAY2, one variant per job). No Godot run this session. Never build.py in the shared tree.
Q1 A, Q2 deferred (no shop/ad art), Q3/Q4 fixed, Q5 B. No human play test, no real-phone check yet.
