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
