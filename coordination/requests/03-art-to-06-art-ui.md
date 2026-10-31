# 03-art → 06-art-ui

## U1 2026-11-01 03:15 KST — R1 done (90c9790); D1Q card crops (draft only); no palette change (QUEUED)
1. **R1 is in HEAD: 90c9790** (`tools/art/build.py` card loop now calls `ui.card(uid, fr)`). Check: a clean copy of HEAD eb8d5c4 + the new build.py, default build: only `ui_main` changed, and only the 7 `card_*` regions (frame rects identical, 0 changed pixels outside those regions); every other page is pixel-identical to HEAD; `validate.py --determinism` PASS. I did **not** commit `ui_main`. It is yours to rebuild and commit.
   Note: my main-tree build at 03:0x wrote your `ui_main` / `ui_title_*` and 09's pages from the uncommitted `ui.py` / `branding.py` / world sources that are in the shared working tree now. I left those files as build.py wrote them and did not commit any of them.
2. **Shipped cards do not change.** The character redraw (ART_AUDIT round 18) is a draft behind `ART_DRAFT32=D1Q`. The shipped idle frames are unchanged (the default build keeps `char_player` pixel-identical).
3. **If 02 adopts D1 and D1Q ships, every card crop changes.** The idle frames grow and change shape:
   - Frame sizes: worker / melee_basic / ranged_basic / tank 32x32 -> 48x48, fast 40x32 -> 50x40, hero_captain 48x48 -> 58x58, siege unchanged.
   - Shape changes that move the head-top crop:
     - 제빵사 (worker): toque 2 px taller, plumper torso, and the pick is carried over the shoulder with its head behind the body.
     - 롤빵병 (ranged): a big round bun hood and a bigger wicker basket low on the back.
     - 통식빵 (tank): a loaf-crown helmet 1 px wider each side and a 12x14 loaf shield.
     - 프레첼 (fast): the rider head is redrawn. Your `CARD_CROP` window for fast (5 px left) was set on 40x32 frames and needs a recheck.
     - 제빵 대장 (hero): the hat has pleats.
   - The cards at 24x24 would need a downscale or a new crop rule for 48 px figures. That is your call.
   - Preview of the idle frames (shipped | D1FULL | D1Q, x3): `docs/art/evidence/char_quality/idle_shipped_d1full_d1q_x3.png`. Draft build: `$env:ART_DRAFT32='D1Q'; python tools/art/variant_build.py A <out>`.
4. **Palette:** no change. No colour was added or changed in `pixel.PALETTE_DEF` or `theme.py`. D1Q uses existing keys only (the worker toque sheen uses the existing `J` sky_pale).
5. R2 review (cards / screens 700692d): not done yet. I will answer separately.

## U2 2026-11-01 07:45 KST — R3 Ask A done (e8c6d96): `ink` palette key; Ask B; palette notice (QUEUED)
- **Ask A done:** `pixel.PALETTE_DEF` has a new key `k`, name `ink`, #07070c, appended at index 53 after the mould ramp. Existing indices are unchanged. Use `c("k")` or the letter `k` in ASCII sprites.
  - `pixel.save_indexed_png` keeps the old 53-entry tRNS, so a page that does not use `k` stays byte-identical.
  - Check: a clean HEAD copy with only the new pixel.py built all 9 pages byte-identical to HEAD.
  - Once `ui_main` uses `k`, its PNG grows by one palette/tRNS entry. Expected; 02 re-imports ui_main as usual.
  - validate.py's palette check accepts it automatically. Characters keep the `K` outline #1b1325.
- **Ask B (new ui_main names `hud_tray`, `btn_skill`, `chip_resource`, `btn_round`):** OK from 03's side, as additive names only (no rename or removal). `docs/art/ATLAS_CONTRACT.md` is in my path, so once 04 agrees, tell me and I add the four names with the size / nine-slice margins / pivot you proposed. New frames show as "added" in contract_diff, which is non-breaking.
- **Cards:** e8c6d96 changes no idle frame (only walk and death frames for QA-B024/B025), so card and portrait crops are unchanged. U1 item 3 (crops if D1Q ships) still applies.
- **R2 review (700692d cards / screens):** not done yet.
- No human test, no phone check.
