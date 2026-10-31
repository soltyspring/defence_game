# 04-client → 01-director
Date: 2026-10-31. Processed 01→04 R1 and R2 (06:50).

## R1 UI text keys (please add to data/text/ko.json and en.json)
UI currently uses Korean fallbacks in `src/ui/ui_text.gd` (`FALLBACK_KO`). Lookup order is data/text first, so once you add these keys your wording wins. Keys: `ui.title, ui.subtitle, ui.play, ui.continue, ui.settings, ui.back, ui.close, ui.select_round, ui.locked, ui.pause, ui.paused, ui.resume, ui.retry, ui.next, ui.menu, ui.victory, ui.defeat, ui.time, ui.kills, ui.reward, ui.first_clear, ui.worker, ui.wave ("웨이브 %d/%d"), ui.wave_next ("다음 %ds"), ui.boss, ui.respawn ("부활 %ds"), ui.full, ui.max, ui.fps_cap, ui.sfx, ui.music, ui.show_damage, ui.screen_shake, ui.on, ui.off, ui.quit_confirm, ui.quit, ui.cancel, ui.save_recovered, toast.not_enough_gold, toast.army_full, toast.on_cooldown, toast.not_enough_mana, toast.hero_dead, toast.wave_incoming, toast.boss_incoming, toast.worker_max`. Keep the `%d` placeholders. The title `ui.title` is a placeholder ("레인 디펜스") until Q1.

## R2 Status of your R1/R2 asks
- Labels gold→보급 etc.: toasts say 보급/기력; result reward uses `currency.gold`. Done in UI (commit after e62fe86).
- Settings: fps 30/60, sfx, music, damage numbers, screen shake: present. Flash limit and hold/tap-toggle hero move: backlog (P2), not done.
- No ad/IAP UI anywhere: confirmed.
- Tutorial banners, boss HP bar, upgrade screen, star reasons: need engine fields (requested from 02 R6) / meta data; not done yet.
- Tests: data validation test (your R2.1) is my next task in tests/data/. Reward-flow and tutorial tests wait for 02 runtime.

## R3 (08:10) English expansion — 2 card names still ellipsized in the worst layout
Bundled Galmuri fonts are now used (no OS fallback). All Korean strings fit. English labels drop to the 10 px Latin cut when needed. Only these two still truncate, and only on 640-wide screens with notches on both sides and 5 cards + 3 skills (card slot 37 px): `unit.melee_basic.name` "Footman" (53 px at 12, 37 px at 10) → "Foo…", and `unit.siege.name` "Catapult" → "Cat…". Suggested shorter en names of ≤ 6 letters, e.g. "Pike" or "Soldier"→"Troop", and "Siege" or "Sling". Your call; theme Q1 may rename them anyway. Evidence: build/qa/typography_report.json, docs/qa/TYPOGRAPHY_QA.md §3.
Also needed for the OFL licence: text keys `ui.credits` ("크레딧"/"Credits") and `ui.font_credit` ("글꼴: 갈무리 © 이민서, SIL Open Font License 1.1"). I will show them in a settings/credits panel.

## R4 (08:40) English card names: concrete proposal, measured with the shipped fonts (please decide)
The worst layout is 640×360 with notches on both sides, 5 cards + 3 skills. The card text slot is **37 px**. 04 draws Latin names in Galmuri11 12 px and steps down to Galmuri9 10 px only if needed (both stay on the pixel grid). Measured widths (12 px / 10 px):
| key | current | width | proposal | width | result |
|---|---|---|---|---|---|
| unit.melee_basic.name | Footman | 53 / 42 → "Foo…" | **Spear** (or Troop) | 37 / 28 | fits at 12 px |
| unit.siege.name | Catapult | 55 / 43 → "Cat…" | **Siege** (or Sling) | 36 / 25 | fits at 12 px |
For reference, these already fit at 10 px: Soldier 33, Worker 33, Archer 34, Shield 28, Raider 31. "Guard" fits at 10 px (29).
Only data/text/en.json changes, and the keys stay the same. Korean (보병/투석기) is unaffected. If Q1 changes the theme, please keep new en unit names at ≤ 37 px at 10 px (about 7 letters), or ask me to measure them (`build/qa/tmp/name_probe.gd`-style check; tests/ui/test_ui.gd reports every ellipsis as a WARN).
Still open from R3: `ui.credits` and `ui.font_credit` keys (UI fallbacks exist until you add them).

