# 스킬 효과 재작화 (ChatGPT 이미지 생성용)

새 스킬 4종(밀가루 보급·설탕 결계·얼음 크림·오븐 열기)의 효과가 코드로 그린 사각형과 선이라 싸 보인다. 프레임 애니메이션 도트 효과로 바꾼다. 기존 스킬 3종(내려찍기·함성·포격)도 선이 가늘고 흐려서 같은 방식으로 다시 그린다(선택).

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_current_effects.png` | 지금 게임 화면의 새 스킬 효과. 바꿀 대상 |
| `2_existing_fx_too_thin.png` | 지금 게임의 다른 효과. 도트 화풍은 맞지만 너무 가늘고 흐리다 |
| `3_unit_scale.png` | 효과가 붙을 유닛 크기: 영웅 48px, 병사 32px (4배로 보여 줌) |
| `4_sheet_layout.png` | 시트 형식: 자홍 배경, 6칸 × 2줄, 칸마다 64×128 도트를 4배로 그린 크기 |

## 진행 방법

1. 새 대화에 이미지 4장을 첨부하고 **① 공통 지시**를 보낸다.
2. 효과마다 **②** 프롬프트를 하나씩 보낸다. 효과 하나에 시트 한 장이 나온다.
3. 결과를 `flour.png`, `shield.png`, `frost.png`, `oven.png`(선택: `slam.png`, `rally.png`, `barrage.png`)로 저장해서 넘겨준다.
4. 받은 시트는 칸마다 잘라서 4배 축소하고, 색을 정리해서 효과 아틀라스로 만든다. 게임은 같은 이름의 효과를 자동으로 그림 애니메이션으로 바꿔 그린다.

한 대화에서 3장을 넘기면 화풍이 흐려진다. 3장마다 새 대화에서 ①부터 다시 한다.

---

## ① 공통 지시 (이미지 4장 첨부와 함께, 맨 처음 한 번)

```text
I'm making skill effects for a cute pixel-art lane-defence game where bread knights fight mould monsters. I attached 4 images:
1_current_effects: the current effects in the game. They look cheap (plain rectangles and lines); replace them.
2_existing_fx_too_thin: other effects in the game. Keep this pixel style but make the new effects much bolder, chunkier and brighter: thick pixel shapes, 2-3 tone shading, a light rim, readable at small size.
3_unit_scale: the characters the effects play around (hero 48 px, soldier 32 px tall).
4_sheet_layout: the sheet format for every effect.

Rules for every sheet:
- Canvas 1536x1024, flat pure magenta #FF00FF background everywhere.
- 6 columns x 2 rows of equal cells (256x512). Frames go left to right, top row first (frame 1-12). If an effect needs only 6 frames, leave the bottom row empty magenta.
- Each cell shows the effect drawn on a 64x128 pixel grid at 4x (every art pixel is a 4x4 block). The ground line is 64 px above the cell bottom; effects that touch the ground sit on it.
- True pixel art: no anti-aliasing, no blur, no soft glow gradients (use 2-3 stepped bands for glow), at most 16 colours per effect, 1-pixel darker outline on solid shapes.
- Effects only: no characters, no ground, no text, no frame numbers, no grid lines.

Reply "ready" and wait.
```

## ② 효과별 프롬프트

### A. 밀가루 보급 (flour.png, 8프레임)
```text
Effect A, FLOUR DROP (8 frames): two small cream flour sacks with a brown tie and a wheat stamp fall from the top of the cell, bounce once on the ground line, and burst into a soft white flour puff with a few golden sparkle pixels. Sacks about 14x16 px each. Frames 1-3 falling, 4 landing squash, 5-6 puff growing, 7-8 puff fading to small sparkles.
```

### B. 설탕 결계 (shield.png, 12프레임: 1줄 = 펼침 6, 2줄 = 유지 반복 6)
```text
Effect B, SUGAR BARRIER (12 frames). Top row (frames 1-6): a pink-white sugar-glass dome rises from the ground line around the cell centre, 56 px wide and 44 px tall when complete, with a sparkling candy rim and a few hexagonal sugar-crystal facets; it pops up with a little overshoot. Bottom row (frames 7-12): the finished dome as a gentle looping shimmer (a light glint sliding over it), slightly transparent-looking by using lighter tints, no real transparency.
```

### C. 얼음 크림 (frost.png, 8프레임)
```text
Effect C, FROST CREAM (8 frames): a burst of frozen cream on the ground. A swirl of pale blue-white cream splashes onto the ground line, then jagged ice crystals shoot up (up to 40 px tall, 60 px wide), hold for a moment with a cold sparkle, then crack and fall apart into small ice bits. Colours: white, pale cyan, icy blue, dark navy outline.
```

### D. 오븐 열기 (oven.png, 6프레임 반복)
```text
Effect D, OVEN HEAT (6 looping frames): one tall flame tongue rising from the ground line, 20 px wide and up to 40 px tall, like fire from an oven: deep red base, orange body, yellow core, a few ember pixels and a wisp of dark smoke at the tip. Each frame flickers to a different height and lean so the 6 frames loop smoothly. The game repeats this flame side by side along the road.
```

### E. 선택: 밀대 내려찍기 (slam.png, 8프레임)
```text
Effect E, ROLLING-PIN SLAM (8 frames): a heavy ground impact. A bright white-yellow flash at the ground point, a thick dust shockwave ring spreading left and right along the ground (up to 64 px wide), cracked earth chunks and flour dust flying up, then settling. Warm beige, brown and white, chunky shapes.
```

### F. 선택: 갓 구운 함성 (rally.png, 8프레임 반복)
```text
Effect F, FRESH-BAKED RALLY (8 looping frames): a warm golden aura around a hero standing at the centre: rising golden chevrons and bread-crumb sparkles, a pulsing ring of light on the ground, small musical/heart-shaped bread icons floating up. Loops smoothly. Warm gold, orange, cream.
```

### G. 선택: 빵가루 포격 (barrage.png, 8프레임)
```text
Effect G, BREADCRUMB BARRAGE IMPACT (8 frames): a round golden crust shell lands from the upper left, hits the ground line and explodes into a chunky crumb explosion: orange-yellow burst, flying brown crust chunks, a ring of crumbs, then smoke puffs fading. Up to 64 px wide, 64 px tall.
```

## 결과가 어긋날 때 보낼 한 줄 수정

- 너무 가늘다: `Make it bolder: thicker pixel shapes, fewer thin lines, stronger contrast.`
- 부드럽게 번졌다: `Real pixel art only: square 4x4 blocks, no soft glow, use 2-3 flat bands for glow.`
- 칸마다 크기가 다르다: `Keep the same size and ground position in every cell; only the animation changes.`
- 배경이나 캐릭터가 들어갔다: `Effect only on flat magenta: no characters, no ground, no text.`
