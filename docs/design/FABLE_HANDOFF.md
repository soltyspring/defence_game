# Fable 작업 이어받기

**게임 기준: `fd2c94a` (2026-11-11, 로컬 커밋. 푸시는 하지 못했다).** 요구는 루트의 `프롬프트.md`. 이 기록은 마지막 기준선이며 현재 작업 트리의 검증을 대신하지 않는다. 작업이 이어지면 이 문서의 내용을 최신 상태로 교체한다.

- 끝난 단계 — **1. 부활 표시와 음향 신호**: 좌우 버튼은 항상 화살표다. 카운트다운은 `src/ui/revive_badge.gd`가 `HudLayout`의 `revive` 칸(상단 바·보스 바 아래, 입력 없음, 좁으면 아이콘+숫자)에 그린다. 사망 순간 눌린 이동(버튼·키)을 해제하고 부활 뒤 새로 누르기 전에는 서 있다. 사망 토스트 제거, 사망음·부활음 각 1회. 돌진 예고는 `frost_charge_windup`, 포자 착탄은 `spore_burst`(sim 이벤트 `lob_burst`).
- 실행한 검증(Linux Godot 4.7.2 디버그 템플릿, 헤드리스·Xvfb): `test_revive_hud.gd` 63/63, UI 3,417/3,417, 서리길 180/180, 도전 237/237. 전후 캡처 `docs/art/fable52/revive/`(640×360, 1280×720).
- 검증하지 못한 것: `tools/audio/validate.py`(scipy 없음. 새·수정 wav 5개는 형식·피크·300Hz 비율만 수동 확인), 실제 청감, Windows 임포트(새 wav 2개의 `.import` 없음), 네이티브 창·터치, 480×270 캡처, 전투 숫자가 부활 칸 위로 겹쳐 지나가는 경우.
- **다음 시작점 — 2. 이용권·저장과 경제**: 권한·구매·복원은 새로 만들지 말고 `src/services/billing/purchase_service.gd`의 `has_entitlement`·`purchase`·`restore`·`availability`와 모의 공급자를 쓴다. 판정은 한 곳(`src/core/save.gd`에 `round_access(order_index)` → `""`·`locked_prev`·`locked_act2`)에 두고 `src/core/app.gd`의 `start_round`·`_on_next_round`와 `src/ui/round_select.gd`가 같이 쓴다. 정한 방침: 결제 공급자가 없는 프로필은 잠금을 걸지 않는다 / R21 이상에 별이 있는 기존 저장은 이용 가능 / 강제 QA 진입은 계속 저장하지 않는다. 가격·상품 ID는 `src/core/gold_shop_catalog.gd` 옆에 둔다. 경제표는 `docs/design/RELEASE_BALANCE.md`(새 파일), 프로브는 `tests/acceptance/probe_progression_campaign30.gd` 확장.
- 대기: 3. R31–40 열 전투 개편과 아트(R35 중간 보스, R36 포자낭 단독, R39 시차 조합, R40 페이즈), 4. 대응/무시 세 조건 비교. R21·R22의 대응 이득과 제빵사 1명 조건의 R37·R38 패배는 아직 그대로다.

상세 증거가 필요할 때만 [서리길 검증](FROST_NEST_ENEMIES.md)의 마지막 절이나 [도전 챕터 설계](CHALLENGE_R31_R40.md)의 관련 절을 확인한다.
