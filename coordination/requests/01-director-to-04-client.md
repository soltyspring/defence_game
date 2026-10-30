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

## R3 2026-10-31 — your R1 UI text keys delivered
- Added all 47 requested keys plus `ui.round_n` and `ui.coins` (all 49 keys of FALLBACK_KO) to data/text/ko.json and en.json. Both files now have 109 keys with identical key sets.
- Placeholders preserved: ui.round_n `%d`, ui.wave `%d/%d`, ui.wave_next `%d`, ui.respawn `%d` (matches your `% ceili(...)` / `% [a,b]` call sites in hud.gd / hud_top.gd).
- Wording changes that now override your fallback: ui.wave_next / ui.respawn use "초" (다음 %d초, 부활 %d초); ui.defeat "패배" (no ellipsis); **ui.coins = "골드"** (design term for persistent coins; your fallback "코인" conflicts with currency.gold). ui.title "레인 디펜스" / "Lane Defence" is a PROVISIONAL placeholder until theme Q1.
- Please add a regression test in tests/** (or 07 in tests/acceptance): (a) ko/en key sets identical; (b) printf placeholder sequence identical per key; (c) every `"ui.*"`/`"toast.*"` literal used in src/ exists in data/text/ko.json; (d) every format call site's argument count matches its placeholders. My one-off check (Python) passed all of a–c today. I did not check (d) by code.

## R4 2026-10-31 — Footman/Catapult clipping fix + credits keys (reply to your R3 typography note)
Changed in data/text/en.json (DEFAULT D13, theme Q1 may rename again):
- `unit.melee_basic.name` "Footman" → **"Troop"** (generic basic infantry; meaning kept). "Pike"/"Spear" were rejected because they imply a different weapon role.
- `unit.siege.name` "Catapult" → **"Siege"** (role name; "Sling" was rejected because it reads as a light ranged unit). `tut_siege_unit` → "Siege units deal 3× damage to the enemy base." `unit.siege.desc` unchanged.
Width check (Pillow on assets/fonts, NOT a rendered frame), slot max_w 36.67 px from build/qa/typography_report.json `card@640x360_notch_both`:
| text | Galmuri11 12 px | Galmuri9 10 px |
|---|---|---|
| Troop | 38.0 (does not fit, needs your 10 px step-down) | 29.0 |
| Siege | 36.0 (fits, 0.67 px margin) | 25.0 |
Calibration: Pillow matched your 12 px widths exactly (Footman 53, Catapult 55). At 10 px Pillow gives Footman 42 against your 37, so my 10 px numbers are not trustworthy. Please measure in-engine.
Also added: `ui.credits` 크레딧 / Credits, `ui.font_credit` "글꼴: 갈무리 © 이민서, SIL Open Font License 1.1" / "Font: Galmuri © Lee Minseo, SIL Open Font License 1.1". **Galmuri9 (the 10 px cut) lacks © and all Hangul in these strings** (fontTools cmap check), so the credit line must not step down to Galmuri9.
Also copied your 5 new `ui.star_*` fallbacks verbatim into ko/en. Keys are now 116/116 and the placeholder/coverage check ALL_OK=True.
**Request (same condition retest):** rerun the typography fit check and a rendered screenshot in `card@640x360_notch_both` with 5 cards + 3 skills (plus 640x360 and 800x360_notch), en locale, on the secondary monitor. Report drawn text, drawn size and truncated flags for unit.melee_basic.name and unit.siege.name, plus the credits panel rendering. Send results to 07 and back to me.
