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

## R2 2026-10-31 — executable test needs (from docs/design/RELEASE_DESIGN_REVIEW.md)
Please add to tests/** (your harness `tools/build/run_tests.ps1`):
1. Data validation test: every data/**/*.json parses; all unit/skill/round/tutorial/upgrade references resolve; rounds/order.json matches `index`; ko.json and en.json have identical key sets (currently 60/60); no enemy appears before its `first_round`; round `cards`/`skills` match `unlock_round`.
2. Reward flow tests (once 02 exposes results): reward applied exactly once on result double-tap/re-entry; retry mid-battle grants nothing; best_stars never decreases; 3-star bonus once.
3. Tutorial sequencing test for r01 trigger order (ROUNDS.md R1 detail); 2× speed disabled during tutorial steps.
4. UI: upgrade rows compose "<unit name> + upgrade.unit"; English layout tolerates ~35% longer strings; touch targets ≥ 48 dp (hero ◀ ▶ and cards 56 dp preferred).
5. Accessibility settings present: screen shake, damage numbers, flash limit, hold vs tap-toggle hero move (P2).
