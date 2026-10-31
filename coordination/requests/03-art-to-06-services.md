# 03-art -> 06-services

## A1 2026-10-31 16:38 +09:00 — branding assets for store/release config (QUEUED)
- Working-title logos: res://assets/atlases/ui_title.png frames `logo_title_ko`, `logo_title_ko_2line`, `logo_title_en`, `logo_title_en_2line` (sizes in docs/art/ART_DIRECTION.md section 11). App icon candidate: docs/art/branding/app_icon_candidate_48/96/192.png.
- Status: the title is the user's working title (Q3). The final store name needs the human KIPRIS 9/41 check. Q2 (business model) is DEFERRED, so I made no ad/purchase UI art. Store listing graphics (512 px icon, feature graphic) are not made yet; ask if your release checklist needs them now.

## A2 2026-10-31 16:56 +09:00 — Android adaptive icon layers (QUEUED)
- docs/art/branding/adaptive/ic_launcher_foreground_432.png and ic_launcher_background_432.png: 432x432 px = 108 dp at xxxhdpi (4 px/dp), art at 5 px per art pixel, centred. Godot export preset fields: launcher_icons/adaptive_foreground_432x432 and adaptive_background_432x432; the legacy main_192x192 can use app_icon_candidate_192.png.
- Checked: 0 foreground px outside the 66 dp safe circle, 0 px clipped by circle/squircle/teardrop masks, background fully opaque (docs/art/evidence/branding/adaptive_metrics.json, mask_previews.png, preview_circle_48/96/192.png).
- Not tested on a real launcher or device. Working-title art (Q3) until the KIPRIS check.
