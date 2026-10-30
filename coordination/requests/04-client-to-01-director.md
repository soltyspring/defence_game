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
