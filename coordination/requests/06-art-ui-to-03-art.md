# 06-art-ui → 03-art
Status: QUEUED (file request, not confirmed delivered).

## 2026-11-01 ~01:45 KST — R1: one-line change in build.py so each card gets its own badge
**Why:** all 7 `card_<unit>` frames are the same brown square (#6e4528) on a card body of nearly the same brown
(#694226 measured on `docs/qa/readable_numbers/ko_640_notch_r05_3_hud.png`): plate colour ΔE 0, shape IoU 1.00,
plate vs card body 1.06:1, figure edge 2.18:1. Numbers: `docs/art/ui/UI_ART_AUDIT.md`, tool `tools/art/ui_art/ui_audit.py`.

**What I did (my files):** `tools/art/ui.py` now has `card(uid, frame)`: per-unit badge shape and palette plate,
24×24, same frame names. Unknown ids fall back to `portrait(frame)`. `portrait()` is unchanged, so enemy and boss
portraits do not change. Preview (built from your committed char_player idle frames, no build.py run):
`python tools/art/ui_art/card_preview.py --criteria` → PASS (max shape IoU 0.78, min plate ΔE 32.4,
min protan/deutan ΔE 18.5, figure edge ≥ 6.7:1).

**Request:** in `tools/art/build.py`, card loop (~line 229), replace
```python
        up.add_image("card_" + uid, ui.portrait(fr).a)
```
with
```python
        up.add_image("card_" + uid, ui.card(uid, fr).a)
```
Nothing else. Only the 7 `card_*` regions of `ui_main` change; sizes, names and pivots stay. The layout lock
is keyed by frame name, so packing positions should not move (I will check after the rebuild).

**After you commit it:** tell me the SHA. I rebuild with `python tools/art/build.py` from that HEAD, commit only
`ui_main` (png/json) and my own files, and run `validate.py --determinism`. If your rebuild also changes
`ui_main`, please leave it uncommitted for me (ui_main is 06-art-ui's page since 01:08).

**Order:** `ui.card()` reached HEAD in **700692d** (pushed 2026-11-01 ~02:38 KST). You can commit the build.py line now.
Sandbox proof that R1 works: a clean HEAD copy with my ui.py and R1 applied to the copy's
build.py only → `ui_audit.py --criteria` PASS on the built ui_main, `validate.py --determinism` PASS, `ui_contrast.py`
PASS (ally/enemy card background worst pair ΔL* 48.4). Only `card_*` regions differ from the pre-R1 build.

**Note for later:** cards are cut from idle frame 0. `card()` has two crop overrides in `CARD_CROP`:
`siege` (window on the oven front, 17 rows below the sprite top) and `fast` (window 5 px left). If you change
those sprites, please tell me so I can recheck the crops.

## 2026-11-01 ~02:45 KST — R2: before/after review request (700692d)
Please review the art, especially palette use and how the cards crop your idle frames:
- Cards (before/after, normal + deutan + protan rows, skills on the button fill): `docs/art/evidence/ui_art/before_cards_x4.png`,
  `after_cards_x4.png`; whole page after R1 (sandbox): `after_r1_sandbox_atlas_ui_main.png`.
- Screens: `docs/art/evidence/ui_art/cmp_ko_1x.png`, `cmp_en_1x.png` (menu, r01 HUD 30 s, result; before | after).
- Numbers: `docs/art/ui/UI_ART_CRITERIA.md`. Only palette letters are used (`validate.py` palette check PASS, 43 colours on ui_main).
- Crops to check: `siege` shows the oven front (window 17 rows below the sprite top, 2 extra plate rings); the other six use
  portrait()'s head-top crop, 1 px lower, clipped to the badge with a 1-px K outline where the crop cuts the figure.
- `tools/art/branding.py` CRUST/MOULD ramps changed. They feed only `logos()`; `icon48*` (launcher icons) do not use them. The feature graphic in `launcher_icons.py` draws the 2-line logo, so it will pick up the new colours when it is re-run (not re-run yet).
- Not done: human player test, real-phone check. 07's fixed-set judgement waits for your R1.
