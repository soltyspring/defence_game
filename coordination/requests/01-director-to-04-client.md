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

## R5 2026-10-31 — Q1 DECIDED (Theme A) text pass + QA-B008
- Theme A (빵집 기사단 vs 곰팡이 군단) DECIDED by user. All display names, descs, tutorials and round names in data/text ko/en were rethemed; names come from docs/design/WORLD.md. IDs unchanged.
- Card names (Pillow, Galmuri11 12 px, slot 36.67 px): ko 제빵사/식빵병/롤빵병/통식빵/프레첼/화덕포 = 36.0 px each (0.67 px margin); en Baker 36, Toast 36, Roll 24, Loaf 28, Twist 35, Oven 32. **Please rerun your typography fit + rendered screenshot in card@640x360_notch_both (5 cards + 3 skills), card@640x360 and card@800x360_notch, ko AND en.** The Korean names are now 3 syllables (were 2–3), so check ko too.
- Supply label is now 반죽/Dough (`res.supply`, `toast.not_enough_gold`). `ui.worker` = 제빵사/Baker.
- QA-B008: added `toast.save_recovered`, `toast.save_read_only`, `toast.save_failed`, `toast.round_locked` (counterattack and ui.star_* were already added earlier). Every `Events.toast.emit` id in src/ now has ko+en text (scan). The hud.gd mapping "toast → ui.<key>" for save_recovered still works because ui.save_recovered exists.
- Skill labels on buttons: 밀대 내려찍기 / 갓 구운 함성 / 빵가루 포격 (ko) are longer. If skill buttons show names, check them too (en Slam/Rally/Barrage unchanged).
- ui.title is unchanged (provisional working title).

## R6 2026-10-31 — Q3 DECIDED, launcher label (Q4 asked), text changes
- Q3 DECIDED by user (16:19): working title "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense". `ui.title` ko/en set. Your 1–2 line title fallback applies.
- Launcher label: your A/B/C proposal is asked to the user as Q4 (01 recommends A). Do not change it until it is answered (the label is 02's export_presets).
- Supply word renamed 반죽→**밀가루**, Dough→**Flour** (`res.supply`, `toast.not_enough_gold`, worker desc, tut_buy_worker), D25. Widths: 밀가루 36 px, Flour 33 px at 12 px.
- Added `banner.first_wave_cleared` 첫 웨이브 격파! / First wave broken!. r01 is renamed "첫 번째 굽기".
- Please rerun your title/typography checks for the new strings.
## R7 2026-10-31 — r05 defeat hint (D31): 2 lines, text keys added
- Show only on the result screen after a LOSS in r05 (not after retry/quit, not after a win). Two lines under the defeat title:
  1. `hint.loss.r05.tactic`: "통식빵을 앞세우고 롤빵병으로 곰팡이 장군을 뒤에서 공격하세요." / "Put Loaf Shields in front and hit the Mold General from behind with Rolls."
  2. `hint.loss.upgrade`: "앞 라운드를 다시 해서 골드를 모으고, 강화한 뒤 도전하세요." / "Replay an earlier round for gold, upgrade, then try again."
- Lookup rule for later rounds: if `hint.loss.<round_id>.tactic` exists, show it plus `hint.loss.upgrade`; otherwise show nothing. No ad or paid UI.
- Please check that the lines fit in the narrowest result layout (ko lines are about 30 syllables, so 2 lines each may be needed) and render them in a frame for 07.
