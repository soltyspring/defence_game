# 배경 변경표 R01–R40

생성: `python tools/art/world/backdrop_sheets.py` (표는 `src/gameplay/backdrop_scenes.gd`의 `ROUNDS`·`NOTES`에서 만든다). 캡처는 640×360 실제 게임 화면(`tests/acceptance/capture_backdrop.gd`).

- 전후 비교: `pair_ch1..4_left-before_right-after.png` (챕터별 초입·중간·보스, 교전 장면과 적 기지 앞 장면)
- 40개 라운드 교전 장면: `rounds_all_r01-r40_fight_half-size.png`
- R40 연결/노출: `r40_core_left-linked_right-exposed.png`

## R01–R10 밀밭 마을

| 라운드 | 이 라운드에서 달라지는 것 | 랜드마크 (위치) | 캡처 |
|---|---|---|---|
| R01 | 아침. 곡물 창고와 방풍림, 멀리 작은 둥지 | shelter(중경), windbreak(중경), nest_far(능선) | 있음 |
| R02 | 곡물 창고와 불 켜진 노점 | shelter(중경), stall(중경), nest_far(능선) | 있음 |
| R03 | 노점과 불 켜진 가게 둘 | stall(중경), shop(중경), shop(중경), nest_far(능선) | 있음 |
| R04 | 첫 불 꺼진 가게, 온전한 방책 | shop(중경), shop(중경), palisade(길가), nest_far(능선) | 있음 |
| R05 | 늦은 오후. 방책 한 곳이 무너지고 연기, 둥지가 커짐 | shop(중경), smoke(중경), palisade(길가), nest_far(능선) | 있음 |
| R06 | 불 꺼진 가게 둘, 버려진 수레 | shop(중경), shop(중경), cart(길가), nest_far(능선) | 있음 |
| R07 | 무너진 방책·수레·판자 친 가게 | palisade(길가), cart(길가), shop(중경), nest_far(능선) | 있음 |
| R08 | 노을. 탄 노점, 방책 두 곳 붕괴 | stall(중경), shop(중경), palisade(길가), palisade(길가), nest_far(능선) | 있음 |
| R09 | 방책 잔해뿐, 연기, 능선 위 둥지 전체 | palisade(길가), shop(중경), smoke(중경), palisade(길가), nest_far(능선) | 있음 |
| R10 | 흐린 저녁. 둥지가 적 기지 바로 뒤 전면에 드러남 | shop(중경), smoke(중경), palisade(길가), nest_front(적 기지 뒤) | 있음 |

## R11–R20 오염 과수원

| 라운드 | 이 라운드에서 달라지는 것 | 랜드마크 (위치) | 캡처 |
|---|---|---|---|
| R11 | 과수원 문과 열매 달린 나무 | orchard_gate(길가), fruit_tree(중경), fruit_tree(중경), tree_ridge(능선) | 있음 |
| R12 | 사다리와 바구니, 나무 세 그루 | fruit_tree(중경), ladder(길가), fruit_tree(중경), fruit_tree(중경), tree_ridge(능선) | 있음 |
| R13 | 첫 쓰러진 수레 | fruit_tree(중경), cart_fallen(길가), fruit_tree(중경), tree_ridge(능선) | 있음 |
| R14 | 곰팡이 핀 나무와 첫 안개 | fruit_tree(중경), blight_tree(중경), ladder(길가), fog(중경), tree_ridge(능선) | 있음 |
| R15 | 버려진 착즙 헛간(중간 보스) | press_house(중경), cart_fallen(길가), blight_tree(중경), fog(중경), tree_ridge(능선) | 있음 |
| R16 | 잎 진 나무와 짙은 안개 두 겹 | bare_tree(중경), bare_tree(중경), fog(중경), fog(중경), tree_ridge(능선) | 있음 |
| R17 | 수레 두 대 바리케이드 | cart_fallen(길가), cart_fallen(길가), bare_tree(중경), blight_tree(중경), fog(중경), tree_ridge(능선) | 있음 |
| R18 | 능선 너머 제분소 실루엣 | bare_tree(중경), mill_ruin(능선), blight_tree(중경), fog(중경), tree_ridge(능선) | 있음 |
| R19 | 제분소가 중경으로, 부서진 물레 | blight_tree(중경), mill_ruin(중경), cart_fallen(길가), fog(중경), fog(중경), tree_ridge(능선) | 있음 |
| R20 | 뿌리 아치를 지나 적 기지 뒤 제분소 폐허 | bare_tree(중경), blight_tree(중경), root_arch(길가), mill_ruin(적 기지 뒤), fog(중경) | 있음 |

