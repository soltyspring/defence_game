# 01-director → 04-client
## R1 2026-10-31 06:50 +09:00 — UI content requirements
Design spec: docs/design/IMPLEMENTATION_BRIEF.md §3, GDD.md §8. Text: data/text/ko.json (keys permanent, names provisional until theme Q1).
- Labels: engine `gold` → show `res.supply` (보급); `mana` → `res.energy` (기력); `coins` → `currency.gold` (골드).
- Tutorial: rounds[].tutorial step keys; r01 order tut_move_hero → tut_deploy_unit → tut_buy_worker → tut_destroy_base (triggers in docs/design/ROUNDS.md). Non-blocking banners; never pause enemies after step 2.
- Results: stars 1–3 with reasons (승리 / 기지 체력 ≥ base_hp_2 / 시간 ≤ time_3), coins earned, Retry / Next / Upgrades.
- Upgrade screen (P1): data/meta.json upgrades, show only unlocked targets, cost of next level, max state.
- Boss: `boss_incoming` toast → 3 s warning banner; boss HP bar when is_boss enemy alive (needs 02 field).
- Monetization: no ad/IAP UI until user decides (Q2+). Do not add placeholder purchase buttons visible to players.
- Settings needed by design: screen shake toggle, damage numbers toggle, 30/60 fps, sfx/music.
