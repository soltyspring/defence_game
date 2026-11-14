# 기사단 본부 '편성' 카드 삽화 (ChatGPT 이미지 생성용)

기사단 본부에 세 번째 카드 '편성'이 생겼다(2026-11-15). 지금은 강화 훈련장 배경(`assets/art/lobby/training.png`)을 잘라 쓰고 그 위에 출전 중인 유닛 아이콘을 얹어 둔 임시 그림이라, 옆의 '라운드 선택'·'강화' 카드보다 밋밋하다. 같은 화풍의 카드 삽화 한 장을 받는다.

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_existing_lobby_cards.png` | 지금 쓰는 두 카드의 원본 시트(위: 라운드 선택, 아래: 강화). 이 화풍·밝기·시점에 맞춘다 |
| `2_hall_now.png` | 지금 기사단 본부 화면. 가운데가 임시 '편성' 카드 |
| `3_characters.png` | 아군 유닛들(식빵·롤빵·통식빵·프레첼·화덕포·제빵장). 장면에 나올 캐릭터 |
| `4_layout_guide.png` | 그림 영역(718×475, 카드 224×148과 같은 비율). 아래 띠에는 게임이 이름을 쓴다 |

## 진행 방법

1. 새 대화를 열고 이미지 4장을 첨부한 뒤 아래 프롬프트를 보낸다.
2. 결과를 `squad_card.png`로 저장해서 넘겨준다.
3. 받은 그림은 `docs/art/gpt_sources/lobby/`에 넣고 `tools/art/import_lobby_art.py`에 자르기 영역을 더해 `assets/art/lobby/squad.png`(224×148)로 만든 뒤 편성 카드에 연결한다. 그때 임시 유닛 아이콘은 뺀다.

## 결과가 어긋날 때 한 줄 수정

| 증상 | 보낼 문장 |
| --- | --- |
| 화풍이 다른 두 카드와 다름 | `Match 1_existing_lobby_cards exactly: same painterly pixel style, same warm evening light, same level of detail.` |
| 아래쪽이 복잡해 글자가 안 읽힘 | `Keep the bottom quarter calm and slightly dark (plain floor), the game writes the card name there.` |
| 캐릭터가 사람 병사처럼 나옴 | `The soldiers are the bread characters from 3_characters (toast, roll, loaf, pretzel), not humans.` |
| 글자가 들어감 | `No text, letters or numbers anywhere in the picture.` |

---

## 프롬프트 (이미지 4장 첨부와 함께)

```text
I need one more card illustration for the main hall of a cute pixel-art bakery defence game. I attached 4 images:

1_existing_lobby_cards: the two existing card illustrations (top: round select = the bakery castle and fields, bottom: upgrades = a bakery workshop with an oven). Match their style exactly: painterly pixel art, warm evening light, rich but readable detail, soft dark vignette at the edges.
2_hall_now: the current main hall screen. The middle card is a placeholder for the new one.
3_characters: our ally characters. They are bread and pastry knights, not humans.
4_layout_guide: fill the dashed area (718x475) completely. The bottom band is covered by a dark name strip in the game.

The new card is "SQUAD" (choosing which knights go to battle): a cosy wooden barracks or training yard inside the bakery castle. In the middle, four or five of the bread knights from 3_characters stand in a neat row facing the viewer, ready for inspection: the toast knight with a bread knife, the roll thrower, the big loaf shield knight, the pretzel runner, and the small oven cannon on wheels at one end. Behind them a wall with a wooden weapon rack and a red banner with a loaf emblem, a chalkboard with small pinned cards (no readable text). The Head Baker (white chef hat, red cape) stands at one side holding a clipboard.

Rules:
- Canvas 1536x1024, flat pure magenta #FF00FF outside the dashed area; inside it, the full picture edge to edge.
- Same pixel density as 1_existing_lobby_cards (it is shown at 224x148).
- The bottom quarter is a calm, slightly darker floor so a white name can sit on it.
- No text, letters or numbers anywhere. No UI frames, no buttons.
```
