# 기력 스킬 아이콘 7종 (ChatGPT 이미지 생성용)

스킬 버튼 아이콘 7개가 둘로 나뉘어 있다. 앞의 셋(내려찍기·함성·포격)은 예전 화풍이고, 뒤의 넷(밀가루·설탕·얼음·오븐)은 코드로 그려서 밋밋하다. 같은 테두리와 화풍으로 7개를 한 장에 다시 그린다. 크기는 지금과 같은 24×24이다.

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_current_icons.png` | 지금 아이콘 7개(8배 확대). 바꿀 대상 |
| `2_ingame_context.png` | 전투 화면 오른쪽 아래 스킬 버튼(48×48 안에 24×24)과 출전 준비의 스킬 탭 |
| `3_style_reference.png` | 유닛 카드 아이콘. 외곽선·색·명암을 여기에 맞춘다 |
| `4_sheet_layout.png` | 시트 형식: 자홍 배경, 4칸 × 2줄, 칸 안의 384×384 정사각형 = 24×24 도트를 16배로. 8번 칸은 비운다 |

## 진행 방법

1. 새 대화에 이미지 4장을 첨부하고 **① 공통 지시**를 보낸다.
2. **② 그리기**를 보낸다. 시트 한 장에 아이콘 7개가 나온다.
3. 마음에 들지 않는 아이콘만 **③ 한 개 고치기**로 다시 그리게 한다.
4. 결과를 `skill_icons.png`로 저장해서 넘겨준다. 한 개만 다시 그린 시트는 `skill_icons_fix.png`로 저장한다.

---

## ① 공통 지시

```text
I'm making the skill button icons for a cute pixel-art lane-defence game where bread knights fight mould monsters. I attached 4 images:
1_current_icons: the 7 current skill icons (24x24, shown 8x). Two different styles; the last four are too plain. Replace all seven.
2_ingame_context: where they appear: 48x48 skill buttons at the bottom right of the battle screen, and the skill tab of the deploy screen.
3_style_reference: our unit card icons. Match their outline, palette, shading and cuteness exactly.
4_sheet_layout: the sheet format.

Rules:
- Canvas 1536x1024, flat pure magenta #FF00FF background.
- 4 columns x 2 rows of 384x512 cells. Each icon fills the 384x384 square inside its cell (24x24 art pixels at 16x, every art pixel a 16x16 block). Icons 1-7 in order; cell 8 stays empty magenta.
- All seven share one badge shape: a rounded-square frame with a 1-pixel dark outline and a 1-pixel coloured rim in the skill's colour, a darker inner background, and one bold symbol in the middle that reads at 24x24.
- True pixel art: no anti-aliasing, no blur, no gradients, at most 12 colours per icon, light from the upper left.
- No text, no numbers, no grid lines.

Reply "ready" and wait.
```

## ② 그리기

```text
Draw the 7 icons in this order:
1 ROLLING-PIN SLAM (brown rim): a wooden rolling pin smashing down with a white-yellow impact burst and flying crumbs.
2 FRESH-BAKED RALLY (warm red rim): a golden bread banner or horn with rising golden chevrons, a cheering battle cry feeling.
3 BREADCRUMB BARRAGE (purple rim): a round golden crust shell with a cross score mark falling diagonally, with a short streak trail.
4 FLOUR DROP (wheat gold rim): a cream flour sack with a brown tie and a wheat stamp, a small puff of flour and a sparkle.
5 SUGAR BARRIER (pink rim): a pink sugar-glass dome with hexagonal facets and a white glint.
6 FROST CREAM (icy blue rim): a swirl of white cream with blue ice crystals rising from it.
7 OVEN HEAT (orange rim): a bold flame tongue: deep red base, orange body, yellow core, two embers.
```

## ③ 한 개 고치기

```text
Redraw only icon N on the same sheet layout (cell N, others empty magenta), same badge frame: <what to change>.
```

## 결과가 어긋날 때 보낼 한 줄 수정

- 작게 보면 안 읽힌다: `Simpler, bolder symbol: fewer details, thicker shapes, stronger contrast at 24x24.`
- 테두리가 제각각이다: `All seven must use the identical badge frame; only the rim colour and symbol change.`
- 그림처럼 부드럽다: `Real pixel art only: square 16x16 blocks, flat colours, 1-pixel outline.`
- 글자가 들어갔다: `No text or numbers anywhere.`