## R21–R30 서리길

| 라운드 | 이 라운드에서 달라지는 것 | 랜드마크 (위치) | 캡처 |
|---|---|---|---|
| R21 | 눈 덮인 울타리와 이정표, 아군 화덕 불빛 | hearth(아군 기지 옆), snow_fence(길가), signpost(길가), peaks(능선) | 있음 |
| R22 | 얼어붙은 저장고 하나 | hearth(아군 기지 옆), silo(중경), snow_fence(길가), peaks(능선) | 있음 |
| R23 | 저장고 세 동 | hearth(아군 기지 옆), silo(중경), silo(중경), silo(중경), peaks(능선) | 있음 |
| R24 | 제분장과 얼어붙은 물레 | hearth(아군 기지 옆), silo(중경), mill_hall(중경), peaks(능선) | 있음 |
| R25 | 제분장 두 동, 멀리 얼음 방벽(보스) | hearth(아군 기지 옆), mill_hall(중경), mill_hall(중경), ice_wall(능선), peaks(능선) | 있음 |
| R26 | 식은 굴뚝, 방벽이 가까워짐 | hearth(아군 기지 옆), mill_hall(중경), chimney(중경), ice_wall(능선), peaks(능선) | 있음 |
| R27 | 얼음 방벽과 관문 | hearth(아군 기지 옆), ice_wall(중경), ice_gate(중경), peaks(능선) | 있음 |
| R28 | 관문을 지나 굴뚝 지대, 지평선의 오븐 불빛 | hearth(아군 기지 옆), ice_gate(중경), chimney(중경), chimney(중경), oven_glow(능선) | 있음 |
| R29 | 굴뚝 숲, 오븐 불빛이 커짐 | hearth(아군 기지 옆), chimney(중경), chimney(중경), oven_glow(능선), snow_fence(길가) | 있음 |
| R30 | 적 기지 뒤 오븐 심장, 하늘 아래가 달아오름 | hearth(아군 기지 옆), chimney(중경), oven_glow(능선), oven_heart(적 기지 뒤) | 있음 |

## R31–R40 둥지 심부

| 라운드 | 이 라운드에서 달라지는 것 | 랜드마크 (위치) | 캡처 |
|---|---|---|---|
| R31 | 균사 통로 입구: 갈빗대 둘 | camp(아군 기지 옆), rib(중경), rib(중경), strands(능선) | 있음 |
| R32 | 갈빗대 셋, 통로가 좁아짐 | camp(아군 기지 옆), rib(중경), rib(중경), rib(중경), strands(능선) | 있음 |
| R33 | 첫 균사 기둥 | camp(아군 기지 옆), rib(중경), pillar(중경), strands(능선) | 있음 |
| R34 | 기둥·갈빗대·첫 포자낭 | camp(아군 기지 옆), pillar(중경), rib(중경), sac(중경), strands(능선) | 있음 |
| R35 | 기둥 사이 포자낭, 적 기지 뒤 매듭 벽 | camp(아군 기지 옆), pillar(중경), pillar(중경), sac(중경), knot_wall(적 기지 뒤), strands(능선) | 있음 |
| R36 | 포자실: 포자낭 셋, 벽의 숨구멍 | camp(아군 기지 옆), sac(중경), sac(중경), sac(중경), pores(능선) | 있음 |
| R37 | 포자실 깊은 곳: 큰 포자낭과 기둥 | camp(아군 기지 옆), sac(중경), pillar(중경), sac(중경), pores(능선) | 있음 |
| R38 | 굴 입구(잠입병의 길)와 포자낭 | camp(아군 기지 옆), sac(중경), tunnel_mouth(중경), sac(중경), pores(능선) | 있음 |
| R39 | 핵실 앞: 기둥 둘, 굴, 멀리 핵의 빛 | camp(아군 기지 옆), pillar(중경), pillar(중경), core_light(능선), tunnel_mouth(중경), pores(능선) | 있음 |
| R40 | 핵실: 핵으로 모이는 갈빗대와 맥동하는 균사 | camp(아군 기지 옆), pillar(중경), core_ribs(중경), core_light(능선), core_chamber(적 기지 뒤) | 있음 |
