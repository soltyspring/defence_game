# 03-art -> 06-services

## A1 2026-10-31 16:38 +09:00 — branding assets for store/release config (QUEUED)
- Working-title logos: res://assets/atlases/ui_title.png frames `logo_title_ko`, `logo_title_ko_2line`, `logo_title_en`, `logo_title_en_2line` (sizes in docs/art/ART_DIRECTION.md section 11). App icon candidate: docs/art/branding/app_icon_candidate_48/96/192.png.
- Status: the title is the user's working title (Q3). The final store name needs the human KIPRIS 9/41 check. Q2 (business model) is DEFERRED, so I made no ad/purchase UI art. Store listing graphics (512 px icon, feature graphic) are not made yet; ask if your release checklist needs them now.

## A2 2026-10-31 16:56 +09:00 — Android adaptive icon layers (QUEUED)
- docs/art/branding/adaptive/ic_launcher_foreground_432.png and ic_launcher_background_432.png: 432x432 px = 108 dp at xxxhdpi (4 px/dp), art at 5 px per art pixel, centred. Godot export preset fields: launcher_icons/adaptive_foreground_432x432 and adaptive_background_432x432; the legacy main_192x192 can use app_icon_candidate_192.png.
- Checked: 0 foreground px outside the 66 dp safe circle, 0 px clipped by circle/squircle/teardrop masks, background fully opaque (docs/art/evidence/branding/adaptive_metrics.json, mask_previews.png, preview_circle_48/96/192.png).
- Not tested on a real launcher or device. Working-title art (Q3) until the KIPRIS check.

## A3 2026-10-31 17:36 +09:00 — logo page path changed (QUEUED)
The logos moved from `ui_title.png` to `res://assets/atlases/ui_title_ko.png` (`logo_title_ko`, `logo_title_ko_2line`) and `ui_title_en.png` (`logo_title_en`, `logo_title_en_2line`). Same pixels. Update any store/release checklist path that pointed at ui_title.

## A4 2026-10-31 18:59 +09:00 — launcher set + store icon 512 + feature graphic 1024x500 (QUEUED)
- Runtime launcher set (assets/branding/): main 192, adaptive foreground/background/monochrome 432. Your check_store_graphics.py on docs/art/branding/adaptive/* (same pixels): safe circle PASS (0 px outside r=132), logo 46.5 x 51.0 dp PASS, background opaque PASS, monochrome PRESENT. Preset keys requested from 02 (A14).
- Store icon: docs/art/branding/store/store_icon_512.png, your check: 512x512, RGBA, 3.8 KB, 0 transparent px, all PASS.
- Feature graphic: docs/art/branding/store/feature_graphic_ko_1024x500.png and _en (RGB, no alpha, 1024x500). The title is a separate layer (feature_graphic_title_<ko|en>_layer.png) over feature_graphic_base_1024x500.png, so after the KIPRIS check only the layer changes. Title plate centred, top 4-35 % of the height; units and both bases in the lower half; bases touch the left/right edges (context only). Your script looks in docs/services/store_assets/ (yours), so please copy the file there if you want it in the check. Content rules (real game art: yes, it is built from the shipped atlases; no ranking/price words: none) need your review.
- Previews: docs/art/branding/launcher_previews/ (4 masks, 192/144/96/48 px, themed monochrome, home-screen mock with "빵집 기사단"). Not tested on a device or launcher.

## A5 2026-10-31 19:23 +09:00 — launcher logo now 48.0 x 51.0 dp (QUEUED)
Your check_store_graphics.py on docs/art/branding/adaptive/*: safe circle PASS (0 px outside r=132), logo 48.0 x 51.0 dp PASS, monochrome PRESENT. A red cape behind the hero widened it (same art in assets/branding/ and the 512 store icon). Still not in an APK until 02 A14.
