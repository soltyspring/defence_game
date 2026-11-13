# 신규 유닛 5종 재작화 (ChatGPT 이미지 생성용)

대상: 바게트, 마카롱, 고추빵, 도넛, 와플. 100라운드 편성에서 R8·11·14·17·20에 해금되는 아군 유닛이다.

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_style_reference.png` | 맞출 화풍: 지금 게임의 아군 유닛(영웅, 식빵병, 롤빵병, 통식빵, 프레첼, 화덕포)의 대기·걷기·공격 프레임 |
| `2_in_game_scale.png` | 실제 게임 화면에서 유닛이 보이는 크기 |
| `3_sheet_layout.png` | 한 장에 그릴 8가지 동작 칸 배치. 자홍색 배경, 32px 몸통을 8배로 그린 크기 |
| `4_current_units.png` | 지금의 임시 그림. 역할만 참고하고 모양은 모두 새로 만든다 |

## 진행 방법

1. 새 대화를 열고 이미지 4장을 첨부한 뒤 **① 공통 지시**를 보낸다.
2. 유닛마다 **② 유닛 프롬프트**를 하나씩 보낸다. 유닛 하나에 이미지 한 장(8동작 시트)이 나온다.
3. 결과를 `baguette.png`, `macaron.png`, `chili.png`, `donut.png`, `waffle.png`로 저장해서 넘겨준다.
4. 받은 시트는 이렇게 정리해서 게임 아틀라스에 넣는다.
   - 칸마다 잘라 8배 축소하고, 도트 격자와 색 수를 정리한다.
   - 대기 숨쉬기, 걷기 4프레임, 공격 4프레임(타격 프레임 2), 쓰러짐을 만든다.

한 대화에서 유닛이 3개를 넘으면 화풍이 흐려진다. 3개째 뒤에는 새 대화에서 ①부터 다시 한다.

---

## ① 공통 지시 (이미지 4장 첨부와 함께, 맨 처음 한 번)

```text
I'm making new ally units for a cute pixel-art lane-defence game where small bread and pastry knights fight mould monsters. I attached 4 reference images:

1_style_reference: the existing ally units. Match this style exactly: chunky cute pastry bodies, big readable silhouettes, 2 small black eyes with a white highlight, small pink blush, short dark-brown legs, a 1-pixel darker outline in the part's own hue (never pure black), 4-5 tone shading with light from the upper left.
2_in_game_scale: how small the units really are in the game (about 32 pixels tall). Every shape must still read at that size.
3_sheet_layout: the sheet format to use for every unit (8 poses in a 4x2 grid on flat magenta).
4_current_units: the old placeholder art. Keep only the role ideas; design everything else fresh.

Rules for every sheet I ask for:
- Canvas 1536x1024, background flat pure magenta #FF00FF everywhere, no gradient, no texture.
- 4 columns x 2 rows of equal cells (384x512). One pose per cell, in this order:
  1 idle, 2 walk A (front foot forward), 3 walk B (feet passing), 4 walk C (back foot forward),
  5 attack wind-up, 6 attack hit (strongest moment, with a small effect), 7 attack follow-through, 8 defeated (lying on the ground, eyes as X).
- The SAME character in every cell: same size, same colours, same proportions, same equipment. Only the pose changes.
- True pixel art: the character is drawn on a 32x32 pixel grid (up to 48x40 if the unit carries big equipment) and every pixel is a perfectly square 8x8 block. No anti-aliasing, no blur, no gradients, no soft painting, no dithering noise, at most 24 colours.
- Feet stand on the same invisible ground line in every cell (about 64 px above the cell bottom), side view, character faces RIGHT.
- No grid lines, no cell borders, no numbers, no text, no ground, no cast shadow, no background objects.

Reply "ready" and wait for the unit prompts.
```

## ② 유닛 프롬프트 (하나씩)

### 바게트 — 장창, 근접 선제 타격 (R8 해금)
```text
Unit: BAGUETTE PIKEMAN. A tall slim baguette standing upright as the body (golden crust, three diagonal score marks, pale cream cuts), a small round iron cap with a short red plume, cute determined face. Holds a long wooden pike with a steel tip, held level and pointing forward to the right, reaching well beyond the body (the pike makes the sprite about 44 px wide). Body about 30 px tall.
Attack: 5 pulls the pike back, 6 thrusts it far forward with a small white spark at the tip, 7 recovers.
```

### 마카롱 — 저격, 강한 단일 공격 (R11 해금)
```text
Unit: MACARON SHARPSHOOTER. A round macaron as the body: two lavender-pink shells with a cream filling stripe around the middle like a belt, tiny legs, a small navy beret, one eye narrowed for aiming. Carries a long slim crossbow made of a wooden rolling-pin stock and a steel bow, pointing right. Body about 24 px tall, smaller than the other units.
Attack: 5 aims steadily (crossbow raised to the eye), 6 fires with a small recoil and a short bright streak leaving the bow, 7 lowers the crossbow.
```

### 고추빵 — 화염, 밀집 적 광역 공격 (R14 해금)
```text
Unit: CHILI BREAD FLAMER. A plump red chili-pepper-shaped bun as the body (glossy red with a darker red crust and a green stem cap on top like a hat), fierce little eyebrows but still cute. Holds a small copper bellows with a brass nozzle pointing right. Body about 30 px tall.
Attack: 5 squeezes the bellows, 6 blows a short wide cone of orange-yellow flame to the right (about 16 px long, chunky pixel flames), 7 the flame fades into a puff of grey smoke.
```

### 도넛 — 수호, 중장갑 전선 유지 (R17 해금)
```text
Unit: DONUT GUARDIAN. A thick round ring donut as the body (golden dough, pink icing on the top half with a few colourful sprinkles), a small steel helmet, sturdy short legs, calm brave face. Holds a big round iron frying-pan shield in front, covering the lower right of the body, the handle pointing back. Body about 30 px tall and wide, the heaviest-looking ally.
Attack: 5 braces behind the shield, 6 bashes forward with the shield and a small white impact star, 7 steps back into guard.
```

### 와플 — 공성, 기지 파괴 특화 (R20 해금)
```text
Unit: WAFFLE SIEGE CREW. A square golden waffle with a grid pattern as the body, a small brown leather cap, operating a small wooden catapult next to it on the right side. The catapult throws a hard brown caramel boulder. The waffle plus catapult together are about 46 px wide and 36 px tall.
Walk: the waffle pushes the catapult (small wheels). Attack: 5 the catapult arm is pulled down with the caramel boulder loaded, 6 the arm swings up and the boulder leaves to the upper right, 7 the arm settles.
```

## 결과가 어긋날 때 보낼 한 줄 수정

- 칸마다 캐릭터가 다르다: `Keep the exact same character in all 8 cells; copy cell 1 and only change the pose.`
- 그림처럼 부드럽다: `Make it real pixel art: square 8x8 blocks, flat colours, no soft shading or anti-aliasing.`
- 너무 크거나 작다: `The body must be about 32 pixels tall on the 8x8-block grid, like the bread-slice soldier in 3_sheet_layout.`
- 왼쪽을 본다: `The character must face right in every cell.`
- 배경이나 바닥이 생겼다: `Flat magenta background only, no ground, no shadow, no text.`
- 너무 멋있고 귀엽지 않다: `Make it cuter and chunkier like 1_style_reference: bigger head-body, simple shapes, small dot eyes with highlights.`
