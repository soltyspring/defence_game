# 타격·폭발·소환 효과 (ChatGPT 이미지 생성용)

전투 중 가장 자주 보이는 효과(타격 불꽃, 곰팡이 침 튐, 폭발, 쓰러질 때 연기, 먼지, 소환)가 점 몇 개와 가는 고리라서 맞았다는 느낌이 약하다. 같은 이름의 효과를 굵은 도트 애니메이션으로 다시 그린다. 게임은 같은 이름의 효과를 자동으로 새 그림으로 바꿔 그린다.

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_current_hit_fx.png` | 지금 효과 6종(4배 확대). 바꿀 대상 |
| `2_ingame_context.png` | 실제 전투 화면. 효과가 터질 자리와 크기감 |
| `3_unit_scale.png` | 유닛 크기: 영웅 48px, 병사 32px |
| `4_sheet_layout.png` | 시트 형식: 자홍 배경, 4칸 × 2줄 = 8프레임, 칸마다 48×64 도트를 8배로. 십자 = 타격 지점, 아래 선 = 땅 |

## 진행 방법

1. 새 대화에 이미지 4장을 첨부하고 **① 공통 지시**를 보낸다.
2. 효과마다 **②** 한 줄을 보낸다. 효과 하나에 시트 한 장이 나온다.
3. 결과를 `hit_spark.png`, `hit_spit.png`, `explosion.png`, `death_poof.png`, `dust.png`, `spawn.png`로 저장해서 넘겨준다.
4. 3장마다 새 대화에서 ①부터 다시 한다(화풍 유지).

---

## ① 공통 지시

```text
I'm redrawing the combat effects of a cute pixel-art lane-defence game where bread knights fight mould monsters. I attached 4 images:
1_current_hit_fx: the current effects (shown at 4x). They are a few dots and thin rings; hits do not feel like hits. Replace them, same names and purpose.
2_ingame_context: the real battle screen; effects pop over these characters.
3_unit_scale: hero 48 px, soldier 32 px tall.
4_sheet_layout: the sheet format.

Rules for every sheet:
- Canvas 1536x1024, flat pure magenta #FF00FF background.
- 4 columns x 2 rows of 384x512 cells = 8 frames, left to right, top row first. Fewer frames: leave the last cells empty magenta.
- Each cell is a 48x64 pixel grid at 8x (every art pixel an 8x8 block). Hits are centred on the cross; ground effects sit on the lower line.
- True pixel art: chunky, bold shapes, 2-3 tone shading, bright first frames that fade by shrinking and breaking up (not by blur or transparency), at most 12 colours per effect, 1-pixel dark outline on solid shapes, no anti-aliasing.
- Effects only: no characters, no ground, no text, no grid lines.

Reply "ready" and wait.
```

## ② 효과별 한 줄

```text
HIT_SPARK (6 frames, the most common melee hit, about 20x20 px): a white-yellow star flash with 4-6 thick spikes, a tiny ring of bread crumbs flying out, then shrinking sparks.
```
```text
HIT_SPIT (5 frames, a mould glob hitting, about 20x16 px): a green-teal slime splat on the cross, droplets spraying left and right, then dripping bits.
```
```text
EXPLOSION (8 frames, a bomb / siege shell, up to 44 px wide, 40 px tall, bottom on the ground line): white flash, round orange-yellow fireball with a dark red rim, flying brown crust chunks, then grey smoke puffs rising and breaking up.
```
```text
DEATH_POOF (6 frames, a mould monster vanishing, about 30x24 px on the ground line): a puff of pale violet-grey spore smoke with a few green mould flecks, ending in 2-3 small rising spores.
```
```text
DUST (4 frames, a footstep or landing on the road, about 24x8 px on the ground line): a low beige dust cloud kicked to both sides, settling.
```
```text
SPAWN (6 frames, a soldier being deployed, about 28x40 px on the ground line): a flour-white poof with a golden ring on the ground and a few wheat-gold sparkles rising; warm and cheerful, not a blue beam.
```

## 결과가 어긋날 때 보낼 한 줄 수정

- 너무 가늘다: `Bolder: thick pixel shapes, fewer thin lines, stronger contrast.`
- 크기가 칸마다 다르다: `Keep the impact point and size consistent; only the animation changes.`
- 부드럽게 번졌다: `Real pixel art only: square 8x8 blocks, flat colours, no glow gradients.`
