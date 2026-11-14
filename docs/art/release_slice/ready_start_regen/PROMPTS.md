# 전투 시작 '준비 → 출전!' 연출 기획과 GPT 키트

지금은 라운드에 들어가면 아무 신호 없이 곧바로 시간이 흐른다(첫 웨이브까지 약 12초). 다른 게임의 'READY → GO'처럼 짧은 시작 신호를 넣어 전투가 시작되는 순간을 분명히 한다(2026-11-15 사용자 요청).

## 1. 기획

### 문구

| 언어 | 1단계 | 2단계 | 이유 |
| --- | --- | --- | --- |
| 한국어 | **준비** | **출전!** | '출전'은 편성·출전 준비 화면과 같은 말이라 게임 안에서 뜻이 이어진다. '시작!'보다 기사단 분위기에 맞다. |
| 영어 | **READY** | **GO!** | 짧고 익숙하다. |

### 흐름 (총 약 1.7초)

| 시간 | 화면 | 게임 |
| --- | --- | --- |
| 0.00–0.25초 | 화면 가운데 띠가 반투명하게 어두워지고, '준비'가 위에서 떨어져 살짝 튕기며 자리 잡는다. | 시간이 멈춰 있다. 유닛·적·밀가루가 움직이지 않는다. 카드·스킬 버튼은 눌리지 않는다. |
| 0.25–0.90초 | '준비'가 제자리에서 아주 작게 숨 쉬듯 위아래로 움직인다. | 멈춤 |
| 0.90–1.05초 | '준비'가 작아지며 사라지고, '출전!'이 1.6배 크기에서 1배로 쾅 박힌다. 뒤에서 밀가루 폭발 판이 펼쳐지며 살짝 돈다. 화면이 아주 약하게 흔들린다(설정의 '화면 흔들림'을 따른다). | 이 순간 시간이 흐르기 시작한다. |
| 1.05–1.50초 | '출전!' 유지 | 진행 |
| 1.50–1.70초 | '출전!'이 위로 날아가며 사라지고 띠가 걷힌다. | 진행 |

- 화면을 한 번 누르면 바로 '출전!'으로 넘어간다(반복 플레이어용).
- 라운드 시작, 다시하기, 다음 라운드에서 모두 나온다. 일시정지에서 돌아올 때는 나오지 않는다.
- R01 튜토리얼은 '출전!'이 사라진 뒤에 첫 안내를 띄운다.
- 소리: '준비'에 짧은 북소리 한 번, '출전!'에 밝은 나팔·종 한 번. 소리 레시피는 그림을 넣을 때 `tools/audio/synth.py`에 더한다.

### 그림이 하는 일과 코드가 하는 일

| 그림(GPT) | 코드(게임) |
| --- | --- |
| '준비'·'출전!'·'READY'·'GO!' 글자 4개 | 떨어짐·튕김·확대·날아감 애니메이션, 반투명 띠, 화면 흔들림 |
| '출전!' 뒤의 밀가루 폭발 판 1장 | 폭발 판의 회전·확대·사라짐 |

글자는 게임 로고와 같은 화풍(두꺼운 획, 어두운 테두리, 아래 그림자, 위가 밝은 그라데이션)으로 맞춘다. 결과 화면의 '승리!·패배' 글자(`../result_title_regen/`)와 같은 묶음이므로 **두 키트를 같은 대화에서 이어서 만들면** 글자 모양이 통일된다.

## 2. 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_battle_start.png` | 지금 전투 시작 화면. 글자가 올라갈 배경의 밝기·색 |
| `2_game_logo.png` | 게임 로고. 글자 화풍의 기준 |
| `3_mockup_placement.png` | 글자가 놓일 위치와 크기(가운데 띠). 안의 글자는 임시 글꼴이라 모양은 따르지 않는다 |
| `4_layout_guide.png` | 시트 배치. 2열 3행, 점선 상자 크기 |

## 3. 진행 방법

1. 새 대화(또는 결과 화면 제목을 만든 대화)에 이미지 4장을 첨부하고 아래 프롬프트를 보낸다.
2. 결과를 `ready_start.png`로 저장해서 넘겨준다.
3. 받은 시트는 칸마다 잘라 8배 축소하고 색 수를 정리해 `assets/art/ui/ready_start/`에 넣고, 위 흐름대로 전투 시작 연출을 붙인다.

## 4. 결과가 어긋날 때 한 줄 수정

| 증상 | 보낼 문장 |
| --- | --- |
| 글자가 틀림 | `The four words must read exactly 준비, 출전!, READY, GO! — standard letter shapes, nothing else.` |
| '준비'와 '출전!'의 굵기·크기가 다름 | `Make all four words the same stroke thickness, outline and height (about 32 pixels tall).` |
| 흐릿하거나 부드러운 그라데이션 | `Make it true pixel art: hard square 8x8 blocks, no anti-aliasing, at most 12 colours per word.` |
| 폭발 판이 글자처럼 복잡함 | `Make the burst a simple flat shape: a cream-white flour splash with 8 rounded points and a few flying drops, no text.` |
| 분홍·보라가 들어감 | `No pink, purple or magenta anywhere (the background is keyed out).` |

---

## 5. 프롬프트 (이미지 4장 첨부와 함께)

```text
I need a "READY → GO" start signal for battles in a cute pixel-art bakery defence game (bread knights vs mould monsters). It appears in the middle of the battle screen for about 1.7 seconds. I attached 4 images:

1_battle_start: the battle screen at the moment a round begins (bright autumn village, HUD at the top and bottom).
2_game_logo: the game's logo. Match this lettering style exactly: very thick blocky strokes, a 1-pixel very dark brown outline around every letter, a 2-pixel dark drop shadow straight below, a vertical colour ramp (light highlight row on top, bright middle, darker bottom), crisp pixels.
3_mockup_placement: where and how big the words sit (a dim band across the middle). The letters in it are a placeholder font; do not copy their shapes.
4_layout_guide: the sheet layout, 2 columns x 3 rows, one item centred in each dashed box.

Items:
- Row 1 left: 준비 (Korean "ready"). Cool cream-white to pale blue-grey ramp, calm.
- Row 1 right: 출전! (Korean "go into battle!"). Warm gold ramp like the top line of the logo (pale yellow highlight, golden middle, amber-brown bottom). Bold and energetic, the "!" may tilt slightly.
- Row 2 left: READY — same style and colours as 준비.
- Row 2 right: GO! — same style and colours as 출전!.
- Row 3 left: a burst plate shown behind 출전!/GO!: a flat cream-white flour splash with about 8 rounded points, a warm golden rim, and a few round flying flour drops around it. About 80x40 pixels. No text.
- Row 3 right: leave empty magenta.

Letter shapes: standard, clearly readable Hangul and Latin capitals. All four words have the same stroke thickness, outline and height: about 32 pixels tall on the pixel grid; 준비 and READY about 70-88 pixels wide, 출전! and GO! as wide as they need.

Rules:
- Canvas 1536x1024, background flat pure magenta #FF00FF everywhere, no gradient, no texture.
- True pixel art: every pixel is a perfectly square 8x8 block, no anti-aliasing, no blur, no soft gradients, no dithering noise, at most 12 colours per item.
- Never use pink, purple or magenta in the art.
- No dashed boxes, no guide text, no other words, no stars or sparkles outside the burst plate, no background scenery.
```
