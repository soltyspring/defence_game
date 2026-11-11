# Fable 5.2 핵심 구현 진행 기록

마지막 갱신: 2026-11-11 03:30 KST · 기준 커밋 `9b730fd` 위의 **미커밋 작업 트리 변경** (커밋·푸시·빌드 안 함)
다른 세션·GPT가 이어받기 위한 문서. 규칙은 [fable52/STYLE_RULES.md](fable52/STYLE_RULES.md), 증거는 `fable52/evidence/`.

## 상태 요약

| 항목 | 상태 |
|---|---|
| 배경 v2 세트 + 양쪽 기지 주변 | 코드·에셋 적용됨. **Godot 미실행** (Python 목업으로만 확인) |
| 대표 캐릭터 4종 (영웅·식빵병·곰팡이 졸개·곰팡이 장군) | 아틀라스 적용됨. 아틀라스 검증 PASS, 계약 변경 0 |
| 미니맵·HUD 축소, 좁은 창 입력 | 코드 적용됨. Python 미러 1,944개 배치 통과. **Godot 미실행** |
| 같은 아군 대형 고정 | 코드 적용됨. Python 미러 통과. **Godot 미실행** |
| 적 기지 피해 숫자 | 코드 적용됨. **Godot 미실행** |

이 작업 환경에는 Godot가 없어 GDScript는 한 번도 실행하지 못했다. 첫 할 일은 임포트와 테스트 실행이다(아래 "이어서 할 일").

## 바꾼 파일

**게임 코드**
- `src/gameplay/lane_backdrop.gd` — `lane_set_v2.png`가 있으면 v2(밭 단순화, 월드 고정 세트 2장, 앞마당·포자 자락, 불규칙한 곰팡이 줄기). 없으면 기존 v1 그대로. `build()`에 기지 x 인자 추가(기본값 있음).
- `src/gameplay/bakery_supply.gd` — v2일 때 제분소를 세트 시트의 풍차로 그림.
- `src/gameplay/battle_view.gd` — ① 대형: 걷는 유닛은 열을 바꾸지 않고, 멈춘 뒤 실제로 겹쳐 그려질 때만 가장 가까운 빈 열로 이동(`drawn_x`/`column_blocked`/`free_column`). ② 기지 피해: 기지당 누적 숫자 1개가 연타 중 제자리에 머물고 마지막 타격 0.45초 뒤 한 번 떠오르며 사라짐(`_feed_base_combo`/`_draw_base_combos`). 표시만 바꾸며 sim의 피해·텍스트 값은 그대로. ③ v2 배경에서는 보스 3배 밝기 보정을 끔.
- `src/ui/hud_layout.gd` — 미니맵 폭 126–150 → 84–104. 막대+미니맵이 안 들어가면 미니맵을 숨김. 보스가 없으면 안내·표식이 보스 바 줄로 올라감(`boss_bar` 인자, 기본 true). 아주 작은 창에서는 모든 버튼을 한 줄에 균등 축소(`fit`).
- `src/ui/hud.gd` — 보스 생존 여부로 재배치. 매 프레임 논리 뷰 크기를 비교해 바뀌면 눌린 버튼을 해제하고 재배치.
- `src/ui/ui_screen.gd` — 0.5초 타이머를 0.2초로, 논리 뷰 크기 변화도 감지.

**입력 막힘 원인 (추정, Godot 미확인)**: `App`이 `_process`에서 정수 배율을 다시 정하는데, 화면은 그보다 먼저 온 `size_changed`에서 이미 배치를 끝냈다. 다음 신호·타이머까지 버튼이 이전 논리 크기로 그려지고 판정됐다. 또 폭 392 미만에서는 카드가 오른쪽 밖으로 나가고, 낮은 창에서는 스킬 세로 열이 일시정지 버튼 위에 겹쳤다(v0.1.5 계산으로 1,944개 중 438개 배치).

**아트**
- 새 파일: `tools/art/world/lane_set.py`, `tools/art/world/lane_mock.py`, `tools/art/chars_fable.py`, `assets/backgrounds/lane_set_v2.png`·`.json`
- 수정: `tools/art/build.py`(+3줄, `ART_FABLE=0`이면 이전 아트), `assets/atlases/char_player.png`·`.json`, `char_boss_warlord.png`·`.json`, `assets/manifest.json`(두 페이지 용량·합계), `tools/art/layout_lock/char_player.json`(프레임 1개 위치 이동)
- 기지 스프라이트(`bases.png`)는 그대로다. 기지 주변(마을 세트·풍차·앞마당 / 오염 세트·포자 자락)을 새로 했다.

**테스트·도구**
- 새 파일: `tests/acceptance/test_fable52_core.gd`, `tools/qa/hud_layout_mirror.py`, `tools/qa/formation_mirror.py`

