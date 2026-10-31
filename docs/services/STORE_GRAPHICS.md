# Google Play store graphics: requirements and current assets (owner: 06-services)
Version: 1 (2026-10-31 ~17:58 KST). **Static check only: Python and file reads, no Godot, editor or emulator** (18:00–18:30 quiet window for 08). Anything that needs a Godot export is marked **UNVERIFIED (after 18:30)**. No store listing exists and nothing was uploaded or published. Q2 deferred: no shop, price or ad images.

Machine check: `python tests/services/check_store_graphics.py`. Exit codes: 0 = all present assets pass and nothing is missing; 3 = none fail, some missing; 1 = a present asset fails. The check covers mechanical rules only. Content rules ("real gameplay", "no ranking words") need a person.

## 1. Requirements (official sources, checked 2026-10-31)
| Asset | Requirement (paraphrased) | Required? | Source |
|---|---|---|---|
| App icon (store) | 512×512, 32-bit PNG with alpha, ≤ 1024 KB; no rank/price/program badges or misleading text | **required** to publish the listing | https://support.google.com/googleplay/android-developer/answer/9866151 |
| App icon design | full square; Play applies the rounded mask (radius 30% of size) and shadow itself, so no rounded corners or drop shadow in the file; sRGB; avoid transparency (transparent parts show Play's background); illustrated art can fill the whole square | spec | https://developer.android.com/distribute/google-play/resources/icon-design-specifications |
| Feature graphic | 1024×500, JPEG or 24-bit PNG (no alpha). Keep key elements central, out of cutoff zones; avoid pure white/black/dark grey; no ranking/price words; no third-party marks or device frames | **required** to publish | answer/9866151 |
| Screenshots | at least 2 across device types; JPEG or 24-bit PNG (no alpha); each side 320–3840 px; long side ≤ 2× short side; up to 8 per device type | **required** (2) | answer/9866151 |
| Screenshots for game recommendations | at least 3 landscape 16:9 ≥ 1920×1080 (or 3 portrait 9:16 ≥ 1080×1920) showing real gameplay; taglines ≤ 20% of the image; no call-to-action or ranking words; no device frames or fingers | "highly recommended"; required to appear in large-format game recommendations | answer/9866151 |
| Tablet / Chromebook screenshots | ≥ 4, 1080–7680 px, 16:9 or 9:16 | only if we list large-screen screenshots | answer/9866151 |
| Preview video | optional; one YouTube URL, public or unlisted, ads off, not age-restricted, embeddable. Highly recommended for games; some game surfaces need it | optional | answer/9866151 |
| Launcher icon (in the app) | adaptive icon: two layers of 108×108 dp; inner 66×66 dp is never clipped by OEM masks; logo at least 48×48 dp and not over 66×66 dp; outer 18 dp per side reserved; optional monochrome layer for themed icons | needed for a good launcher icon (not a store asset) | https://developer.android.com/develop/ui/views/launch/icon_design_adaptive |
| Alt text | for each graphic and screenshot, ≤ 140 characters | recommended | answer/9866151 |
Content was rephrased for compliance with licensing restrictions.

## 2. Current assets vs requirements (Python check, 2026-10-31 17:56)
| Asset | Found | Verdict | Detail |
|---|---|---|---|
| Store icon 512×512 | none | **MISSING** | 03's candidates are 48/96/192 px. None is 512, and 512 is not a whole multiple of 48, 96 or 192 (10.67×, 5.33×, 2.67×), so plain upscaling would blur the pixel art. Candidates also have transparent corners (alpha 0; 108/432/1728 transparent px), which Play shows against its own background |
| Feature graphic 1024×500 | none | **MISSING** | — |
| Screenshots (store) | none in docs/services/store_assets/ | **MISSING** | need ≥ 2; ≥ 3 at 16:9 1920×1080 for game recommendations |
| Existing 1280×720 captures (136 RGBA, 1 RGB) | evidence only | size PASS for the store minimum; recommendation size **not met**; **136 have an alpha channel** (Play wants no alpha) | would need conversion to RGB and are below 1920×1080 |
| Existing 1600×720 emulator captures (2) | evidence only | **FAIL** | 20:9: long side 1600 > 2 × 720. Phone-shaped screenshots wider than 2:1 are rejected |
| Adaptive foreground 432×432 | yes | **PASS** size; **PASS** safe zone (0 px outside the 66 dp circle, r = 132 px) | — |
| Adaptive foreground logo size | yes | **below the guide** | logo bbox 40.0 × 42.5 dp; the guide asks for at least 48×48 dp |
| Adaptive background 432×432 | yes | **PASS** (fully opaque) | — |
| Monochrome layer | no | ABSENT (optional) | themed icons on Android 13+; Android 16 QPR2 auto-themes apps without one |
| Launcher icon actually used by the build | export_presets.cfg has no `launcher_icons/*` keys → Godot falls back to `config/icon` = res://icon.svg (16×16-grid placeholder) | **UNVERIFIED (after 18:30)** | needs 02 to set the adaptive layers and a rebuild; 06 then reads the APK |

## 3. Store image order (09 R09-06-5, SUCCESS_ANALYSIS.md §32.1) vs these rules
| # | 09 proposal | Fits the rules? | Note |
|---|---|---|---|
| 1 | real lane battle, both bases and HP | yes | first 3 should be real UI (Play recommendation) |
| 2 | hero control + first skill | yes | — |
| 3 | economy choice, caption "반죽을 모아 병력을 구워라", "반죽" value | **wording conflict** | 01 D25 renamed the resource to 밀가루; "반죽" is on 06's Bread Defense block list. Caption must use 밀가루 (asked of 09/01) |
| 4 | roster | yes | names from data/text |
| 5 | boss | yes | — |
| 6 | result stars / upgrades, no shop | yes | Q2 deferred: no price or shop screens |
Captions: ≤ 20% of the image, no call-to-action ("지금 플레이" etc.) or ranking words. Ko and en sets need separate files if captions carry text.

## 4. What is needed, and from whom (requests sent)
- **03 art:**
  - store icon 512×512 RGBA, full square, no transparent corners. Draw at 128 or 64 px and scale ×4 or ×8 for crisp pixels.
  - feature graphic 1024×500 RGB, no alpha. Logo and title in the centre, nothing important in the edges; not a copy of the icon.
  - optional: enlarge the adaptive logo to at least 48 dp (≥ 192 px at 432) while staying inside the 66 dp circle; optional monochrome layer.
- **04 client:**
  - at least 3, better 6, real-gameplay screenshots at 1920×1080, 16:9 landscape, RGB with no alpha, following §3. The game's 640×360 view at ×3 gives exactly 1920×1080.
  - capture the game render, not a phone-shaped 20:9 screen, and not the PC window frame (its title still says "Lane Defence").
  - ko and en sets if captions are added.
- **02 engine:** set `launcher_icons/adaptive_foreground_432x432`, `adaptive_background_432x432` (and `main_192x192`) to 03's files, so the APK launcher icon is not the placeholder. 06 checks the rebuilt APK after 18:30.
- **User (via 01, later, one question at a time):** a preview video means a public or unlisted YouTube upload, which is an external publication. Not now.
