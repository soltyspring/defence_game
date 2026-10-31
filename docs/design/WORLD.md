# 세계관 — 빵집 기사단 vs 곰팡이 군단 (Theme A, DECIDED by user 2026-10-31)
Owner: 01-director. Data IDs stay theme-neutral (D1). Only names, art and sound change.

## 한 쪽 세계관
밀밭 한가운데 있는 작은 빵집 마을에는 매일 새벽 화덕에 불을 지피는 빵집 기사단이 있다. 기사단은 사람이 아니라 갓 구운 빵들이다. 식빵 기사는 바삭한 귀를 갑옷 삼아 앞장서고, 롤빵 투척병은 따끈한 롤빵을 던지며, 통식빵 방패병은 몸통 하나로 길을 막는다. 이들을 이끄는 사람은 밀대를 든 제빵 대장이다. 꼬마 제빵사들은 뒤에서 쉬지 않고 반죽을 빚는다. 반죽이 곧 병사가 되기 때문이다.

어느 비 오는 여름, 마을 끝의 낡은 창고에서 곰팡이가 피어올랐다. 습기를 먹고 자란 곰팡이 군단은 초파리 떼와 썩은 멧돼지를 앞세워 빵집으로 밀려온다. 군단은 포자를 뱉어 빵을 상하게 하고, 부푼 효모를 굴려 보내 터뜨린다. 그 뒤에는 곰팡이 장군이 있고, 창고 깊은 곳의 둥지에는 모든 것을 썩게 하려는 부패 대군주가 잠들어 있다.

기사단의 목표는 단순하다. 빵집을 지키고, 곰팡이 둥지(적 기지)를 부숴 마을을 다시 보송하게 만드는 것이다.

톤: 귀엽고 유머러스하지만 위협은 분명하다. 아군은 따뜻한 갈색·크림·노랑, 적은 탁한 초록·보라·회색이다(피아 식별은 색상과 밝기 둘 다로 구분, D14). 피·잔혹 표현은 없다. 쓰러진 빵은 부스러기로, 곰팡이는 포자 먼지로 흩어진다.

## 이름표 (data/text/ko.json, en.json에 반영)
카드 이름은 가장 좁은 카드 칸(36.67 px, Galmuri11 12 px)에 맞췄다. 긴 이름은 설명(desc)에 적는다.
| ID | 역할 | 카드/표시 이름 ko | en | 정식 이름 ko / en | 12 px 폭 ko / en |
|---|---|---|---|---|---|
| worker | 일꾼 | 제빵사 | Baker | 꼬마 제빵사 / Little Baker | 36 / 36 |
| melee_basic | 기본 근접 | 식빵병 | Toast | 식빵 기사 / Toast Knight | 36 / 36 |
| ranged_basic | 원거리 | 롤빵병 | Roll | 롤빵 투척병 / Roll Thrower | 36 / 24 |
| tank | 방패 | 통식빵 | Loaf | 통식빵 방패병 / Loaf Shield | 36 / 28 |
| fast | 돌격 | 프레첼 | Twist | 프레첼 돌격병 / Pretzel Rider | 36 / 35 |
| siege | 공성 | 화덕포 | Oven | 화덕 대포 / Oven Cannon | 36 / 32 |
| hero_captain | 영웅 | 제빵 대장 | Head Baker | 같음 | (카드 아님) |
| e_grunt | 기본 적 | 곰팡이 졸개 | Mold Mite | | |
| e_swarm | 떼 | 초파리 떼 | Fruit Flies | | |
| e_spitter | 원거리 적 | 포자 뱉개 | Spore Spitter | | |
| e_brute | 거한 | 썩은 멧돼지 | Rot Boar | | |
| e_bomber | 자폭 | 부푼 효모 | Yeast Puff | | |
| boss_warlord | 보스(r05) | 곰팡이 장군 | Mold General | | |
| boss_overlord | 보스(r10) | 부패 대군주 | Rot Overlord | | |
| biome_01 | 바이옴 | 밀밭 빵집 마을 | Wheatfield Village | | |
| skill_slam | 스킬 | 밀대 내려찍기 | Slam | | |
| skill_rally | 스킬 | 갓 구운 함성 | Rally | | |
| skill_barrage | 스킬 | 빵가루 포격 | Barrage | | |
| 자원 supply | 인게임 자원 | 반죽 | Dough | | |
| 자원 energy | 영웅 자원 | 기력 | Energy | | |
| 플레이어 기지 / 적 기지 | | 빵집 / 곰팡이 둥지 | Bakery / Mold Nest | | |
Unchanged: currency 골드/Gold (D12). ui.title stays a provisional working title. The final title is a separate decision; 09/10 are checking name collisions.

## Art/sound direction for 03/05 (requests sent)
- Silhouettes: 식빵 (square, toasted ears), 롤빵 (round), 통식빵 (tall block), 프레첼 (knot shape on a running mount), 화덕 (dome with chimney). Hero: chef hat plus rolling pin.
- Enemies: blobby fuzzy mold, small buzzing flies, a spore pod head, a hunched rotten boar, a swelling yeast ball, a mold general with a fuzzy cape, an overlord as a nest/hive of rot.
- Sound: warm wood and oven sounds and soft crunches for allies; squelch, fizz and buzz for enemies.
