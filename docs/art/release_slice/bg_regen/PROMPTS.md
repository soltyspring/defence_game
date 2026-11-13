# 후반 배경 6장 재생성 (ChatGPT 이미지 생성용)

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_style_reference.png` | 맞출 화풍: 지금 잘 나온 밀밭·과수원·서리 배경 |
| `2_scale_in_game.png` | 실제 게임 한 화면과 캐릭터 크기 관계 |
| `3_layout_guide.png` | 위·가운데·아래 구역 비율과 물체 크기(병사 32px 기준) |
| `4_what_to_fix.png` | 지금 후반 배경의 문제: 빨강 = 늘린 가장자리, 노랑 = 거미처럼 보이는 형체 |

## 진행 방법

1. 새 대화를 열고 이미지 4장을 첨부한 뒤 **① 공통 지시**를 보낸다.
2. 챕터마다 **A(랜드마크)** 프롬프트로 한 장을 만들고, 이어서 같은 대화에서 **B(이어짐)** 프롬프트로 한 장을 더 만든다.
3. 마음에 드는 A와 B를 챕터 이름으로 저장한다(예: `frost_quarry_A.png`, `frost_quarry_B.png`).
4. 하단은 단색 띠 없이 풍경의 땅이 그림 아래 끝까지 이어지게 한다. 게임은 이 아래 끝 바로 밑에 길을 그린다(Codex 쪽 `TRIM_GROUND_ROWS`와 배경 아래 끝 위치 조정 필요).
5. 저장한 파일을 넘겨주면 A+B를 이어 붙인다. 이어 붙인 결과는 4×4 도트 격자와 32색으로 정리해 1024×176 타일로 만든다. 늘리기는 하지 않는다.

한 대화에서 챕터를 2개 넘게 진행하면 화풍이 흐려진다. 2챕터마다 새 대화를 열고 ①부터 다시 한다.

---

## ① 공통 지시 (이미지 4장 첨부와 함께, 맨 처음 한 번)

```text
I'm making backgrounds for a cute pixel-art lane-defence game whose heroes are small bread and pastry knights. I attached 4 reference images:

1_style_reference: the art style to match exactly (palette simplicity, brightness, outline style, light direction).
2_scale_in_game: how one game screen looks with the characters; the soldier is 32 px tall. Keep this size relation.
3_layout_guide: the layout every background must follow (sky top 40%, landmarks 40-80%, low natural foreground ground in the bottom 20%) and the object sizes.
4_what_to_fix: the previous attempt. The red areas are stretched, empty edges; never do that. The yellow circle reads as a spider; never draw anything like it.

Rules for every image I ask for:
- Wide 3:1 panorama. If your canvas cannot be 3:1, use a 3:2 landscape canvas, put the 3:1 picture as a full-width band in the vertical middle, and fill the area above and below it with flat pure magenta #FF00FF.
- True pixel art: big flat shapes, crisp clusters, no painterly texture, no gradients, no dithering, no blur, about 32 colours, flat 3-5 tone ramps, 1 px own-hue dark outlines on near objects (never black).
- Storybook fantasy tone, friendly and readable, mid-to-light values, gentle saturation like the style reference. Not grim, not horror, no large near-black areas.
- One key light from the upper left: warm lit left faces, cool right faces, short rightward shadows, thin contact shadows.
- Real scenery across the WHOLE width up to both edges (hills, trees, rocks, arches). No empty or smeared bands, no horizontal streaks.
- Bottom 20 %: the scene's own ground simply continues to the bottom edge (low grass, field edge, snow, moss or rock floor in the chapter's colours, low contrast, small simple clusters). NO separate flat colour band, no horizon line there. Nothing taller than 8 px in this zone: no buildings, trees, fences or big rocks. No road or path; the game draws the road under the bottom edge.
- Never: characters, creatures, spiders, legs, claws, eyes, skulls, bones, text, UI, frame, watermark.

