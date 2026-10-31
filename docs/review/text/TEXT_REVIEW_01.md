# TEXT_REVIEW_01 — 문구·용어·잘림·첫 3분 안내 (12-text-review)
작성: 2026-11-01 08:30–09:00 KST, 세션 sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2. 기준: git HEAD 85d22bd + 04의 커밋 안 된 hud_layout.gd 작업본(배치안 B).
**이 문서는 문구 검토다. 사람 시험도, 렌더 화면 확인도 아니다.** Godot·편집기·에뮬레이터는 한 번도 실행하지 않았다. 폭은 글꼴 파일로 계산했다.

## 0. 방법과 계산 검증
- 도구: `python docs/review/text/measure_text.py` (fontTools). 글자 폭 = hmtx 전진폭 + GPOS `kern` 짝 보정, 글자마다 정수 px 반올림(Godot 글꼴 설정 subpixel 끔과 같음). Galmuri9는 없는 글자를 Galmuri11로 넘긴다(ui_style.gd `fallbacks`).
- 칸 폭: src/ui/hud_layout.gd(HEAD판과 작업본 둘 다), touch_button.gd(`size.x - 6`), ui_screen.gd `place()`의 크기 반올림, main_menu/round_select/result/settings_panel/upgrade_panel/notice_dialog/hud_top의 식을 파이썬으로 옮겼다. 배치 행렬은 tests/ui/test_ui.gd와 같다(화면 10종 × 인셋 5종 × 최소 대상 40/44/48 × 라운드 10개).
- 검증: Godot이 잰 폭 106개(build/qa/typography_report.json 2026-10-31 17:28, 04 R4 이름 측정, 07 QA-B009)와 **106/106 같다**. 커닝을 빼면 94/106만 같다. 그래서 Pillow `getlength`(raqm 없음, GPOS 커닝 무시)는 라틴 글자에서 1 px 크게 나올 수 있다(Toast 36 대 실제 35, Twist 35 대 34, Roll 24 대 23).
- 어긋난 옛 값 하나: 04 R3(10-31 08:10)의 "Footman 10 px 37"과 이를 옮긴 01 R4. 04가 30분 뒤 R4 표에 적은 42가 글꼴 계산(5+6+6+5+8+6+6)과 맞는다. 01의 "Pillow 10 px 값은 믿을 수 없다"는 이 잘못된 37 때문으로 보인다.
- 결과 파일: docs/review/text/evidence/text_width_report.json, measure_text_stdout.txt.

