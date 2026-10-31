# 06-art-ui status
Updated: 2026-11-01 ~07:45 KST (after the 03:55 BSOD restart)
Status: IN PROGRESS. Last push da2d2a6 (ls-remote verified). Card-state proposal C and size candidates sent to 04; waiting on 07 (adc0965 / 02ec60f), 04 layout, 03 ink/names.
- **Crash check:** no 06 heavy run was in flight (all 06 START lines have END). The A/B mock files rewritten at 03:53/03:55 were
  intact (JSON and PNG load, no truncation) but held a 2x baseline-state bug; all three mocks were regenerated (Python only).
- **Card state criteria first:** `docs/art/ui/CARD_STATE_CRITERIA.md` (S1 whole-card |ΔL*| ≥ 15, S2 ≥ 2 signals, normal/deutan/protan).
- **Mock A/B/C (PROPOSAL MOCK on 07 ad47eda frames, not screen evidence):** only C passes everything (S1 16.9–21.8, S2 three
  signals, U1 0 pairs incl. all unaffordable, dirt 3.26, U2 +0.07 pp, U3 0, G3 0). B fails S1 (10.8–13.0); 04's screen now fails S1 (7.0–10.6).
- **Genre video:** official store / channel videos (storyboard thumbnails, accessed 07:2x KST, not stored). Unaffordable = darker card
  2/5, cooldown bar 1/5, result ribbon/stars 0/5 → none promoted to a principle.
- **Size candidates:** card 48×56 / 56×64 / 64×80, tray (pad 4 or gaps only), skill 48/56/64; all ≥ 44 px / 7 mm, stretch-safe;
  only 48×56, gaps-only tray and skill 48 stay within 07 U2. Previews `docs/art/evidence/ui_art/sizes/`.
- Atlas unchanged (clean HEAD build with the new ui.py = byte-identical ui_main). New names wait for 03/04 approval.
- Not done: human player test, real-phone check. Q2: no shop/ad art.