Reply "ready" and wait for the scene prompts.
```

## ② 챕터별 프롬프트

B를 요청할 때는 같은 대화에서 A 바로 다음에 보낸다.

### R41–50 frost_quarry (설원 채석장)
```text
A: Snowy slate quarry in bright morning light. Terraced pale-grey stone shelves with big cut blocks, one small timber hoist with a rope and a crate, two little snow-roofed work sheds with warm yellow windows, a few round-topped snowy firs, periwinkle mountains far behind.
```
```text
B: The quiet continuation of the image you just made, same palette, same horizon heights and same ground colour. Low snowy terraces, scattered cut blocks, small firs, distant periwinkle peaks; no buildings. Its LEFT edge must continue your previous image's RIGHT edge, and its RIGHT edge must continue your previous image's LEFT edge (same colours and heights at those borders).
```

### R51–60 spore_marsh (포자 습지)
```text
A: Misty mushroom marsh in soft green daylight. Giant friendly pale mushrooms with cream caps, mossy stone arches, still jade pools reflecting a pale sky, a few softly glowing floating spores.
```
```text
B: The quiet continuation of the image you just made, same palette, same horizon heights and same ground colour. Low mossy banks, small mushroom clusters, reeds, still pools, soft distant arches in haze. Its LEFT edge must continue your previous image's RIGHT edge, and its RIGHT edge must continue your previous image's LEFT edge.
```

### R61–70 frozen_bastion (얼어붙은 요새)
```text
A: A friendly ruined hill fort on snowy ridges on a clear winter afternoon. Two round stone towers with small blue banners, a broken wall, icicles, snowy pines, warm sunlight on the parapets, lavender mountains behind.
```
```text
B: The quiet continuation of the image you just made, same palette, same horizon heights and same ground colour. Rolling snowy ridges, one short low wall fragment, pines, distant lavender mountains. Its LEFT edge must continue your previous image's RIGHT edge, and its RIGHT edge must continue your previous image's LEFT edge.
```

### R71–80 root_vault (뿌리 전당)
```text
A: A huge cosy underground hall of ancient tree roots. The roots form smooth light-brown arches with sage moss, warm amber crystals glow in the roots like lanterns, a soft opening of daylight high on the upper left. Warm and inviting, not dark.
```
```text
B: The quiet continuation of the image you just made, same palette, same horizon heights and same ground colour. Gentle root arches receding into warm haze, a few small glowing crystals. Its LEFT edge must continue your previous image's RIGHT edge, and its RIGHT edge must continue your previous image's LEFT edge.
```

### R81–90 aurora_pass (오로라 빙하)
```text
A: A glacier pass in early evening. Light-blue ice cliffs, snowy firs, distant peaks, a soft green and pink aurora drawn as clean pixel bands, a small round moon at the upper left. The scene stays light and readable.
```
```text
B: The quiet continuation of the image you just made, same palette, same horizon heights and same ground colour. Low ice ridges, small firs, the aurora continuing across the sky. Its LEFT edge must continue your previous image's RIGHT edge, and its RIGHT edge must continue your previous image's LEFT edge.
```

### R91–100 mould_heart (균사 핵실, 마지막 챕터)
```text
A: The great mould chamber, the final stage. Tall smooth arches of rock and mycelium like a cathedral; in the far centre, a large round glowing violet-and-teal crystal bloom resting on a rock pedestal; light mist. Dramatic but colourful and readable. Nothing hangs from the ceiling: no hanging body, no tendrils, no legs.
```
```text
B: The quiet continuation of the image you just made, same palette, same horizon heights and same ground colour. Receding mossy arches, small glowing mushrooms, light mist. Its LEFT edge must continue your previous image's RIGHT edge, and its RIGHT edge must continue your previous image's LEFT edge.
```

## 결과가 어긋날 때 보낼 한 줄 수정

- 어둡다: `Make it brighter and friendlier like 1_style_reference; lift the shadows, no near-black.`
- 가장자리가 비었다: `Fill both edges with real scenery; no empty or smeared bands.`
- 아래쪽에 단색 띠가 생겼다: `No flat colour band at the bottom; let the scene's own low ground continue to the bottom edge.`
- 아래쪽에 큰 물건이 있다: `Keep the bottom 20 % low: only grass, snow or moss, nothing taller than 8 px.`
- 그림처럼 보인다: `Make it real pixel art: bigger flat shapes, fewer colours, no soft painting.`
- 거미나 생물처럼 보인다: `Remove anything that looks like a creature, legs or eyes.`
