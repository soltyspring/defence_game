# 아군 승리 환호 동작 (ChatGPT 이미지 생성용)

적 기지를 부수면 아군이 0.8초 진군한 뒤 제자리에서 환호한다(`06cd36e`). 지금 환호는 대기 그림을 위아래로 튀기는 임시 동작이고, 주인공보다 앞에 있던 유닛은 코드가 좌우를 뒤집어 주인공 쪽을 보게 한다. 아군마다 진짜 환호 4프레임을 받는다.

대상 12종: 제빵장(주인공), 식빵, 롤빵, 통식빵, 프레첼(말 탄 기수), 화덕포(수레), 바게트, 마카롱, 케이크, 도넛, 와플, 견습생.

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_style_reference.png` | 지금 게임 아군의 화풍. 매번 첨부 |
| `2_layout_guide.png` | 시트 배치: 2행 × 4칸(칸 384×512), 1행 = 첫 번째 유닛, 2행 = 두 번째 유닛. 흰 선 = 땅 |
| `ref_1_hero_captain_melee_basic.png` … `ref_6_waffle_worker.png` | 시트마다 그릴 두 유닛의 지금 그림(대기·걷기·공격). 모양·색·크기를 그대로 지킨다 |

## 진행 방법

1. 새 대화를 열고 `1_style_reference.png`, `2_layout_guide.png`를 첨부한 뒤 **① 공통 지시**를 보낸다.
2. 시트마다 해당 `ref_N_...png`를 첨부하고 **② 시트 N 프롬프트**를 보낸다. 시트 하나에 유닛 둘(2행)이 나온다.
3. 결과를 `cheer_1.png` … `cheer_6.png`로 저장해서 넘겨준다.
4. 한 대화에서 시트가 3장을 넘으면 화풍이 흐려진다. 3장째 뒤에는 새 대화에서 ①부터 다시 한다.
5. 받은 시트는 칸마다 잘라 각 유닛 크기로 줄이고, 아틀라스에 `cheer` 동작(4프레임)으로 넣는다. 게임은 진군이 끝나면 1→2→3→4→2→3→4 순서로 재생하고, 주인공 앞 유닛은 좌우를 뒤집어 주인공을 보게 한다.

## 결과가 어긋날 때 한 줄 수정

| 증상 | 보낼 문장 |
| --- | --- |
| 캐릭터 모양·색이 지금 그림과 다름 | `Keep the character exactly as in the ref image (same shape, colours, equipment, size); only the pose changes.` |
| 칸마다 크기가 다름 | `Same size in all 4 cells; the character must not grow or shrink while cheering.` |
| 왼쪽을 봄 | `Every frame faces RIGHT, like the ref image.` |
| 흐릿하거나 그라데이션 | `True pixel art: hard square 8x8 blocks, no anti-aliasing, at most 24 colours.` |
| 효과가 너무 큼 | `Keep the celebration effect small (a few sparkles or crumbs near the head), never covering the character.` |
| 분홍·보라 배경이 캐릭터에 들어감 | `No magenta, pink or purple on the character except where the ref already has it.` |

---

## ① 공통 지시 (1_style_reference, 2_layout_guide 첨부, 맨 처음 한 번)

```text
I'm adding a victory CHEER animation to the ally units of a cute pixel-art lane-defence game (bread and pastry knights vs mould monsters). After the enemy base falls, every ally stops and cheers. I attached 2 images:

1_style_reference: the existing ally units. Keep this exact style: chunky cute pastry bodies, small black eyes with a white highlight, pink blush, a 1-pixel darker outline in each part's own hue, 4-5 tone shading with light from the upper left.
2_layout_guide: the sheet format for every request: 2 rows x 4 cells (each 384x512) on flat magenta. Row 1 = the first unit, row 2 = the second unit. The white line in each cell is the ground.

For each sheet I will attach a ref image showing the two units as they look in the game now (idle / walk / attack). Draw each unit in 4 cheer poses, left to right:
  1 anticipation: a small crouch, body squashed a little, eyes happy, feet on the ground.
  2 jump: up in the air (feet about 8 game pixels above the ground), arms or weapon raised high, mouth open in a cheer.
  3 peak: highest point, biggest pose, a few small sparkles or bread crumbs near the head.
  4 landing: feet back on the ground, body slightly stretched, eyes closed in a big smile (^ ^).

Rules for every sheet:
- Canvas 1536x1024, background flat pure magenta #FF00FF everywhere, no gradient, no texture.
- The SAME character as in the ref image in all 4 cells: same shape, colours, equipment and size. Only the pose changes.
- True pixel art at the ref image's pixel size: every pixel a perfectly square 8x8 block. No anti-aliasing, no blur, no soft gradients, no dithering noise, at most 24 colours.
- Side view, the character faces RIGHT in every cell, centred in its cell, feet on the white ground line except in the jump and peak cells.
- Never use magenta, pink or purple except where the ref already has them (blush, macaron shell).
- No grid lines, no cell borders, no text, no ground drawing, no cast shadow, no background objects.

