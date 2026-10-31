# Camera, base resolution and lane length — options for QA-J1 / 03 A12 (owner: 02-engine; PROPOSAL, nothing changed)
Date: 2026-10-31. Inputs: 07 QA-J1 (enemies on screen 0 times in r01 t=7–32 s; lane ≈16 % of screen height; sprites 5–7 %), 03 A12/A13 (art is opaque from y 50 to the lane; enemy nest left edge x 1012 enters a 640 px view only at cam_x ≥ 692), 02 wave probe (r01 first contact 42 s, wave 1 broken 56.65 s).
All numbers are logical px of the 640×360 base view unless stated. They come from the current code/data, not from a phone.

## Current behaviour (facts)
- View 640×360 at 2× on 1280×720 (integer scale, 141d226); 800×450 on 1600×900.
- Camera: x follows hero + 60 px, clamped to [−90 + w/2, L + 50 − w/2]; y bottom-anchored (ground at the same screen row).
- r01: lane 1600, player base x 40, enemy base x 1560, enemies spawn at x ≈ 1538 at 38 px/s, footmen 40 px/s, hero 70 px/s with leash 0.85 (max x 1360).
- At t = 0 the view shows x −90…550. Wave 1 spawns at 25 s at x ≈ 1538 and reaches x 550 only at ≈ 51 s if unopposed. So with an idle hero no enemy is visible for the first ~45 s. That matches 07 (0 frames t = 7–32 s).
- Vertical: ground_y 290; character frames 32 px (hero 48) ⇒ 32/360 = 8.9 % (hero 13 %), bodies ≈ 24 px = 6.7 % (07's 5–7 %). HUD uses ~44 px top + ~60 px bottom; the lane row (ground ±6) is in the 245–300 band.

## Options
| # | Change | Effect (numbers) | Cost / risk | Owner |
|---|---|---|---|---|
| A | **Combat-aware camera**: target = midpoint of hero and the nearest "interest" point ahead (frontmost ally, nearest enemy, or enemy base when < 640 px away), keeping the hero ≥ 64 px inside the left edge | When hero and enemy are < 512 px apart both are on screen. r01 contact at x ≈ 870 is visible with the hero anywhere in 358–870. Wave 1 at spawn (x 1538) still needs hero x ≥ 1026 | Camera moves on its own, so hold-to-move feels less direct; needs 0.5–1 s smoothing and a manual drag override (already 2 s) | 02 |
| B | **Edge indicator** for off-screen enemies/nest (04 A11) | No camera change; the player sees the direction and distance of the threat at all times | UI only; does not make fights visible | 04 |
| C | **Shorter r01 lane** (data) e.g. 1600 → 1100 | Spawn x ≈ 1038. Unopposed grunts reach x 550 at 25 + 12.8 = 38 s; contact with footmen ≈ 33–35 s; wave-1 break would fall inside D16's 25–45 s (estimate from 38+40 px/s closing speed, to be measured) | Changes r01 pacing and the star time; 01 data | 01 |
| D | **First wave earlier** (data) e.g. at = 12 s | Contact ≈ 29 s, break ≈ 44 s (same speeds) | Less build-up time in the tutorial | 01 |
| E | **Smaller base view** 480×270 (×1.333 bigger sprites) | Bodies 24/270 = 8.9 %; visible lane width −25 % (640 → 480) | 04 layout matrix, 03 art scale, HUD density, integer scale on 1280×720 becomes 2.67× (non-integer) unless 1440×810/1920×1080 → breaks the integer-scale fix; NOT recommended | 02+04+03 |
| F | **Camera zoom 0.5** (show 1280 px of lane) | Whole r01 middle visible | Sprites at 1 device px per art px on 2× phones (12–16 device px bodies), unreadable; NOT recommended | 02 |
| G | **Lower the lane on screen / higher camera** (ground row lower, more ground, less sky) | 03: art is opaque from y 50, so no empty sky. Moving the lane down is limited by the bottom HUD (~60 px), so it gains ≤ 10–15 px | Small effect | 02+04 |

## Recommendation (for 01/04/07 to decide)
1. C or D (01, data only) to bring the first fight into 25–45 s. These are the only options here that also fix the D16 window.
2. A (02) as the camera fix, with tuning constants in game_config.json so 01 can adjust them, plus B (04) for threats that stay out of view.
3. Do not do E or F: they undo the integer pixel scale or make sprites unreadable.
Acceptance proposal for 07: r01 with an idle hero, at least one enemy on screen within 5 s of its first contact with an ally, and the nest visible whenever the hero is within 640 px of it. Sprite height % stays as is (needs E, rejected).