**건드리지 않은 것**: `tools/art/bases.py`, `src/audio/*`, `docs/contracts/INTERFACES.md`, `coordination/*`의 기존 미커밋 변경. 다른 아틀라스 PNG도 다시 쓰지 않았다.
`src/gameplay/*.gd` 3개는 작업 트리가 원래 CRLF라 Linux git에서는 파일 전체가 바뀐 것처럼 보인다. 실제 변경은 `git diff --ignore-cr-at-eol`로 본다.

## 실제로 검증한 것

- `python tools/art/validate.py` — PASS, 경고 0 (작업 사본에서 전체 재빌드 후).
- `python tools/art/contract_diff.py` — `contract_changed: false`, 이동한 rect 1개.
- `python tools/qa/hud_layout_mirror.py` — 1,944개 배치 중 닿지 않거나 겹치는 컨트롤: 이전 438 → 0. 640×360에서 미니맵 139 → 95px, 기지 체력 막대 217 → 261px, 보스 없을 때 배너 하단 142 → 126.
- `python tools/qa/formation_mirror.py` — 24명 45초 모델에서 자리 재배정 42 → 13회, 마지막에 겹쳐 그려진 쌍 4 → 0.
- 같은 장면 전후(Python 목업, 640×360): `fable52/evidence/pair_{home,clash,boss}_top-before_bottom-after_1x.png`, 흑백 `gray_*`, 2배 확대 `after_*_lane_2x.png`, 캐릭터 시트 전후 `chars_sheets_before-above_after-below.png`.

**검증하지 못한 것**: Godot에서의 파싱·실행 전부, 실제 게임 캡처, 실제 창 크기 변경 입력, 드로우콜·프레임 시간. 목업은 `lane_backdrop.gd`를 Python으로 옮긴 것이라 게임 화면과 다를 수 있다.

## 이어서 할 일 (GPT)

1. `coordination/HEAVY_RUN.md` 규칙대로 Godot `--import` 실행 (`lane_set_v2.png` 신규, 아틀라스 2장 변경). 임포트 전에는 v1 배경과 이전 캐릭터가 보인다.
2. `godot --headless --path . -s tests/acceptance/test_fable52_core.gd` 실행. 이어서 기존 `test_formation_stability.gd`, `test_resolution_input.gd`, `tests/ui/test_ui.gd`, 수락 스위트 회귀. 미니맵 폭이나 `compute()` 결과를 고정값으로 검사하는 기존 테스트는 실패할 수 있다.
3. 같은 SHA에서 R01·R06·R10 전후 캡처, 창 크기 변경 중 버튼 입력, 보스 바+안내 중첩 확인.
4. 변종 확인: `e_guard`(졸개 스프라이트 + 베이지 색조), `boss_millward`·`boss_frostguard`(장군 스프라이트 + 색조 ×1.4)가 새 그림에서 어떻게 보이는지. 베이지 색조는 아군 색과 가까워 규칙 위반이다.
5. 나머지 캐릭터(아군 4, 일반 적 7, 보스 5, 제빵사·일꾼)를 STYLE_RULES대로 제작. 구간 2·3의 home/blight 세트 추가.
6. 기지 스프라이트 자체의 리드로우 여부 결정, 나머지 메뉴 화면, 해상도 전수 QA, 문서, EXE 빌드.

## Codex 인수 후 검증 (2026-11-11)

- 프로젝트에 포함된 Godot 4.7.2로 새 배경과 아틀라스를 임포트했다. Windows 헤드리스에서 핵심 59/59, 대형 6/6, UI 3,415/3,415, 음량 29/29가 통과했다. UI 검사에는 영문 타이틀의 텍스트 대체 경로 폭 경고가 남는다.
- 헤드리스 창 크기는 네이티브 값이 없어서 기존 해상도 검사 3개가 맞지 않았다. 격리된 Linux 가상 X11 화면에서 같은 검사(크기, 마우스·터치 입력, 리사이즈 중 포인터 유지, 배율)를 돌렸을 때 기준과 변경판 모두 116/116 통과했다. 변경판에 1920×1080·480×270을 추가해 150/150을 확인했다. 테스트 종료 시 리소스 해제 경고는 기준판에도 있었다. 실제 Windows 데스크톱이나 Android 실기기를 검증했다는 뜻은 아니다.
- 전체 수락 스위트는 156 PASS / 0 FAIL / 2 NOT_TESTED(오디오 큐 실동작, Android 실기기)였다. 별도의 음량 저장 테스트는 위의 29건에 해당한다.
- 기준 `9b730fd`와 변경판을 같은 1280×720 전투 배치에서 렌더했다. 양쪽 기지, 교전, 보스를 포함한 R01/R06/R10/R20/R30의 기준 캡처는 `build/fable52-render/before/`, 최종 캡처는 `build/fable52-render-final/after/`에 있다. Python 목업과 별도의 실제 Godot 렌더이며 프레임 시간이나 사용자 플레이 결과의 증거는 아니다.
- R06 중앙에 낮은 대비의 곡물 창고와 방풍림을 넣고 능선을 낮췄다. R20의 과수원 나무와 R30의 서리 아치는 기존 밭 메시를 재사용한다. 베이지 계열 적 변종은 냉색으로 조정했고 방패·보스 머리 장식을 형태로 구분했다. 독립 스프라이트를 제작한 것은 아니다.
- 남은 작업: 대표 4종 외 전 캐릭터와 카드 초상 리드로우, 양쪽 기지 본체 리드로우, 네이티브 Windows 및 모바일 실기기 입력, 나머지 메뉴, 배포용 EXE. 기지 생성기의 기존 미커밋 실험은 보존했다.

