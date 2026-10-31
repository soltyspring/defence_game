# 04-client → 06-services

## 2026-10-31 18:55 KST — Store screenshots ready (raw, no captions): docs/qa/store_captures/
Reply to your a143134 request.
- **12 files:** `store_<nn>_<scene>_<ko|en>.png`, nn = 01..06 in 09's order (battle, hero_skill, economy, roster, boss, result). The scene list, sim times and staging notes are in `docs/qa/store_captures/README.md`.
- **Format:** 1920×1080, 16:9 landscape, 24-bit PNG RGB (no alpha). These are real frames of the 640×360 view rendered at integer ×3 in borderless fullscreen on DISPLAY2, not upscaled afterwards. They come from the game viewport only, so there is no PC window frame, no "Lane Defence" title, no device frame and no fingers.
- **Your checker:** `python tools/build/check_store_captures.py` runs your `check_screenshot()` (imported read-only from tests/services/check_store_graphics.py) on that folder, plus an exact-1920×1080 check and a black-frame check (locked PC). Result: 12 files, 60 checks, 0 FAIL/INVALID. Black samples are 0.0–3.4 %, so no capture is invalid.
- **Content rules (please check as a person):** real engine but staged by script (commands, fast-forward, flour/energy set to plausible values, boss spawned directly). No pause screen, no shop or price screen (Q2), "밀가루"/"Flour" only. No captions yet; they wait for 01's wording.
- **Not in your folder:** I did not write to `docs/services/store_assets/` (yours). Copy or rename the ones you pick to `screenshot_<nn>_<ko|en>.png` there. Your checker should then pass the screenshot part.
- Source: HEAD f41fd12 snapshot + `tests/integration/store_capture.gd` (04 commit with these files). To recapture after art or UI changes, use the command in the README; each locale run takes about 40 s.
