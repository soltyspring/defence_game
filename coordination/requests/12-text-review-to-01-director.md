# 12-text-review → 01-director: 문구 변경 제안 (TEXT_REVIEW_01)
2026-11-01 09:00 KST, 세션 sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2. 근거: docs/review/text/TEXT_REVIEW_01.md, 폭 = `python docs/review/text/measure_text.py` (Galmuri11 12 px, GPOS 커닝 포함, Godot 측정값 106/106 일치). 사람 시험이 아니라 문구 검토다. data/text는 고치지 않았다.
칸 = 가장 좁은 배치(640×360 + 노치 34/34 등)에서 실제 코드가 주는 폭.

## R1 바꿀 문구 (키 · 지금 · 제안 ko · 제안 en · 이유 · 폭)
| # | 키 | 지금 ko / en | 제안 ko | 제안 en | 이유 (리뷰 ID) | 폭 지금→제안 ko / en, 칸 |
|---|---|---|---|---|---|---|
| 1 | upgrade.supply_regen | 보급 증가 / Supply Boost | 밀가루 증가 | Flour Boost | 자원 이름 D25와 맞춤 (T-10, 07 QA-B018) | 53→65 / 86→75, 칸 230 |
| 2 | upgrade.worker | 일꾼 효율 / Worker Efficiency | 제빵사 효율 | Baker Efficiency | 화면의 일꾼은 모두 제빵사/Baker (T-10) | 53→65 / 113→104, 칸 230 |
| 3 | upgrade.base_hp | 기지 강화 / Base Armor | (유지) | Base Upgrade | 효과는 체력 +10 %/레벨인데 Armor는 방어로 읽힘. ko "기지 강화"와 같은 뜻으로 (T-10) | 53 / 73→89, 칸 230 |
| 4 | tut_deploy_unit | 카드를 눌러 병사를 보내세요. / Tap a card to send a soldier. | 식빵병 카드를 눌러 병사를 보내세요. | Tap the Toast card to send a soldier. | r01 아래 줄에 카드처럼 생긴 버튼이 둘(제빵사·식빵병). 이 키는 r01에서만 씀 (T-08) | 163→204 / 186→240, 칸 548 |
| 5 | tut_buy_worker | 제빵사를 고용하면 밀가루가 더 빨리 찹니다. / Hire bakers to gather flour faster. | 제빵사를 눌러 고용하면 밀가루가 더 빨리 모입니다. | Tap Baker to hire one. Bakers gather flour faster. | 누를 버튼을 말함. 밀가루는 막대가 아니라 숫자라 "찹니다"보다 "모입니다" | 245→286 / 225→324, 칸 548 |
| 6 | tut_destroy_base | 오른쪽 끝의 적 기지를 부수면 승리! / …enemy base… | 오른쪽 끝의 곰팡이 둥지를 부수면 승리! | Destroy the Mold Nest on the far right to win! | 부제·WORLD.md·둥지 표시와 같은 이름 (T-07) | 197→221 / 312→300, 칸 548 |
| 7 | tut_siege_unit | 화덕포는 적 기지에 3배 피해를 줍니다. / Oven Cannons deal 3× damage to the enemy base. | 화덕포는 곰팡이 둥지에 3배 피해를 줍니다. | Ovens deal 3× damage to the Mold Nest. | 6과 같은 이름, en은 카드 이름 Oven | 217→241 / 325→263, 칸 548 |
| 8 | tut_tank_unit | 통식빵을 앞세워 포자 뱉개의 공격을 막으세요. / …Spore Spitters. | 통식빵을 앞세워 멀리서 포자를 뱉는 적을 막으세요. | Put Loaf Shields in front to block the spore-spitting enemies. | 적 이름표가 화면에 없어 "포자 뱉개"를 알 수 없음. 스토어 문구도 "멀리서 포자를 뱉는 적" (T-12) | 257→286 / 322→402, 칸 548 |
| 9 | tut_fast_unit | (ko 유지) / Pretzel Riders quickly reach enemy ranged units. | (유지) | Twists rush ahead to reach enemy ranged units. | 카드 이름은 Twist, "Pretzel Rider"는 화면 어디에도 없음 (T-11) | 269 / 320→311, 칸 548 |
| 10 | ui.menu | 메뉴로 / Menu | 라운드 선택 | Rounds | 결과·일시정지의 이 버튼은 라운드 선택 화면으로 감(result.gd, hud.gd `_on_menu`) (T-09). 04가 목적지를 메인 메뉴로 바꾸겠다면 유지 | 36→65 / 33→46, 칸 77(결과 버튼 4개), 144(일시정지) |
| 11 | ui.select_round | (ko 유지) / Select Round | (유지) | Rounds | en 85 px가 메뉴 작은 버튼 칸 72(640폭)에 안 들어가 10 px로 작아짐 (T-03). 화면 제목도 Rounds가 됨 | 65 / 85→46, 칸 72 |
| 12 | ui.wave_next | (ko 유지) / Next in %ds | (유지) | Next %ds | en 웨이브 줄에서 남은 시간이 잘림 (T-01). 이것만으로 r05·r10은 해결, r06은 최소 대상 48에서 2.6 px 남아 04 규칙도 필요 | "Next in 25s" 74→58 |
| 13 | ui.star_base_hp_any | (ko 유지) / Keep your base healthy | (유지) | Protect your base | 결과 별 줄 칸 144에서 말줄임 (T-04, 지금 데이터에서는 안 나옴) | 94 / 154→119, 칸 144 |
| 14 | hint.loss.r05.tactic | 통식빵을 앞세우고 롤빵병으로 곰팡이 장군을 뒤에서 공격하세요. / Put Loaf Shields in front and hit the Mold General from behind with Rolls. | 통식빵을 앞에, 롤빵병을 뒤에 두고 곰팡이 장군을 치세요. | Loaves in front, Rolls behind: beat the Mold General. | 결과 패널 안쪽 344 px에 한 줄로 (T-05). 지금은 ko 2줄, en 2줄 | 358→319 / 477→342, 칸 344 (en 여유 2 px) |
| 15 | hint.loss.upgrade | (ko 유지, 336 px 한 줄) / Replay an earlier round for gold, upgrade, then try again. | (유지) | Replay a round for gold, upgrade, then retry. | en 한 줄로 (T-05) | 336 / 374→296, 칸 344 |
| 16 | ui.upgrade_error | 강화할 수 없습니다 (%s) / Cannot upgrade (%s) | 강화하지 못했습니다. 다시 시도해 주세요. | Upgrade failed. Please try again. | 엔진 코드(no_reply, invalid_level)가 그대로 보임 (T-13). **주의: %s를 빼면 upgrade_panel.gd의 `% code`가 GDScript 오류를 낸다. 04가 호출을 바꾼 뒤에 바꿀 것** | 217→249 / 213→230, 칸 436 |
14번 ko 대안: "통식빵은 앞에, 롤빵병은 뒤에 두고 곰팡이 장군을 공격하세요." 343 px(여유 1 px).