Reply "ready" and wait for the sheet prompts.
```

## ② 시트별 프롬프트 (해당 ref 이미지를 첨부하고 하나씩)

### 시트 1 — 제빵장(주인공) / 식빵 (`ref_1_hero_captain_melee_basic.png`)
```text
Sheet 1. Row 1: the HEAD BAKER (the hero): tall chef hat, red cape, holds a big baguette like a sword. Cheer: raises the baguette straight up overhead in the jump and peak, cape flaring; landing with the baguette resting on the shoulder and a proud grin.
Row 2: the TOAST KNIGHT: a square toast slice body with a red scarf and a small bread knife. Cheer: waves the bread knife over its head, tiny legs kicking in the jump.
```

### 시트 2 — 롤빵 / 통식빵 (`ref_2_ranged_basic_tank.png`)
```text
Sheet 2. Row 1: the ROLL THROWER: a small bread-crust figure in a brown hood with a yellow tunic, throws bread rolls. Cheer: tosses one bread roll straight up in the jump, the roll above its head at the peak, catches it on landing.
Row 2: the LOAF KNIGHT: a sturdy loaf-brown knight with a closed visor helmet and a cream shield with a red cross. Cheer: heavy and proud, a small hop only (about half the height of the others), raises the shield high at the peak.
```

### 시트 3 — 프레첼 / 화덕포 (`ref_3_fast_siege.png`)
```text
Sheet 3. Row 1: the PRETZEL RIDER: a small rider in a pretzel-gold tunic and cap on a cream horse, holding a short lance. Cheer: instead of jumping, the horse rears up on its hind legs in cells 2-3 while the rider raises the lance high; cell 4 the horse lands on all four legs, both happy.
Row 2: the OVEN CANNON: a brick oven on a wooden wagon with two wheels, a dark tube on top like a chimney, a small gold flag at the back, a glowing oven mouth. No crew. Cheer: the wagon bounces on its wheels (small hop), the tube puffs a harmless cloud of white flour confetti straight up at the peak (no fire), the flag waves.
```

### 시트 4 — 바게트 / 마카롱 (`ref_4_baguette_macaron.png`)
```text
Sheet 4. Row 1: the BAGUETTE PIKEMAN (tall baguette body, iron cap with a red plume, long pike). Cheer: thrusts the pike straight up in the jump and peak, the plume bouncing.
Row 2: the MACARON SHARPSHOOTER (lavender macaron, navy beret, crossbow). Cheer: holds the crossbow up with both hands, beret popping off a little at the peak and back on at landing.
```

### 시트 5 — 케이크 / 도넛 (`ref_5_chili_donut.png`)
```text
Sheet 5. Row 1: the CAKE CREAMER (two-layer cake with three lit candles, whipped-cream dispenser). Cheer: squirts a small swirl of white whipped cream straight up at the peak, the candle flames flaring a bit taller.
Row 2: the DONUT GUARD (ring donut with pink icing, helmet, frying-pan shield). Cheer: bangs the frying pan up high at the peak, a small bounce on landing.
```

### 시트 6 — 와플 / 견습생 (`ref_6_waffle_worker.png`)
```text
Sheet 6. Row 1: the WAFFLE SIEGE CREW (square waffle with a leather cap, next to its small catapult). Cheer: the waffle jumps beside the catapult (the catapult stays on the ground), the catapult arm flips up at the peak.
Row 2: the APPRENTICE (small baker kid, white cap, red apron). Cheer: throws both arms up, cap lifting off the head at the peak, a happy landing.
```

## 받은 결과 검토 (2026-11-15)

원본은 `docs/art/gpt_sources/cheer/cheer_1.png`~`cheer_6.png`. 게임 크기로 줄여 지금 대기 그림 옆에 놓은 비교: `compare_1_hero_to_oven.png`, `compare_2_baguette_to_worker.png`(맨 왼쪽 = 지금 게임 그림, 오른쪽 4개 = 환호).

| 유닛 | 판단 | 메모 |
| --- | --- | --- |
| 식빵, 통식빵, 화덕포, 바게트, 마카롱, 케이크, 도넛, 와플 | 사용 가능 | 게임 크기에서 같은 캐릭터로 읽힌다 |
| 제빵장 | 사용 가능(조금 다름) | 머리·모자가 조금 크고 얼굴이 둥글다. 짧은 환호라 허용 범위 |
| 프레첼 | 사용 가능(조금 다름) | 게임 말의 이마에 있는 금색 뿔이 빠졌다 |
| 롤빵 | 다시 받기 권장 | 갈색 두건이 긴 머리처럼 그려졌다 |
| 견습생 | 다시 받기 권장 | 게임은 마른 체형·작은 모자인데, 머리가 큰 2등신·큰 요리사 모자로 바뀌었다 |

시트 5·6에는 칸 테두리 선이 그려져 있다. 자를 때 칸 안쪽 10px을 버리면 된다.

### 다시 받을 때 보낼 문장 (해당 ref 이미지 첨부)

```text
Redo only row 1 of sheet 2 (the ROLL THROWER). It is NOT a girl with long hair: it wears a brown hood that wraps the head like a monk's cowl, with a pale round face showing in the opening and one big eye, exactly as in the ref image. Keep its small body size and the yellow tunic. Same 4 cheer poses, same rules.
```

```text
Redo only row 2 of sheet 6 (the APPRENTICE). Match the ref proportions exactly: a slim kid about 3 heads tall (not a big-headed chibi), a SMALL flat white cap (not a tall chef toque), white shirt, red apron, brown trousers. Same 4 cheer poses (the small cap may pop up at the peak), same rules.
```

```text
(optional) Sheet 3 row 1: the cream horse has a small golden horn on its forehead, as in the ref. Add it in all 4 cells, change nothing else.
```
