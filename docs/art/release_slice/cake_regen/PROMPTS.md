# 케이크 크림병 재작화 (ChatGPT 이미지 생성용)

대상: 지금의 고추빵(내부 ID `chili`)을 **케이크**로 바꾼다. 고추 모양이라 빵으로 보이지 않았다. 역할(화염, 뭉친 적 광역 공격, R14 해금)과 동작 구성은 그대로다.

디자인: 둥근 2단 케이크 몸통 위에 불 켜진 초 3개. 손에는 제과용 토치(크렘 브륄레 굽는 가스 토치)를 들고 불꽃을 쏜다.

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_style_reference.png` | 맞출 화풍: 지금 게임의 아군 유닛들 |
| `2_in_game_scale.png` | 실제 게임 화면에서 유닛이 보이는 크기 |
| `3_sheet_layout.png` | 8동작 칸 배치. 자홍색 배경, 32px 몸통을 8배로 그린 크기 |
| `4_current_chili.png` | 바꿀 대상(고추빵). 동작 구성과 크기만 참고하고 모양은 버린다 |
| `5_finished_sibling.png` | 같은 묶음으로 이미 들어간 도넛 시트. 선 굵기·칸 안 위치·크기를 여기에 맞춘다 |
| `6_cake_fire_draft.png` | ②로 받은 첫 결과(토치 불꽃). 몸통은 확정, ③에서 공격만 생크림으로 바꾼다 |

## 진행 방법

1. 새 대화를 열고 이미지 5장을 첨부한 뒤 **① 공통 지시**를 보낸다.
2. **② 케이크 프롬프트**를 보낸다. 이미지 한 장(8동작 시트)이 나온다.
3. 결과를 `chili.png`(또는 `.webp`)로 저장해서 넘겨준다. 파일 이름은 내부 ID라 `chili` 그대로 둔다.
4. 받은 시트는 `docs/art/release_slice/unit_regen/source/chili.webp`를 교체하고 `python tools/art/release_slice/roster10_sheets.py`로 아틀라스와 카드 초상을 다시 만든다.

**색 주의:** 배경 자홍색(#FF00FF)을 투명으로 빼므로 케이크에 분홍·보라·자홍색을 쓰면 그 부분이 구멍 난다. 크림은 흰색·아이보리, 장식은 딸기 빨강, 초는 빨강·흰 줄무늬로 한다.

## 결과가 어긋날 때 한 줄 수정

| 증상 | 보낼 문장 |
| --- | --- |
| 분홍 크림이 나옴 | `No pink, purple or magenta anywhere: make the frosting pure white/ivory and the decorations strawberry red.` |
| 칸마다 크기·모양이 다름 | `Redraw so all 8 cells show the identical cake character at the identical size; only the pose changes.` |
| 흐릿하거나 그라데이션 | `Make it true pixel art: hard square 8x8 pixel blocks, no anti-aliasing, no gradients, at most 24 colours.` |
| 토치가 안 보임/총처럼 보임 | `The torch is a small handheld kitchen blowtorch: a short silver gas canister with a brass nozzle on top, held like a pistol.` |
| 케이크가 너무 큼 | `Make the cake body about 28 px tall on the 32 px grid, same size as the donut in 5_finished_sibling.` |

---

## ① 공통 지시 (이미지 5장 첨부와 함께, 맨 처음 한 번)

```text
I'm redrawing one ally unit for a cute pixel-art lane-defence game where small bread and pastry knights fight mould monsters. I attached 5 reference images:

1_style_reference: the existing ally units. Match this style exactly: chunky cute pastry bodies, big readable silhouettes, 2 small black eyes with a white highlight, small pink blush, short dark-brown legs, a 1-pixel darker outline in the part's own hue (never pure black), 4-5 tone shading with light from the upper left.
2_in_game_scale: how small the units really are in the game (about 32 pixels tall). Every shape must still read at that size.
3_sheet_layout: the sheet format (8 poses in a 4x2 grid on flat magenta).
4_current_chili: the unit I am replacing. Keep only its pose list and its size in the cells; throw away its look (it read as a chili pepper, not a pastry).
5_finished_sibling: a finished sheet from the same set. Match its outline weight, its size in the cell and its position in each cell.

