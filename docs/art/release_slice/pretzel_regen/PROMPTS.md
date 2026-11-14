# 프레첼병 재디자인 (ChatGPT 이미지 생성용)

지금 프레첼병은 낙타 같은 황갈색 짐승을 탄 작은 빵 기수라서, 프레첼(8자처럼 꼰 반죽 매듭, 굵은 소금 알갱이)로 보이지 않는다(2026-11-15 사용자). 화덕포 때처럼 **후보 4개**를 받아 고르고, 고른 하나로 게임용 시트와 환호를 받는다.

역할(바꾸지 않음): 아군 돌격병. 싸고(밀가루 55) 체력이 낮으며(90), 가장 빠르게(속도 80, 다른 병사의 2~3배) 달려가 바로 앞의 적을 짧은 간격(0.7초)으로 연속해서 친다. 근접 유닛.

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_style_reference.png` | 지금 게임의 아군들(게임이 실제로 쓰는 그림). 화풍·크기감·외곽선 기준 |
| `2_current_pretzel.png` | 지금 프레첼병(대기·걷기·공격·쓰러짐). 바꿀 대상 |
| `3_in_game.png` | 실제 전투 화면 크기(가운데 오른쪽, 짐승을 탄 기수가 지금 프레첼병) |
| `4_layout_candidates.png` | 후보 배치: 2×2칸, 칸마다 왼쪽 = 대기, 오른쪽 = 공격이 맞는 순간 |

## 진행 방법

1. 새 대화에 이미지 4장을 첨부하고 **① 후보 프롬프트**를 보낸다.
2. 결과를 `pretzel_candidates.png`로 넘겨주면 게임 크기로 줄여 다른 아군 옆에 세운 비교를 만들어 드린다. 하나를 고른다(섞어도 된다).
3. 같은 대화에서 **② 게임용 시트**(8동작)와 **③ 환호**(4동작)를 받는다.
4. 화덕포처럼 전투 그림·카드 초상·환호를 함께 바꾼다.

## 결과가 어긋날 때 한 줄 수정

| 증상 | 보낼 문장 |
| --- | --- |
| 프레첼로 안 보임 | `Make the pretzel knot obvious at a glance: a thick glossy dark-golden dough rope twisted into the classic pretzel shape (two round loops and a crossed twist), with white coarse salt crystals.` |
| 후보끼리 비슷함 | `Make the four candidates clearly different in silhouette and in how they move.` |
| 너무 큼/작음 | `Size it like the toast soldier in 1_style_reference: about 28-34 game pixels tall (a mount may make it up to 40 wide).` |
| 흐릿하거나 그라데이션 | `True pixel art: hard square 8x8 blocks, no anti-aliasing, at most 24 colours.` |
| 분홍·보라가 들어감 | `No pink, purple or magenta anywhere except the small blush on faces.` |

---

## ① 후보 프롬프트 (이미지 4장 첨부)

```text
I want to redesign one ally unit of a cute pixel-art lane-defence game (bread and pastry knights vs mould monsters). I attached 4 images:

1_style_reference: the ally units as they look in the game now. Match this style exactly: chunky cute bakery shapes, small black eyes with a white highlight, pink blush, a 1-pixel darker outline in each part's own hue, 4-5 tone shading with light from the upper left.
2_current_pretzel: the unit I am replacing, the PRETZEL RUNNER. Today it is a small bread rider on a tan camel-like animal, and nobody can tell it is a pretzel. Keep only its role.
3_in_game: how small units really are on screen. Every design must read at about 30 game pixels tall.
4_layout_candidates: draw 4 different candidates in a 2x2 grid; in each cell the LEFT half is the idle pose and the RIGHT half is the moment its attack hits.

The unit: the cheapest, FASTEST ally. It sprints ahead of everyone and hits the nearest enemy with quick repeated jabs. It must read instantly as "a PRETZEL": a thick glossy dark-golden dough rope twisted into the classic pretzel knot (two round loops and a crossed twist), sprinkled with white coarse salt crystals.

Candidates (make them clearly different silhouettes):
A. PRETZEL KNIGHT: the body IS a pretzel knot standing upright, the two loops framing a cute face, little legs, a small round buckler and a short sword; attack = a quick double slash.
B. PRETZEL WHEEL: a round pretzel knot that rolls like a wheel at full speed, a tiny face in the centre twist, little arms; attack = it rams and spins into the enemy with a puff of salt.
C. PRETZEL FENCER: a slim pretzel-stick body (a straight twisted dough stick) with a pretzel-knot hat, a thin rapier; attack = a lunging thrust with a salt-crystal sparkle.
D. PRETZEL RIDER, kept but made obvious: a small pretzel-knot rider on a fast little steed whose body is braided pretzel dough with salt crystals, a short lance; attack = a lance poke.

Rules:
- Canvas 1536x1024, background flat pure magenta #FF00FF everywhere, no gradient, no texture.
- True pixel art: every pixel a perfectly square 8x8 block (each candidate about 30 game pixels tall, up to 40 wide with a mount), no anti-aliasing, no blur, no soft gradients, no dithering noise, at most 24 colours per candidate.
- Side view, facing RIGHT, feet or wheel on the white ground line.
- Never use pink, purple or magenta except the small blush on faces.
- No text, no letters A-D, no cell borders, no ground drawing, no cast shadow, no background objects.
```

## ② 게임용 시트 프롬프트 (후보를 고른 뒤, 같은 대화)

```text
Great. Use candidate ___ (write any changes here). Now draw the final in-game sheet for it.
Canvas 1536x1024, flat #FF00FF, 4 columns x 2 rows of equal cells (384x512), one pose per cell, in this order:
  1 idle, 2 run A, 3 run B, 4 run C (a fast sprint or roll; the fastest unit in the game),
  5 attack wind-up, 6 attack hit (strongest moment, a small salt-crystal sparkle), 7 follow-through, 8 defeated (lying on the ground, eyes as X, a few broken dough bits).
The SAME unit in every cell: same size, colours and proportions. About 30 game pixels tall (up to 40 wide), each pixel an 8x8 block, at most 24 colours, facing RIGHT, feet or wheel on the same ground line about 64 px above each cell bottom. No grid lines, no text, no ground, no shadow.
```

## ③ 환호 프롬프트 (같은 대화)

```text
Now a victory CHEER for the same unit, 4 poses on one row of a 1536x1024 magenta canvas (cells 384x512, row 1 only, leave row 2 empty):
  1 anticipation (a little squash, happy eyes), 2 jump (off the ground, weapon or arms raised), 3 peak (a few salt-crystal sparkles), 4 landing (big ^ ^ smile, feet the same length as in the idle pose).
Same unit, size, colours and rules as the sheet above; a white ground line in each cell like before.
```
