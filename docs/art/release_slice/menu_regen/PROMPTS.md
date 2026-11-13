# 메인 메뉴 배경 재작화 (ChatGPT 이미지 생성용)

지금 메뉴 배경은 평면 그림체(단색 띠 하늘, 반투명 숲, 평면 길)라서, 게임 안 도트 그림과 화풍이 다르다. 메뉴 한 장을 게임과 같은 도트로 새로 그린다.

## 첨부할 이미지 (같은 폴더)

| 파일 | 용도 |
| --- | --- |
| `1_current_menu.png` | 지금 메뉴. 로고와 버튼 위치를 보여 준다. 그림체는 따라 하지 않는다. |
| `2_ingame_style.png` | 맞출 화풍: 실제 게임 화면(성, 풍차, 마을, 유닛) |
| `3_layout_guide.png` | 배치: 가운데 로고·버튼 자리는 비워 두고, 왼쪽은 우리 빵집 성, 오른쪽은 곰팡이 둥지. 위아래 15%는 넓은 휴대폰에서 잘린다. |
| `4_style_parts.png` | 성, 둥지, 풍차를 지금 게임 모양 그대로 보여 준다. 유닛은 화풍 참고용이고 그리지 않는다. |

## 진행 방법

1. 새 대화를 열고 이미지 4장을 첨부한 뒤, 아래 프롬프트를 한 번에 보낸다.
2. 마음에 드는 결과를 `menu_bg.png`로 저장해서 넘겨준다.
3. 받은 그림은 이렇게 정리해서 메뉴에 넣는다.
   - 도트 격자를 맞추고 32–40색으로 줄인다.
   - 화면 비율(16:9–20:9)에 맞게 위아래를 잘라 쓴다.

## 프롬프트

```text
Main menu background for a cute pixel-art lane-defence game: little bread knights defend their bakery town from a mould nest. I attached 4 images:
1_current_menu: the current menu, only to show where the logo and buttons sit. Do NOT copy its flat style.
2_ingame_style: the real game screen. Match this pixel-art style exactly: crisp pixel clusters, 1-pixel own-hue dark outlines, 4-5 tone shading, light from the upper left, warm storybook colours.
3_layout_guide: the layout to follow.
4_style_parts: the player keep, the enemy mould nest and the windmill as they look in the game. Draw these same buildings (same shapes and colours), larger and with more detail.

Canvas: 1536x1024 landscape. One single image, no text, no logo, no buttons, no UI, no characters, no frame.

Scene: late golden-hour dusk over the bakery valley.
- LEFT third: our bakery keep (cream brick tower with the red cone roof and brick base, warm lit windows), the windmill behind it, a few cozy village houses with smoke from chimneys, wheat field.
- RIGHT third: the dark teal mould nest (rounded fungal mass with long stalks topped by dark bulbs, glowing teal spores), cool violet-teal mist, dead trees; its side of the sky slightly cooler and darker.
- CENTRE: a dirt road winds from the bottom centre toward the horizon between the two sides. The upper centre is a calm dark-to-warm dusk sky with a low sun and soft pixel clouds, very little detail, because the game logo is placed there. The lower centre is quiet field and road, low contrast, because three menu buttons are placed there.
- Horizon around 60 % of the height. Keep every important object between 15 % and 85 % of the height (the top and bottom 15 % may be cropped on wide phones). Both side edges continue the scenery (they may be cropped on 16:9 screens).

Pixel rules: true pixel art on a grid of about 384x256 logical pixels (each pixel a 4x4 block), no anti-aliasing, no blur, no painterly brush texture, no gradients except stepped bands, at most 40 colours.
```

## 결과가 어긋날 때 보낼 한 줄 수정

- 가운데가 복잡하다: `Keep the centre calm: plain dusk sky above, plain field and road below. Move detail to the left and right thirds.`
- 그림처럼 부드럽다: `Make it real pixel art: square 4x4 blocks, flat colours, 1-pixel outlines, no soft painting.`
- 성이나 둥지 모양이 다르다: `Use the exact keep, nest and windmill shapes from 4_style_parts.`
- 글자나 버튼이 들어갔다: `No text, no logo, no buttons. Background only.`