Rules for the sheet:
- Canvas 1536x1024, background flat pure magenta #FF00FF everywhere, no gradient, no texture.
- 4 columns x 2 rows of equal cells (384x512). One pose per cell, in this order:
  1 idle, 2 walk A (front foot forward), 3 walk B (feet passing), 4 walk C (back foot forward),
  5 attack wind-up, 6 attack hit (strongest moment, with a small effect), 7 attack follow-through, 8 defeated (lying on the ground, eyes as X).
- The SAME character in every cell: same size, same colours, same proportions, same equipment. Only the pose changes.
- True pixel art: the character is drawn on a 32x32 pixel grid (up to 48x40 with the flame) and every pixel is a perfectly square 8x8 block. No anti-aliasing, no blur, no gradients, no soft painting, no dithering noise, at most 24 colours.
- Never use pink, purple or magenta on the character (the magenta background is keyed out). Blush may be a soft orange-red.
- Feet stand on the same invisible ground line in every cell (about 64 px above the cell bottom), side view, character faces RIGHT.
- No grid lines, no cell borders, no numbers, no text, no ground, no cast shadow, no background objects.

Reply "ready" and wait for the unit prompt.
```

## ③ 생크림으로 바꾸기 (2026-11-14, ② 결과를 받은 같은 대화에서)

②의 결과(`6_cake_fire_draft.png`)는 몸통이 좋아서 그대로 쓴다. 공격만 불꽃 대신 생크림으로 바꾼다. 게임 쪽 투사체와 터지는 효과는 이미 생크림으로 바뀌었고, 설명도 "케이크 크림병"이다.
같은 대화에서 아래를 보낸다. 대화가 끊겼으면 새 대화에 이미지 1–3, 5, 6을 첨부하고 ①을 보낸 뒤 "Redraw 6_cake_fire_draft with these changes:"를 앞에 붙여 보낸다.

```text
Great cake. Keep the body, face, frosting, candles, legs, size and every cell position exactly the same. Change only the weapon and the attack:
- Weapon: a whipped-cream dispenser instead of the blowtorch: the same small silver canister, but with a white star-shaped piping tip on a short nozzle pointing right. No brass torch head.
- Cell 5 (wind-up): squeezes the dispenser lever, a tiny white cream bead at the tip. The candle flames stay normal size.
- Cell 6 (hit): the dispenser shoots a thick wavy burst of fluffy WHITE whipped cream to the right (about 16 px long, chunky pixel cream swirls with ivory shading and a few flying cream drops). No fire, no orange, no yellow in the shot.
- Cell 7 (follow-through): a small cream blob drips from the tip and a couple of cream drops fall; no smoke.
- Cells 1-4 and 8 stay as they are, only with the new dispenser in hand.
Same rules as before: flat #FF00FF background, true 8x8 pixel blocks, no pink, purple or magenta on the character.
```

## ② 케이크 프롬프트

```text
Unit: CAKE FLAMER. A round two-layer celebration cake as the body: golden vanilla sponge sides with one thin cream line between the layers, thick pure-white frosting on top that drips a little down the sides, a few strawberry-red dots around the rim. Three short lit birthday candles stand on top like a crown (red-and-white striped, each with a small orange-yellow flame). Cute determined face on the sponge, tiny brown legs. Body about 28 px tall and 26 px wide, clearly a cake at a glance.
Weapon: a small handheld kitchen blowtorch (short silver gas canister with a brass nozzle), held in front, nozzle pointing right.
Idle and walk: the candle flames flicker slightly between cells.
Attack: 5 raises the torch and the three candle flames flare up taller, 6 the torch blows a short wide cone of chunky orange-yellow pixel flame to the right (about 16 px long), 7 the flame fades into a small puff of grey smoke and the candles settle.
Defeated: the cake tips over on its side, the candles are out with thin smoke wisps, eyes as X.
```
