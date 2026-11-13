# 길가 소품 (ChatGPT 이미지 생성용)

길 바로 위 근경 소품(덤불, 바위, 눈더미, 버섯, 수정 등)이 지금은 코드로 그린 반원과 막대라서, 버섯이 표지판이나 탁자처럼 보인다. 테마 5개에 소품 8개씩 도트로 그린다.

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_current_props.png` | 지금 소품(길 위 띠만 확대). 바꿀 대상 |
| `2_ingame_context.png` | 실제 게임 화면. 소품이 놓일 자리와 배경 |
| `3_unit_scale.png` | 유닛 크기: 병사 32px. 소품은 이보다 낮아야 한다 |
| `4_sheet_layout.png` | 시트 형식: 자홍 배경, 4칸 × 2줄, 칸마다 48×64 도트를 8배로. 안쪽 상자 = 최대 40×24 |

## 진행 방법

1. 새 대화에 이미지 4장을 첨부하고 **① 공통 지시**를 보낸다.
2. 테마마다 **②** 한 줄을 보낸다. 테마 하나에 시트 한 장이 나온다.
3. 결과를 `props_farm.png`, `props_snow.png`, `props_cave.png`, `props_marsh.png`, `props_heart.png`로 저장해서 넘겨준다.
4. 받은 시트는 칸마다 잘라 8배 축소하고, 색을 정리해서 챕터별 길가 소품으로 넣는다.

테마와 챕터 연결: farm = R1–20, snow = R21–30·41–50·61–70·81–90, cave = R31–40·71–80, marsh = R51–60, heart = R91–100.

---

## ① 공통 지시

```text
I'm making small roadside props for a cute pixel-art lane-defence game. They stand on the strip of ground right behind the road, in front of the painted background, behind the units. I attached 4 images:
1_current_props: the current props (code-drawn half-circles and sticks); a mushroom reads as a signpost. Replace them.
2_ingame_context: the real game screen showing where the props sit.
3_unit_scale: the units (soldier 32 px tall). Props must stay LOW: at most 24 px tall and 40 px wide.
4_sheet_layout: the sheet format.

Rules for every sheet:
- Canvas 1536x1024, flat pure magenta #FF00FF background.
- 4 columns x 2 rows of 384x512 cells, one different prop per cell (8 props), each standing on the bottom line of its cell, inside the inner box.
- Drawn on a 48x64 pixel grid at 8x (every art pixel an 8x8 block).
- True pixel art: no anti-aliasing, no blur, at most 16 colours per sheet, 1-pixel own-hue dark outline, light from the upper left, a 1-2 px dark contact shadow at the base.
- Low, readable, cute shapes; not too detailed. No characters, no ground strip, no text, no grid lines.

Reply "ready" and wait.
```

## ② 테마별 한 줄

```text
Sheet FARM (wheat meadow and autumn orchard): a round green bush, an autumn orange bush, a grass tuft with two daisies, a small grey rock, a wheat sheaf, a fallen red apple with a leaf, a short wooden fence piece, a tiny flour sack.
```
```text
Sheet SNOW (frozen mill, quarry, fort, glacier): a soft snow mound, a snow-capped rock, a frosted grass tuft, an ice shard cluster, a small snowy pine sapling, a cut slate block with snow, a broken stone wall piece with snow, a frozen puddle crust.
```
```text
Sheet CAVE (mould cavern and root hall): a pale cave mushroom pair (clearly a mushroom: round cap, short stem, gills), a mossy rock, a root knot coming out of the ground, a small amber crystal, a violet glowing spore sac on a stalk, a fern tuft, a flat stone with moss, a cluster of tiny teal glowing mushrooms.
```
```text
Sheet MARSH (mushroom marsh): a reed clump with cattails, a lily pad on a puddle, a mossy log end, a big pale marsh mushroom (round cap, clearly a mushroom), a green bubble pool, a mossy rock, a fern, a cluster of white swamp flowers.
```
```text
Sheet HEART (final mould chamber): a violet crystal cluster, a glowing teal mushroom pair, a pulsing mould blob, a cracked purple rock, a spore sac on a stalk, a curled mould tendril stub, a small heap of crystal shards, a glowing fungus shelf on a stone.
```

## 결과가 어긋날 때 보낼 한 줄 수정

- 너무 크다: `Keep every prop under 24 px tall and 40 px wide on the 8x grid.`
- 버섯이 버섯처럼 안 보인다: `Make mushrooms obvious: round domed cap, gills under the cap, short stem.`
- 그림처럼 부드럽다: `Real pixel art only: square 8x8 blocks, flat colours, 1-pixel outline.`
- 칸을 넘었다: `One prop per cell, standing on the cell's bottom line, inside the inner box.`
