# 챕터별 적 둥지 (ChatGPT 이미지 생성용)

지금은 1–100라운드 내내 같은 초록 둥지가 나와서 챕터가 바뀐 느낌이 없다. 챕터마다 그 배경에 맞는 둥지를 그린다. 형식은 지금 둥지와 같다: 96×128 그림 6장(평상시 2, 손상 2, 파괴 2).

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_current_nest_every_chapter.png` | 지금 게임: 모든 챕터에 같은 둥지 |
| `2_current_base_states.png` | 지금 둥지(위)와 우리 성(아래)의 평상시·손상·파괴 상태. 크기와 화풍 기준 |
| `3_chapter_backgrounds.png` | 챕터 10개의 배경. 둥지가 각 배경에 어울려야 한다 |
| `4_sheet_layout.png` | 시트 형식: 자홍 배경, 4칸 × 2줄, 칸마다 96×128 도트를 4배로 |

## 진행 방법

1. 새 대화에 이미지 4장을 첨부하고 **① 공통 지시**를 보낸다.
2. 챕터마다 **②** 한 줄을 보낸다. 챕터 하나에 시트 한 장이 나온다.
3. 결과를 `nest_01.png` … `nest_10.png`로 저장해서 넘겨준다(챕터 번호 = R01–10이 01).
4. 받은 시트는 칸마다 잘라 4배 축소하고, 색을 정리해서 챕터별 둥지로 넣는다.

10장을 한 대화에서 다 만들면 화풍이 흐려진다. 3–4장마다 새 대화에서 ①부터 다시 한다. 챕터 수를 줄이고 싶으면 5종만 만들어도 된다(01–02 / 03·05·07·09 / 04·08 / 06 / 10).

---

## ① 공통 지시

```text
I'm making the enemy base for a cute pixel-art lane-defence game: bread knights attack a mould nest at the right end of the road. I attached 4 images:
1_current_nest_every_chapter: today the same green nest appears in all 100 rounds. I want one nest per chapter.
2_current_base_states: the current nest (top) and our bakery keep (bottom) in their idle, damaged and ruined states. Match this pixel style, size and outline exactly.
3_chapter_backgrounds: the 10 chapter backgrounds; each new nest must belong to its chapter.
4_sheet_layout: the sheet format.

Rules for every sheet:
- Canvas 1536x1024, flat pure magenta #FF00FF background.
- 4 columns x 2 rows of 384x512 cells. Use cells 1-6 only: 1 idle A, 2 idle B (slight pulse or glow change, same shape), 3 damaged A, 4 damaged B, 5 ruined A, 6 ruined B. Cells 7-8 stay empty magenta.
- The same nest in every cell: same position, same base width; it stands on the bottom edge of the cell. Damaged = cracks, broken spikes, oozing; ruined = collapsed half-height wreck with smoke.
- Drawn on a 96x128 pixel grid at 4x (every art pixel a 4x4 block). The nest's door/mouth faces LEFT (toward our army).
- True pixel art: no anti-aliasing, no blur, at most 32 colours, 1-pixel own-hue dark outline, light from the upper left.
- Cute-creepy, not horror: rounded mould shapes, glowing spores, a dark door with two small glowing eyes.
- No characters, no ground, no text, no grid lines.

Reply "ready" and wait.
```

## ② 챕터별 한 줄

```text
Nest 01 (R1-10, wheat meadow): the classic green mould nest growing over a half-eaten haystack and a broken wheat cart, small yellow mushrooms.
```
```text
Nest 02 (R11-20, autumn orchard): mould swallowing a rotten apple tree stump and cider barrels, orange-brown leaves stuck in the slime, red rotten apples.
```
```text
Nest 03 (R21-30, frozen mill pass): mould frozen into blue-white ice, icicles hanging from it, a snow cap on top, cold teal spore glow.
```
```text
Nest 04 (R31-40, mould cavern): a cave nest built into a rock arch, roots holding it together, violet and teal spore sacs hanging from it.
```
```text
Nest 05 (R41-50, snowy slate quarry): mould growing over stacked slate blocks and a broken wooden hoist, snow on the stones.
```
```text
Nest 06 (R51-60, mushroom marsh): a swampy nest standing in shallow water on a mossy rock, giant pale mushrooms, reeds, bubbling green pools.
```
```text
Nest 07 (R61-70, ruined frozen fort): mould inside a broken stone tower ruin with a torn blue banner, ice on the stones.
```
```text
Nest 08 (R71-80, root hall): a nest woven from huge brown roots with glowing amber crystals, moss on top.
```
```text
Nest 09 (R81-90, aurora glacier): a crystal-ice mould nest with aurora green and pink glints on its ice shell.
```
```text
Nest 10 (R91-100, mould heart): the final nest: a big violet-teal mould citadel with crystal spires and a pulsing heart window, the most imposing of all (still 96x128).
```

## 결과가 어긋날 때 보낼 한 줄 수정

- 칸마다 모양이 다르다: `Same nest, same position and width in every cell; only damage changes.`
- 너무 무섭다: `Make it cute-creepy like the reference, rounded shapes, not horror.`
- 그림처럼 부드럽다: `Real pixel art only: square 4x4 blocks, flat colours, 1-pixel outline.`
- 문이 오른쪽을 본다: `The door must face LEFT.`
