# UI 그래픽 원인 측정 (06-art-ui, 2026-11-01)

담당: 06-art-ui. 대상: 카드·스킬 아이콘·HUD·타이틀 로고. 측정 기준 HEAD: 278d52b 시점의 `assets/atlases/ui_main`
(1aec5fe까지 이 페이지는 바뀌지 않음). Godot 없이 PNG 픽셀로 측정했다.

- 도구: `python tools/art/ui_art/ui_audit.py --hud docs/qa/readable_numbers/ko_640_notch_r05_3_hud.png --criteria`
- 결과 파일: `docs/art/evidence/ui_art/before_audit.json`, 그림 `before_cards_x4.png`, `before_ui_main_x4.png`
- 색 차이: CIE76 ΔE(Lab). 색각 이상: Machado 2009, 강도 1.0(protan·deutan). 명암: WCAG 2 대비비.
- 화면 색은 실제 캡처에서 쟀다. 카드 몸통 #694226(04 `C_PANEL_LIGHT` #6e4528, α .95)과 일꾼 버튼 #493f27은
  `ko_640_notch_r05_3_hud.png`, 메뉴 하늘 #3d517a는 `docs/verification/evidence/visual7-fca9346/{ko,en}_2x_notch_1_menu.png`.

## 화면에 실제로 나오는 아틀라스 프레임

04 코드(`src/ui/**`)가 쓰는 `ui_main` 프레임은 아래뿐이다. 나머지 UI 바탕(패널·버튼·카드 몸통·결과 리본·막대)은
04가 `StyleBoxFlat`과 `draw_pixel_box`로 직접 그린다.

| 쓰는 곳 | 프레임 |
|---|---|
| HUD 카드 버튼 (`hud.gd` 172–174, `battle_sim.gd` 1168) | `card_<unit>` |
| HUD 스킬 버튼 (`hud.gd` 189) | `icon_skill_slam/rally/barrage` |
| HUD 이동·일시정지 | `btn_move_left/right`, `icon_pause` |
| 자원 줄 (`hud_top.gd`) | `icon_supply`, `icon_energy` |
| 메뉴·라운드 선택·강화 | `icon_gold`, `icon_lock`, `icon_star`, `icon_star_empty` |
| 위협 표시 (`threat_marker.gd`) | `icon_nest`, `icon_skull` |
| 타이틀 (`title_block.gd`) | `logo_title_<ko|en>`, `logo_title_<ko|en>_2line` |

`panel`, `panel_dark`, `btn*`, `card_frame*`, `ribbon_*`, `bar_*`, `digit_*` 9-slice와 숫자는 어느 화면에도 쓰이지 않는다.
이 프레임을 다시 그려도 캡처는 바뀌지 않는다. 04가 쓰기로 해야 효과가 있다(요청 `coordination/requests/06-art-ui-to-04-client.md`).

## 원인 1. 카드 7장이 서로 구별되지 않는다

| 측정 | 값 |
|---|---|
| 판 색 (7장 모두) | #6e4528 |
| 판 색 차이, 15쌍 (HUD 줄 6장) | ΔE 0.0 (일반·protan·deutan 모두) |
| 판 모양 IoU, 15쌍 | 1.00 (모두 같은 24×24 정사각형) |
| 실제 HUD 캡처, 카드 5장 평균색 쌍별 ΔE | 최소 1.7, 중앙 12.1, 최대 26.9 |

카드끼리 다른 것은 판 안의 작은 인물뿐이다. 인물도 같은 빵 색 계열이라 평균색 차이가 최소 1.7이다.
원인 위치: `tools/art/build.py`(03) 230행이 모든 아군 카드에 같은 `ui.portrait(fr)`을 부른다. `portrait()`는 유닛 id를 받지 않는다.

## 원인 2. 카드 판·인물·HUD가 같은 밝기다

| 측정 | 값 | 비고 |
|---|---|---|
| 판 #6e4528 대 카드 몸통 #694226 | 1.06:1 | 판 테두리가 몸통에 묻힘 |
| 일꾼 판 대 일꾼 버튼 #493f27 | 1.26:1 | |
| 인물 가장자리 대 판 (판에 닿는 인물 픽셀의 중앙값) | 2.18:1, 화덕포 1.88:1 | K 외곽선 #1b1325 대 #6e4528 |
| 인물 전체 중앙 밝기 대 판 | 1.72–1.88 (식빵병·롤빵병·통식빵·제빵사·화덕포) | 참고값 |
| HUD 카드 버튼 평균 대 흙 바닥 #9f6d42 | 1.86–2.82:1, ΔL* −16.9 ~ −28.7 | 몸통 색은 04 코드 |
| 이동 버튼 대 흙 바닥 | 2.06:1 | |
| 스킬 버튼 대 흙 바닥 | 2.90, 2.88:1 | |

판·몸통·외곽선이 모두 진한 갈색이라 카드 안에서 무엇이 판이고 무엇이 인물인지 밝기로 갈리지 않는다.
HUD 줄 전체도 흙 바닥과 3:1이 안 된다. 이 부분의 몸통·바탕 색은 04 코드라서 06은 아이콘만 고칠 수 있다.

## 원인 3. 스킬 아이콘과 타이틀 로고의 글자·그림이 바탕에 묻힌다

| 측정 | 값 |
|---|---|
| 밀대 내려찍기: 그림(밝은 쪽 75% 백분위) 대 판 #6e4528 | 1.88:1 |
| 빵가루 포격: 그림 대 판 #9a5f12 | 2.33:1 |
| 갓 구운 함성: 그림 대 판 #5c1631 | 10.61:1 (문제 없음) |
| 로고 2줄째 "곰팡이 디펜스": 글자 면 픽셀 중 하늘과 3:1 이상 | 15.7% |
| 로고 2줄째 "Mold Defense" | 12.1% |
| 로고 1줄째 "빵집 기사단" / "Bakery Knights" | 63.3% / 73.3% |

로고 원인: `branding.paint()`는 획의 오른쪽·아래 1 px를 `edge` 색으로 칠한다. 2배 글자는 획이 2 px라서 글자 면의
약 절반이 `edge` 색이다. 곰팡이 줄은 `edge` D #1e2b30(하늘과 1.84:1), 채움 t/l(2.78, 1.18:1)이었다.
빵 줄은 `edge` w와 아래쪽 o(둘 다 1.80:1)가 3:1 아래였다.

## 고친 것과 남은 것

수치 기준은 `UI_ART_CRITERIA.md`, 결과는 같은 파일의 "결과" 표에 적는다.

- 06이 고친 것(`tools/art/ui.py`, `tools/art/branding.py`): 유닛별 카드 배지 `ui.card()`, 밀대·포격 판 색,
  빈 별 테두리, 이동 버튼, 로고 색 단계.
- 03에 요청(R1): `build.py` 카드 호출 한 줄을 `ui.card(uid, fr)`로. 이 변경 전에는 빌드된 `card_*`가 그대로다.
- 04에 요청: 9-slice 프레임 사용 여부, HUD 줄 대 바닥 3:1, 카드 몸통 색.