## 1. 08:01 게이트 실패 재현 (먼저 확인)
조건: 640×360, 노치 34/34(safe x 34–606), 카드 5·스킬 3, 최소 대상 40.
| 배치 | 카드 폭(계산) | 실제 버튼 폭(place 반올림) | 이름 칸(−6) | ko 카드 이름 6개 | 결과 |
|---|---|---|---|---|---|
| HEAD 85d22bd | 42.67 | 43 | 37 | 모두 36 px | 맞음, 여유 1 px |
| B 첫 구현(스킬만 줄이고 카드를 줄임, UI_LAYOUT_REFERENCE §5 서술로 재구성) | 41.33 | 41 | 35 (시험은 35.33) | 모두 36 px | **6개 모두 1 px 넘침** |
| B 지금 작업본(이동 버튼도 40으로 줄임) | 45.33 | 45 | 39 | 모두 36 px | 맞음, 여유 3 px |
- 게이트 메시지 `w=36 max=35`와 같은 값이다. 화덕포만의 문제가 아니라 3글자 한글 이름 6개(제빵사·식빵병·롤빵병·통식빵·프레첼·화덕포)가 같은 36 px이라 함께 넘쳤다. en "Baker"(36)도 넘지만 Galmuri9 10 px(28)로 내려가 잘리지는 않는다.
- 남은 여유: 작업본에서도 640×360 왼쪽 노치만 있는 배치는 카드 43 → 칸 37, 한글 이름 여유 **1 px**. 카드 이름은 계속 한글 3글자(36 px) 이하여야 한다.
- 영문 Footman·Catapult: data/text에는 더 없다(D13 Troop/Siege → 테마 A Toast/Oven). 지금 en 카드 이름 폭은 Toast 35, Roll 23, Loaf 28, Twist 34, Oven 32, Baker 36으로 가장 좁은 칸 37에 모두 12 px로 들어간다. 남은 곳은 02의 대체 콘텐츠 src/core/default_content.gd(`Catapult` 55/43 px, `Shieldbearer` 82/62, `Spearman` 61/48: 37 px 칸에서 말줄임, 한국어 기기에서도 영어)와 04 미리보기 mock_engine.gd뿐이다. 대체 콘텐츠는 data/**를 못 읽을 때만 나온다(T-14).

## 2. 용어 일관성표
판정: ✓ 같음, △ 이해는 되지만 다름, ✗ 다름.
| 개념 (ID) | ko 화면 | en 화면 | WORLD.md 이름표 | 코드 주석·04 대체 문구·문서 | 판정 |
|---|---|---|---|---|---|
| 일꾼 (worker) | 카드 `ui.worker` 제빵사, `toast.worker_max` 제빵사가 최대입니다, `tut_buy_worker` 제빵사 | Baker, Bakers at maximum | 제빵사 / Baker | **`upgrade.worker` 일꾼 효율 / Worker Efficiency**; ui_text.gd 대체 문구 `ui.worker` 일꾼, `toast.worker_max` 일꾼이 최대입니다 | ✗ (강화 이름, 대체 문구) |
| 인게임 자원 (supply) | `res.supply` 밀가루, `toast.not_enough_gold` 밀가루가 부족합니다 | Flour, Not enough flour | 밀가루 / Flour (D25) | **`upgrade.supply_regen` 보급 증가 / Supply Boost** (QA-B018 열림); 대체 문구 보급이 부족합니다; hud_top.gd 주석 "반죽/Dough"; 스토어 그림 문구 "반죽을 모아…" | ✗ |
| 영웅 자원 (energy) | 기력 (`res.energy`, 부족 알림, 강화, 스킬 안내) | Energy | 기력 / Energy | 같음 | ✓ (단 r01에는 쓸 곳이 없다, §4) |
| 메타 화폐 (coins) | 골드 (`ui.upgrade_not_enough`, `hint.loss.upgrade`, 알림) | Gold | 골드 / Gold | `ui.coins`·`currency.gold`는 어디에서도 안 씀; 대체 문구 `ui.coins` 코인; 메뉴·강화 화면은 동전 그림+숫자만 | △ (이름이 처음 나오는 곳이 부족 알림) |
| 영웅 (hero_captain) | 안내·알림·강화는 "영웅", 강화 줄은 "제빵 대장 · 영웅 강화" | hero / Head Baker | 제빵 대장 / Head Baker (역할 영웅) | — | △ (전투 중 이름은 안 보임) |
| 유닛 5종 | 식빵병·롤빵병·통식빵·프레첼·화덕포. 안내 문구도 같은 말 | Toast·Roll·Loaf·Twist·Oven. 안내 문구는 Rolls ✓, Loaf Shields △, Oven Cannons △, **Pretzel Riders ✗**(카드는 Twist) | 같음 | data/units/units.json `name` = ko 이름 ✓ | en `tut_fast_unit`만 ✗ |
| 적 이름 | 보스 2개만 보스 막대에 보임. `tut_tank_unit` 포자 뱉개, `tut_bomber_warning` 부푼 효모 | Spore Spitters, Yeast Puffs | 같음 | 화면에 적 이름표 없음 | △ (안내가 본 적 없는 이름을 씀) |
| 스킬 3종 | 밀대 내려찍기·갓 구운 함성·빵가루 포격 (누르고 있을 때만 이름 표시) | Slam·Rally·Barrage | 같음 | 스토어 ko 본문은 "세 가지 **기술**" | 화면 ✓, 스토어 ✗ |
| 플레이어 기지 | 기지 (`ui.star_base_hp` 기지 체력, `upgrade.base_hp` 기지 강화) | Base HP, **Base Armor** | 빵집 / Bakery | — | △ (WORLD 이름표와 다름); en ✗ (효과는 체력 +10 %/레벨, 방어 아님) |
| 적 기지 | `tut_destroy_base`·`tut_siege_unit` 적 기지, `ui.subtitle` 곰팡이 둥지 | enemy base / mold nest | 곰팡이 둥지 / Mold Nest | 위협 표시 그림은 둥지(icon_nest) | △ (한 대상에 두 이름) |
| 라운드·웨이브 | 라운드, 웨이브, 다음 라운드 | Round, Wave | — | `ui.menu` 메뉴로/Menu 는 **라운드 선택 화면**으로 감(result.gd, hud.gd) | `ui.menu` ✗ |
| 제목·홈 이름 | `ui.title` Q3, 홈 이름 Q4 (project.godot name_localized) | 같음 | 같음 | config/name "Lane Defence"는 데스크톱 폴더용으로 남김(app.gd 주석). 창 제목은 app.gd가 ui.title로 바꿈 | ✓ |
| 진영 | 빵집 기사단 / 곰팡이 군단 | Bakery Knights / Mold Legion | 같음 | en 철자 Mold 통일(KIPRIS의 Mould는 일부러 넣은 검색어) | ✓ |
- data 안 이름 필드(units.json, heroes, skills, rounds의 `name`)는 ko 문구와 30/30 같다.
- ko/en 키 집합 같음, 자리표시자(%d, %s, {levels}) 짝 모두 같음.
- 글자 범위: ko 341자, en 239자(대체 문구 포함). Galmuri11·Bold에 빠진 글자 0. 상태 표시 기호 ● ▲ × ※, ★ ☆ … © · ◀ ▶ 모두 있음.

## 3. 잘림·넘침 표 (칸보다 넓은 문구만)
| ID | 키 (조합) | 위치 | 언어 | 폭 px | 칸 px | 결과 | 어느 배치 | 담당 |
|---|---|---|---|---|---|---|---|---|
| T-01 | 라운드 이름 + `ui.wave` + `ui.wave_next` ("6. Break the Mold Wall   Wave 0/4  Next in 25s") | HUD 위 웨이브 줄 (hud_top, 칸 = 막대 폭 − 70) | en r06 | 302 | 291.4 / 287.4 / 283.4 (최소 대상 40/44/48) | "…Next i…": **남은 시간이 잘린다** | 640×360 + 노치 34/34 (HEAD·작업본 같음) | 04 (+01) |
| T-01 | 같음, r10 "10. The Rot Overlord …" | 〃 | en | 293 | 〃 | 세 경우 모두 잘림 | 〃 | 04 (+01) |
| T-01 | 같음, r05 "5. The Mold General …" | 〃 | en | 288 | 〃 | 44·48에서 잘림 | 〃 | 04 (+01) |
| — | 같은 줄 ko 최장 r06 | 〃 | ko | 280 | 283.4 | 맞음(여유 3.4) | 〃 | — |
| T-02 | `+x/s` 수입 숫자 (hud_top `show_income`) | 왼쪽 위 자원 칸 | ko·en | ko 139, en 147 필요 | 640폭 노치 없음 138.3, 노치 한쪽 129.5, 양쪽 120.6 | **수입 숫자를 아예 안 그림.** ko는 노치 없는 640×360에서 0.68 px 모자람 | ko: 640×360/400/480, 666×400, 683×384 모든 인셋·대상. en: 여기에 720×360 노치 포함 | 04 |
| T-03 | `ui.select_round` "Select Round" | 메인 메뉴 작은 버튼 3개 | en | 85 | 72 (작업본) / 74 (HEAD), 노치 없는 640도 82 | Galmuri9 10 px로 내려감: 옆 "Upgrades"·"Settings"는 12 px | 640폭 화면 | 01 (또는 04) |
| T-04 | `ui.star_base_hp_any` "Keep your base healthy" | 결과 별 조건 줄 | en | 154 | 144 | "Keep your base hea…" | 640 + 노치 34/34. 지금 데이터는 모든 라운드에 base_hp_2가 있어 이 문구가 안 나옴 | 01 |
| T-05 | `hint.loss.r05.tactic` / `hint.loss.upgrade` (D31, 04가 아직 안 그림) | 결과 패널 안쪽 폭 344 | ko 358 / 336, en 477 / 374 | | 344 | ko 2+1줄, en 2+2줄. 09 계산의 빈 공간 ≈ 86 px(22 px 줄 4개 = 88)에 en이 안 들어갈 수 있다 | 모든 화면(패널 폭 380 고정) | 01 문구, 04 배치 |
| — | 카드 이름 6종·제빵사 | 카드 | ko | 36 | 37 이상 | 맞음, 최소 여유 1 px | §1 | 규칙만 |
| — | 라운드 칸 이름 | 2줄 칸 | ko·en | | 78–83 | 모두 2줄 안에 들어감(말줄임 0) | 최소 대상 48까지 | — |
| — | 안내·알림·배너·보스 이름·일시정지·설정·강화 줄·알림 창 | | ko·en | | | 모두 맞음. 가장 빡빡한 것: 결과 버튼 4개에서 "Next Round" 74/77, 안내 띠 `toast.save_recovered` en 394/492 | | — |
- 시험 코드 차이(04 참고): test_ui.gd는 결과 버튼 칸을 (356−16)/3−6 = 107 px로, 메뉴 작은 버튼을 81 px로 본다. 실제 코드는 각각 77 px(버튼 4개, 패널 380)와 72 px(작업본)이다. 지금 문구는 그래도 다 맞지만, 시험이 실제 칸을 재지 않는다.

## 4. 첫 실행부터 r01 첫 승리까지 화면 문구 (순서대로)
근거: app.gd boot → main_menu.gd → `시작`은 continue_round_id()로 r01 바로 시작 → hud.gd/hud_top.gd → tutorial_director.gd(02) 조건 → battle.gd 알림 → result.gd. 시간은 데이터·코드 조건이다(r01: 시작 밀가루 60, 웨이브 12/40/75초, 적 기지 50 %에서 반격). **사람이 실제로 이해하는지는 재지 않았다.**
판정: 행동 = 문구만 보고 무엇을 누를지 알 수 있나(명확 / 애매 / 없음). 용어 = 설명 없이 처음 나오는 말.
| # | 언제 | 화면에 나오는 문구 (ko / en) | 행동 | 처음 나오는 용어·문제 |
|---|---|---|---|---|
| 1 | 홈 화면 | 빵집 기사단 / Bakery Knights | — | — |
| 2 | 메인 메뉴 | 로고 "빵집 기사단: 곰팡이 디펜스", 부제 "빵집 마을을 지키고 곰팡이 둥지를 부숴라", 동전 그림 + "0", 버튼 **시작**·라운드 선택·강화·설정, "v0.1.0" | 명확(시작이 가장 큼) | "곰팡이 둥지"(뒤의 안내는 "적 기지"라고 부름, T-07). 동전 숫자에 이름 없음 |
| 3 | r01 0초 | 왼쪽 위 "밀가루 60/200", "기력" + 막대(640폭에서는 `+x/s` 없음, T-02). 가운데 "1500/1500 VS 800/800", "0/36", "1. 첫 번째 굽기   웨이브 0/3  다음 12초". 아래 ◀ ▶, 팔각형 "제빵사 40"(배지 0), 카드 "식빵병 30" | — | **기력**: r01에는 스킬이 없어 쓸 곳이 없는데 막대가 차오른다(T-06). "0/36"(병력 수)에 이름 없음 |
| 4 | 0초 안내 | ◀ ▶ 버튼을 누르고 있으면 영웅이 움직입니다. / Hold ◀ ▶ to move your hero. | 명확 | "영웅"이 어느 그림인지 화면에 표시 없음(작음) |
| 5 | 영웅을 움직인 뒤, 안 움직이면 **20초 뒤** | 카드를 눌러 병사를 보내세요. / Tap a card to send a soldier. | 애매: 아래 줄에 카드처럼 생긴 것이 둘(제빵사 팔각형, 식빵병) | **순서 문제(T-08)**: 안내는 순서대로만 나온다. 영웅을 안 움직이면 이 안내가 20초까지 안 나오고, 그 사이 6초부터 적이 오고 12초에 첫 웨이브가 온다 |
| 6 | 12초 | 알림 "적 웨이브가 몰려옵니다!", 배너 "웨이브 1/3" | — | — |
| 7 | 첫 출병 뒤 밀가루 ≥ 40 | 제빵사를 고용하면 밀가루가 더 빨리 찹니다. / Hire bakers to gather flour faster. | 애매: "고용"할 버튼이 "제빵사"라는 건 이름이 같아 짐작은 된다. 효과(초당 수입)는 640폭에서 안 보인다 | "찹니다"는 막대에 맞는 말인데 밀가루는 숫자다 |
| 8 | 아무 때나 | 밀가루가 부족합니다 / 아직 준비 중입니다 / 제빵사가 최대입니다 / 병력이 가득 찼습니다 | 명확 | — |
| 9 | 영웅이 쓰러지면 | 영웅이 부활 중입니다 + ◀ 버튼에 빨간 숫자 | 숫자의 뜻은 알림이 1.6초 떠 있는 동안만 알 수 있다 | `ui.respawn` "부활 %d초"는 데이터에 있지만 안 쓴다 |
| 10 | 아군이 길의 50 %를 넘으면 (8초 표시) | 오른쪽 끝의 적 기지를 부수면 승리! / Destroy the enemy base on the far right to win! | 명확(누를 것은 없음) | "적 기지" = 부제의 "곰팡이 둥지" = 오른쪽 둥지 표시(T-07) |
| 11 | 첫 웨이브를 다 잡으면(데이터상 약 37–47초) | 배너 "첫 웨이브 격파!" | — | — |
| 12 | 40초, 75초 | "적 웨이브가 몰려옵니다!", "웨이브 2/3", "웨이브 3/3" | — | — |
| 13 | 적 기지 50 % 아래 | 적이 반격합니다! | — | — |
| 14 | 승리 | "승리!", ★승리 ★기지 체력 50% 이상 ★150초 안에 클리어, 시간·처치·보상 +숫자, "첫 클리어 보너스!", 버튼 메뉴로·강화·다시하기·**다음 라운드** | 명확 | "메뉴로"는 라운드 선택 화면으로 간다(T-09). "보상" 숫자가 골드라는 표시 없음 |
요약: 0–20초 구간이 가장 약하다. 첫 안내가 영웅 이동이고, 출병 안내는 영웅을 움직여야 나온다. r01에서 쓸 수 없는 "기력"이 처음부터 보인다. 640폭 화면에서는 제빵사 효과(초당 수입)를 숫자로 볼 수 없다.

## 5. 발견 목록과 요청
우선순위: P2 = 첫 3분 이해나 정보 손실, P3 = 표기·일관성.
| ID | 내용 | 우선 | 담당 (요청 파일) |
|---|---|---|---|
| T-01 | en 웨이브 줄에서 남은 시간이 잘림 (r05/r06/r10, 640+노치) | P2 | 04 규칙(라운드 이름을 먼저 줄이거나 뺌), 01 en `ui.wave_next` "Next %ds" (r05·r10 해결, r06은 최소 대상 48에서 2.6 px 남음) |
| T-02 | 640폭 화면에서 `+x/s` 수입 숫자가 항상 숨음 (ko 0.68 px 차) | P2 | 04 |
| T-03 | en "Select Round"가 메뉴에서 10 px로 작아짐 | P3 | 01 (en "Rounds" 46 px) |
| T-04 | en `ui.star_base_hp_any` 말줄임 (지금은 안 나옴) | P3 | 01 |
| T-05 | D31 패배 안내가 2줄씩 됨, 아직 그리지 않음 | P2 (r05 첫 막힘) | 01 짧은 문구(각 1줄), 04 그리기 |
| T-06 | r01에서 쓸 곳 없는 "기력"이 보임 | P2 | 04 (스킬 없는 라운드에서 기력 줄 숨김) |
| T-07 | 적 기지를 "적 기지"와 "곰팡이 둥지" 두 이름으로 부름; WORLD.md 이름표(빵집/곰팡이 둥지)와 화면이 다름 | P3 | 01 |
| T-08 | r01 출병 안내가 영웅 이동 뒤에만 나옴(최대 20초) | P2 | 01 (데이터 순서), 참고 02 (tutorial_director 시간 제한) |
| T-09 | "메뉴로/Menu"가 라운드 선택으로 감 | P3 | 01 문구 (또는 04 목적지) |
| T-10 | `upgrade.supply_regen` 보급/Supply, `upgrade.worker` 일꾼/Worker, en `upgrade.base_hp` Base Armor(효과는 체력) | P3 (QA-B018 포함) | 01 |
| T-11 | en `tut_fast_unit` "Pretzel Riders"는 카드 이름 Twist와 연결이 안 됨 | P3 | 01 |
| T-12 | 안내가 화면에 안 나오는 적 이름을 씀(포자 뱉개, Spore Spitters) | P3 | 01 |
| T-13 | `ui.upgrade_error`가 엔진 코드(예: no_reply)를 그대로 보여 줌 | P3 | 01 문구 + 04 호출 동시 변경 |
| T-14 | 02 대체 콘텐츠의 영어 이름(Catapult 등)이 37 px 칸에서 잘리고 한국어 기기에서도 영어 | P3 (데이터를 못 읽을 때만) | 02 |
| T-15 | 04 대체 문구(ui_text.gd FALLBACK_KO) 8개가 데이터와 다름(일꾼, 보급, 코인, 다음 %ds…), hud_top.gd 주석 "반죽/Dough" | P3 | 04 |
| T-16 | 쓰지 않는 키: `ui.respawn`, `ui.locked`, `ui.pause`, `ui.round_n`, `ui.coins`, `currency.gold/gems`, `unit.worker.name`(HUD는 `ui.worker`), 설명(desc) 전부, `hint.loss.*` | 정보 | 01·04 |
| T-17 | Pillow 폭 계산은 GPOS 커닝을 빼서 라틴 이름이 1 px 크게 나옴 (WORLD.md en 폭, 06 도구 size_candidates.py·launcher_icons.py) | 정보 | 03 (글꼴 규칙 문서), 01 |
| S-01..04 | 스토어 문서(얼어 있음): "기술"/"스킬", 광고·결제 없음 문장, 그림 문구 "반죽", 창 제목 "Lane Defence" 설명이 지금 코드와 다름 | — | 조정자 |
요청 파일: coordination/requests/12-text-review-to-01-director.md, -to-04-client.md, -to-03-art.md, -to-02-engine.md, -to-coordinator.md.

## 6. 하지 않은 것·한계
- 렌더 화면, 실제 폰, 사람 판단은 없다. "이해된다/애매하다"는 문구와 조건을 읽은 판단이다(D11: 사람 시험 전에는 가설).
- 04 작업본은 커밋 전이라 바뀔 수 있다. 커밋되면 `measure_text.py`를 다시 돌리면 된다.
- 그림자(1 px)는 칸 여백 3 px 안이라 폭 판정에 넣지 않았다. 숫자 칸(고정 폭)은 hud_top의 식을 따랐다.