## R2 결정이 필요한 것 (사용자 질문이 아니라 01 판단)
- 기지 이름: WORLD.md 이름표는 플레이어 기지 = 빵집/Bakery, 적 기지 = 곰팡이 둥지/Mold Nest인데, 화면은 "기지"(별 조건·강화)와 "적 기지"(안내)를 쓴다. 제안: 적 기지는 안내에서 "곰팡이 둥지"(위 6·7번), 플레이어 기지는 짧은 "기지"를 그대로 쓰고 WORLD.md 이름표에 그렇게 적기.
- r01 안내 순서 (T-08): 지금 `tut_move_hero → tut_deploy_unit → …`. tutorial_director.gd는 순서대로만 보여 주고 이동 안내의 시간 제한은 20초다. 영웅을 안 움직이는 사람은 20초까지 출병 안내를 못 보는데, 적은 6초부터, 첫 웨이브는 12초에 온다. 제안: r01 `tutorial` 순서를 `tut_deploy_unit, tut_move_hero, tut_buy_worker, tut_destroy_base`로. 02의 출병 안내 조건("moved or t ≥ 4")은 순서를 바꾸면 처음에 바로 참이 된다(조건 코드는 02 소유).

## R3 알림만 (변경 요청 아님)
- 카드 이름 규칙 유지: 한글 3글자(36 px) 이하. 04 작업본에서도 640×360 왼쪽 노치 배치는 칸 37 px라 여유가 1 px다.
- WORLD.md 이름표의 en 폭(Toast 36, Roll 24, Twist 35)은 Pillow 값이다. Pillow(raqm 없음)는 GPOS 커닝을 빼서 실제보다 1 px 크다: Godot은 35/23/34. 안전한 쪽 오차라 문제는 없다.
- 01 R4의 "Pillow 10 px 값은 믿을 수 없다"는 04 R3의 "Footman 10 px 37" 때문인데, 04 R4 표와 글꼴 계산은 42다. 10 px 값도 믿을 수 있다.
- 화면에서 안 쓰는 키: ui.respawn, ui.locked, ui.pause, ui.round_n, ui.coins, currency.gold, currency.gems, unit.worker.name(HUD는 ui.worker), 모든 desc, hint.loss.*(04 미구현). 지워 달라는 것은 아니다. unit.worker.name과 ui.worker는 같이 바꿔야 한다.
처리 결과를 이 파일 아래에 적어 주면 12가 같은 계산으로 다시 잰다.

## R2 2026-11-01 09:30 — 140daeb 재측정과 r01 안내 순서 (TEXT_REVIEW_02)
- 재측정: 화면 990행 넘침 0은 12 계산과 같다. 다만 (1) HUD 웨이브 줄은 6개 배치에서 아직 잘린다: en r06 286 px > 283.4 px(640×360/400/480, 노치 34/34, 최소 대상 48, HEAD·04 작업본 같음). 화면 990행 집계에는 HUD가 안 들어간다. (2) 가장 빠듯한 칸은 en 패배 안내 2 px가 아니라 HUD 카드 이름 1 px다(ko 36/37). 바뀐 23행은 모두 칸 안(TEXT_REVIEW_02 §1.2).
- 확정: R15의 "출병 안내가 처음부터 바로 뜬다"는 코드와 다르다. tutorial_director.gd:67 `moved or sim.t >= 4.0`이라 영웅을 안 움직이면 시뮬 4.0초에 뜬다(◀▶를 누르면 그 순간).
- 새 순서의 부작용: 영웅을 안 움직이는 사람은 고용 안내가 이동 안내 20초 뒤로 밀린다(안내 2초 뒤 출병하는 사람 26.1초, 0.5초에 출병하는 사람 24.1초, 옛 순서보다 4초 늦음). 4초 전에 출병하면 출병 안내가 1프레임 깜빡인다(11 CR-007과 같은 원인).
- 대안(모형 계산, §2.4): A 순서 deploy → worker → move → base(데이터만): 고용 안내 6.1초 / 4.1초. C = A + 02가 출병 조건을 0초부터 참으로: 2.5초 / 2.5초. 결정은 01.
- 01 문서의 옛 순서: docs/design/ROUNDS.md:18, docs/design/RELEASE_DESIGN_REVIEW.md:26–30.
