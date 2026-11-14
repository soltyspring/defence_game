# 화덕포 재디자인 (ChatGPT 이미지 생성용)

지금 화덕포는 갈색 빵 덩이에 회색 포신이 꽂힌 모양이라 '화덕'으로도 '대포'로도 잘 읽히지 않는다(2026-11-15 사용자: 그림 자체가 별로). 먼저 **디자인 후보 4개**를 한 장으로 받아 고르고, 고른 하나로 게임용 시트를 받는다.

역할(바꾸지 않음): 아군 공성 유닛. 비싸고(밀가루 120) 느리며(속도 22) 멀리서(사거리 150) 3초마다 무거운 덩이를 포물선으로 쏴서 기지에 3배, 뭉친 적에 범위 피해를 준다. 이름은 '화덕포'(화덕 + 대포).

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_style_reference.png` | 지금 게임의 아군들(게임이 실제로 쓰는 그림). 이 화풍·크기감·외곽선에 맞춘다 |
| `2_current_oven.png` | 지금 화덕포(대기·걷기·공격·쓰러짐). 바꿀 대상 |
| `3_in_game.png` | 실제 전투 화면 크기(맨 오른쪽 뒤의 갈색 수레가 지금 화덕포) |
| `4_layout_candidates.png` | 후보 시트 배치: 2×2칸, 칸마다 왼쪽 = 대기, 오른쪽 = 발사 순간 |

## 진행 방법

1. 새 대화에 이미지 4장을 첨부하고 **① 후보 프롬프트**를 보낸다.
2. 결과를 `siege_candidates.png`로 넘겨주면 게임 크기로 줄여 다른 아군 옆에 세운 비교를 만들어 드린다. 그걸 보고 하나를 고른다(섞어도 된다: "A의 몸통 + C의 포신").
3. 고른 후보로 **② 게임용 시트 프롬프트**(8동작)와 **③ 환호 프롬프트**(4동작)를 같은 대화에서 보낸다.
4. 받은 시트는 신규 유닛 시트처럼 잘라 화덕포 아틀라스로 바꾸고, 카드 초상과 환호도 함께 바꾼다.

## 결과가 어긋날 때 한 줄 수정

| 증상 | 보낼 문장 |
| --- | --- |
| 후보끼리 너무 비슷함 | `Make the four candidates clearly different in silhouette: different body shape, different barrel, different wheels or legs.` |
| 다른 아군보다 너무 큼/작음 | `Size it like the waffle unit in 1_style_reference: about 48 pixels wide and 40 pixels tall including the barrel.` |
| 무섭거나 진짜 무기 같음 | `Keep it cute and toy-like: rounded shapes, a friendly face, warm bakery colours.` |
| 흐릿하거나 그라데이션 | `True pixel art: hard square 8x8 blocks, no anti-aliasing, at most 24 colours.` |
| 분홍·보라가 들어감 | `No pink, purple or magenta anywhere (the background is keyed out).` |

---

## ① 후보 프롬프트 (이미지 4장 첨부)

```text
I want to redesign one ally unit of a cute pixel-art lane-defence game (bread and pastry knights vs mould monsters). I attached 4 images:

1_style_reference: the ally units as they look in the game now. Match this style exactly: chunky cute bakery shapes, small black eyes with a white highlight, pink blush, a 1-pixel darker outline in each part's own hue, 4-5 tone shading with light from the upper left.
2_current_oven: the unit I am replacing, the OVEN CANNON. It reads as a brown lump with a grey pipe; neither "oven" nor "cannon" comes across. Keep only its role.
3_in_game: how small units really are on screen. Every design must read at about 48x40 pixels.
4_layout_candidates: draw 4 different candidates in a 2x2 grid; in each cell the LEFT half is the idle pose and the RIGHT half is the firing moment.

The unit: a slow, expensive SIEGE gun for the bakery army. Every 3 seconds it lobs a heavy baked boulder (a hard round bread loaf) in a high arc that smashes enemy bases and groups. It must read instantly as "a bakery oven that is also a cannon".

Candidates (make them clearly different silhouettes):
A. BRICK DOME OVEN on a wooden cart: a round brick pizza-oven dome with a glowing arched mouth that IS the cannon mouth, a little chimney puffing, two wooden wheels, a cute face on the dome.
B. CAST-IRON STOVE MORTAR: a squat black-iron baking stove on four short stubby legs, a wide short mortar barrel pointing up at 45 degrees, a round oven door with a warm glow and a small face, a bread-loaf ammo basket on the back.
C. OVEN CREATURE: a living little oven with tiny feet that waddles; its oven door is the mouth and it spits the bread boulder; big cute eyes above the door, a chef-hat-shaped chimney.
D. BREAD CANNON CREW: a long baguette-shaped barrel on a wooden gun carriage with big wheels, a toast-slice gunner (like the toast soldier in 1_style_reference) beside it holding a lit taper, a stack of round bread cannonballs.

Firing pose: show the moment of the shot with a small puff of flour smoke and the bread boulder just leaving the muzzle.

Rules:
- Canvas 1536x1024, background flat pure magenta #FF00FF everywhere, no gradient, no texture.
- True pixel art: every pixel a perfectly square 8x8 block (each candidate about 48x40 game pixels including its barrel), no anti-aliasing, no blur, no soft gradients, no dithering noise, at most 24 colours per candidate.
- Side view, facing RIGHT, feet or wheels on the white ground line.
- Never use pink, purple or magenta except the small blush on faces.
- No text, no letters A-D, no cell borders, no ground drawing, no cast shadow, no background objects.
```

## ② 게임용 시트 프롬프트 (후보를 고른 뒤, 같은 대화)

```text
Great. Use candidate ___ (write any changes here). Now draw the final in-game sheet for it.
Canvas 1536x1024, flat #FF00FF, 4 columns x 2 rows of equal cells (384x512), one pose per cell, in this order:
  1 idle, 2 walk A, 3 walk B, 4 walk C (it rolls or waddles forward; wheels turn or feet step),
  5 attack wind-up (barrel lifts, the mouth glows brighter), 6 attack shot (flour smoke puff, the bread boulder leaving the muzzle), 7 recoil and settle (a small puff of smoke), 8 defeated (tipped over, cracked, the glow out, eyes as X).
The SAME unit in every cell: same size, colours and proportions. About 48x40 game pixels including the barrel, each pixel an 8x8 block, at most 24 colours, facing RIGHT, wheels or feet on the same ground line about 64 px above each cell bottom. No grid lines, no text, no ground, no shadow.
```

## ③ 환호 프롬프트 (같은 대화)

```text
Now a victory CHEER for the same unit, 4 poses on one row of a 1536x1024 magenta canvas (cells 384x512, row 1 only, leave row 2 empty):
  1 anticipation (squash down a little, happy eyes), 2 jump (wheels or feet off the ground, the barrel raised high), 3 peak (fires a harmless puff of white flour confetti straight up), 4 landing (big ^ ^ smile).
Same unit, size, colours and rules as the sheet above; a white ground line in each cell like before.
```
