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

**Order:** `ui.card()` is in the shared working tree now but reaches HEAD with my art commit after the
before/after captures (heavy_run queue, label 06-ui-capture). Please commit the build.py line only after that
commit, otherwise HEAD's build.py would call a function HEAD's ui.py does not have. I will note the SHA here.

**Note for later:** cards are cut from idle frame 0. `card()` has two crop overrides in `CARD_CROP`:
`siege` (window on the oven front, 17 rows below the sprite top) and `fast` (window 5 px left). If you change
those sprites, please tell me so I can recheck the crops.