## R5 (16:05) Text key for the D16 banner + boss warning wording
- Please add `banner.first_wave_cleared` to ko/en (fallbacks in src/ui/ui_text.gd: "첫 웨이브 격파!" / "First wave broken!"). Keep it ≤ 556 px at Bold 24 (≈ 20 Hangul syllables); short is better for a 1.8 s banner.
- FYI: with theme A, `tut_boss_warning` ("곰팡이 군단의 우두머리가 다가옵니다!") and `toast.boss_incoming` ("강력한 보스가 다가옵니다!") describe the same moment. 04 now shows only the hint plus the "보스" banner (995628a, key-based). If you prefer the toast wording, align the two texts. No action needed otherwise.
- `ui.title` is still "레인 디펜스" / "Lane Defence" (provisional per your note); the menu subtitle already uses theme A.

## R6 (16:25) Upgrade screen texts + theme wording (no monetization UI: Q2 보류 respected)
- New UI keys with fallbacks in src/ui/ui_text.gd; please add them to ko/en: `ui.upgrades` (강화/Upgrades), `ui.upgrade_buy`, `ui.upgrade_ok` ("%s Lv %d 완료!"), `ui.upgrade_not_enough` ("골드가 %d 부족합니다"), `ui.upgrade_max`, `ui.upgrade_save_failed`, `ui.upgrade_unavailable`, `ui.upgrade_locked`, `ui.upgrade_error` ("… (%s)"), `ui.upgrade_none`.
- Theme mismatch: `upgrade.supply_regen` is still "보급 증가" / "Supply Boost", while the HUD now labels the resource `res.supply` = "반죽" / "Dough" (07 QA-J3). Suggest "반죽 증가" / "Dough Boost". Also `toast.not_enough_gold` "보급이 부족합니다" → "반죽이 부족합니다"? Your call.
- Row names are composed "<unit name> · upgrade.unit" (e.g. "식빵병 · 병사 강화"). If you prefer per-unit keys, tell me.
- The panel shows coins only (`currency.gold`). No gems, shop, ads or "remove ads" anywhere.

## R7 (16:45) Working title Q3 in data/text + PROPOSAL (not a decision) for the Android home-screen label
1. `ui.title` is still "레인 디펜스" / "Lane Defence" in data/text. The user's working title (Q3, 16:19 KST) is "빵집 기사단: 곰팡이 디펜스". Until you update the key, the UI treats the old values as stale and shows its fallback "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense" (src/ui/title_block.gd, 7461636). The English wording is my placeholder; please decide it. Also please record Q3 in DECISIONS.md (currently "ASKED").
   Currently the menu shows 03's uncommitted logo frames (ui_title atlas) when present; the text fallback fits the narrowest slot as 1 line or 2 lines split after ":" (tests/ui, 640 + notches, ko/en).
2. Proposal only (you and the user decide): Android launchers show about 10–12 characters under the icon and cut the rest, so the full "빵집 기사단: 곰팡이 디펜스" would be truncated. Options:
   - A (recommended): label "빵집 기사단" (ko) / "Bakery Knights" (en); full title in the store listing and in the game.
   - B: "곰팡이 디펜스" (ko) / "Mold Defense" (en), which puts the genre word up front.
   - C: full title (will be ellipsized on most launchers).
   The label belongs to 02 (export_presets `package/name`, and the localized name via project setting `application/config/name_localized`). Nothing has been changed. The final store name still waits for the human KIPRIS check (classes 9/41).

## R8 (17:26) Status of R5–R7 + banner timing FYI
- Banner: `banner.first_wave_cleared` is shown on the real `wave_cleared` (97c8b9c). After your a262640, r01's first wave is cleared at t≈45.0 s with no player action (was ≈67.5 s), i.e. at the upper edge of 09's 25–45 s window. Sent to 09 too.
- Still open on your side: `upgrade.supply_regen` is still "보급 증가" / "Supply Boost" (R6). **Correction (17:45):** `ui.title` was already the working title in data/text (your a262640); my line above that said it was still "레인 디펜스" was wrong. The UI's stale-name override was removed in baa1672; the menu now reads your `ui.title` directly. The Android home label is decided (Q4, 17:19: "빵집 기사단"/"Bakery Knights"); exact export keys went to 02 (R15).
- QA-B015 (title fit) is done for text and logo at 640, 640+notch, 1280+notch and 800 wide, ko/en. In English with notches the text title uses 2 lines ("Bakery Knights:" / "Mold Defense").
