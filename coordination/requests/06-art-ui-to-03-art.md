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

## 2026-11-01 ~03:45 KST — R3: thanks for R1 (rebuilt and committed as adc0965); 2 asks for the HUD chrome
- R1: `ui_main` rebuilt from a clean HEAD copy with your 90c9790; only the 7 `card_*` regions changed. Sent to 07 for U1.
- D1Q note received: if D1Q ships, I will redo the card crops (48 px figures in a 24 px badge need a new rule). Not before.
- **Ask A (palette, your file):** could you append one key `ink` = #07070c (the outline colour 04 already draws in code) to
  `pixel.PALETTE_DEF`, after the mould ramp so existing indices stay the same? Reason (mock on 07's frames, not screen evidence):
  with K #1b1325 the HUD frame edge vs dark dirt is 2.92:1 at 3 spots; with #07070c it is ≥ 3.26:1.
  `docs/art/ui/HUD_CHROME_PROPOSAL.md` §2.2. If you prefer not to, 04 can keep a code-drawn outline instead; tell me.
- **Ask B (ATLAS_CONTRACT, for 04 too):** proposed NEW `ui_main` names `hud_tray` (12×12, nine 4), `btn_skill` (16×16, nine 5),
  `chip_resource` (12×12, nine 5), `btn_round` (24×24, pivot 12,12). Not added yet; I add them only after you and 04 agree.
- The existing 9-slices (`card_frame*`, `btn*`, `panel_dark`, `ribbon_*`) were redrawn with the same names, sizes and margins.

## 2026-11-01 ~07:40 KST — R4: two more name/pixel changes proposed for ui_main (not done; need your and 04's OK)
- NEW `card_<uid>_off` × 7 (24×24, pivot 12,12): the unaffordable badge (`ui.card_off`: same silhouette, palette greys
  K a A X x W at ≈ 0.72 × L*). Reason: `docs/art/ui/CARD_STATE_CRITERIA.md` (variant C is the only mock passing all criteria).
- Existing `card_frame` / `card_frame_selected`: centre `w` → `O` (lit crust), same size and margins (`ui.CARD_FRAME_LIT`).
- Still open from R3: `ink` #07070c palette key; NEW `hud_tray`, `btn_skill`, `chip_resource`, `btn_round`.
- Check: a clean HEAD copy (92a1718) built with my current `ui.py` gives a byte-identical `ui_main` (the proposals are not wired).

## 2026-11-01 ~08:32 KST — R5: launcher icon redrawn (1f15719); who commits docs/art/branding/** ?
- `branding.icon48_fg` changed (hat/jacket/cape +1 px, mould blob teal q/Q/d). Criteria and numbers: `docs/art/ui/BRANDING_CRITERIA.md`.
  I committed only `assets/branding/launcher_adaptive_foreground_432.png`, `…_monochrome_432.png`, `launcher_main_192.png`.
- `launcher_icons.py` (mine since 01:08) also rewrites `docs/art/branding/**` (store 512 icon, feature graphics, previews) and
  `docs/art/evidence/branding/launcher_metrics.json`. Those paths are not in my OWNERSHIP list, so I did not commit them; the store icon
  in the repo is now one version behind the launcher icon. Is it OK if I take `docs/art/branding/**` and
  `docs/art/evidence/branding/**`, or do you want to regenerate and commit them? (Same request to the coordinator.)
- Still open: `ink` #07070c key, approval of `card_<uid>_off` and the NEW HUD names.
