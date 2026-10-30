# 04-client → 09-research-product
Date: 2026-10-31 09:00 +09:00. Reply to R09-04-1..6 and the 08:45 / 09:00 follow-ups.

## X3 "보급이 부족합니다" right after start: CONFIRMED test artefact, not a game defect
It was my integration test's own `events.toast.emit("not_enough_gold")` 2 frames before the shot, as you found. Fixed in 5ba49a4: `3_hud` is now taken before any injected toast, and the injected one goes to a separate `3b_toast` frame. A new real-engine check `no 'not enough supply' toast from real play so far (toasts: [])` passes. It records every `Events.toast` from start to the first shot without player input.

## R09-04-5 base HP numbers: DONE (5ba49a4)
"hp/max" is drawn in fixed-cell Galmuri9 10 px inside each bar, at the outer end away from "VS". If the bar is too narrow it falls back to "hp". The bar height is now 14 (12 px inner). Tests: values equal the snapshot (1234.4/1500 → "1235/1500"); after a real `_damage_base(player, 100)` the drawn text is "1400/1500"; label rects stay inside their bar half and clear of VS in the worst layout; "1111" and "8888" have the same width. Visible: build/qa/real3/ko_r05_v3_3c_boss.png ("1700/1800" vs "1800/1800").
Limits: verified at 2× only; 1× was not re-captured this round. Integer-pixel regularity at 2.5× still depends on 02's integer scale (open).

## R09-04-6 star rows: DONE for shape (5ba49a4); atlas icon still pending the 02 re-import
Met rows draw a filled star; unmet rows ALWAYS draw a hollow outline star (atlas `icon_star_empty` is a filled grey star, the same shape, so it is not used). Greyscale crop: build/qa/real3/stars_greyscale_2x.png (win ✓, base ✓, time ✗) shows that filled vs hollow stays distinct. Test: `row_markers == ["filled","filled","hollow"]`. Round-select tiles use the same marker.

## R09-04-2/3/4: not changed in this round
Damage-number default is an 01 decision. Resume UI already exists: background → pause overlay with Resume/Retry, tested by notification injection only, not on a device. Speed toggle: the engine has no command yet.
