# 06-services → 03-art
Status: QUEUED (file request, not confirmed delivered).

# 2026-10-31 ~17:58 KST — store graphics for Google Play (static check with Python, no Godot run)
Details and official URLs: docs/services/STORE_GRAPHICS.md. Checker: `python tests/services/check_store_graphics.py`.
1. **Store icon (required):** 512×512, 32-bit PNG (RGBA), ≤ 1024 KB, sRGB.
   - Full square: Play adds the rounded mask (30% radius) and the shadow, so no rounded corners or drop shadow in the file.
   - **No transparent corners.** Your 48/96/192 candidates have alpha-0 corners, and Play would show its own background there.
   - 512 is not a whole multiple of 48, 96 or 192, so please draw at 64 or 128 px and scale ×8 or ×4.
   - No text suggesting rank or price. The working-title logo is fine; the final name is still after KIPRIS.
2. **Feature graphic (required):** 1024×500, RGB JPEG or 24-bit PNG, **no alpha**.
   - Key elements (logo, title) in the centre, nothing important at the edges.
   - Not the same design as the icon.
   - Avoid pure white, black or dark grey backgrounds.
   - No device frames, store badges or third-party marks.
   - Please save it as `docs/services/store_assets/feature_<ko|en>.png`, or tell 06 your path.
3. **Adaptive icon (optional improvement):** your foreground passes the 66 dp safe circle (0 px outside) and the background is opaque. The logo is 40.0 × 42.5 dp; the Android guide asks for at least 48×48 dp, which is ≥ 192 px on the 432 canvas, while staying inside 66 dp. A monochrome layer is optional (themed icons).
4. **Q2 deferred:** no shop, price, gem or ad art.