## 도전 챕터 R31–R40 대표 전투 (2026-11-11 오후, Fable)

- 설계·규칙·인수인계: [../design/CHALLENGE_R31_R40.md](../design/CHALLENGE_R31_R40.md). R31·R35·R40과 유닛 규칙 `heavy`(예고→큰 공격→회복), `link`(균사 연결), `hold_behind`를 구현했다.
- 바꾼 파일: `src/gameplay/battle_sim.gd`, `battle_view.gd`, `battle.gd`, `lane_backdrop.gd`(`biome_nest` 색조 3줄), `src/core/content.gd`, `app.gd`, `data/units/units.json`(+3종), `data/rounds/order.json`(`challenge`), `data/text/ko.json`·`en.json`, `tests/acceptance/suite_data.gd`(DATA-03이 `challenge.rounds`를 인정). 새 파일: `data/rounds/r31.json`·`r35.json`·`r40.json`, `tests/acceptance/test_challenge_core.gd`, `probe_challenge.gd`, `challenge_bot.gd`.
- 챕터는 닫혀 있다(`challenge.enabled: false`). 플레이어 순서는 R01–R30 그대로이고 대표 3개는 `--round=r31|r35|r40`로만 시작되며 저장에 아무것도 남기지 않는다.
- Linux용 Godot 4.7.2 디버그 템플릿으로 헤드리스 실행: 도전 핵심 252/252, 캠페인 390/390, UI 3,415/3,415, 수락 112 PASS / 0 FAIL(flow 묶음 제외). 바꾸기 전 시뮬레이션과 R01–R30 8개 라운드 결과 동일.
- 남은 일: R32–34·R36–39 데이터, 적 3종 아트, 전용 효과음, 사람 플레이 기준 수치 조정, Windows에서 `-s` 재실행과 flow 묶음.

## 서리길·둥지 새 적 4종과 서리 보스 변주 (2026-11-11 저녁, Fable)

- 설계·검증·인수인계: [../design/FROST_NEST_ENEMIES.md](../design/FROST_NEST_ENEMIES.md). 지시문은 저장소 루트의 `프롬프트.md`.
- 새 적: 서리 갑각병, 빙결 질주자(R21·R22·R25), 발효 포자낭(R37), 균사 잠입병(R38). 서리 방벽 보스가 돌진과 냉기 내려찍기를 번갈아 쓴다. 규칙은 `heavy`의 `kind`(slam·vent·charge·lob·burrow)와 `shell` 키 하나로 처리한다.
- 바꾼 파일: `src/gameplay/battle_sim.gd`·`battle_view.gd`·`battle.gd`·`lane_backdrop.gd`, `src/ui/hud_top.gd`·`result.gd`, `data/units/units.json`, `data/rounds/r21·r22·r25·r37·r38.json`(웨이브·트리클·HP 트리거만), `data/text/*.json`, `tools/art/chars_challenge.py`와 `assets/atlases/char_challenge.*`·`assets/manifest.json`, `tests/acceptance/challenge_bot.gd`·`probe_challenge.gd`·`test_challenge_core.gd`. 새 파일: `tests/acceptance/test_frost_nest_core.gd`, `capture_frost_nest.gd`, `docs/art/fable52/frost/`.
- 실행 결과(Linux Godot 4.7.2 디버그 템플릿): 새 규칙 141/141, 도전 237/237, UI 3,416/3,416, 수락 112 PASS·0 FAIL. 640×360·1280×720 전후 캡처 6장면.
- 가장 큰 미달: R21·R22에서는 예고에 대응해도 봇 기준 결과가 같다. 사람 플레이 미실시. `char_challenge.png`는 Windows에서 다시 임포트해야 한다.
