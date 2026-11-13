# 도트 캐릭터와 맞춘 챕터 배경 시안

내장 `image_gen`으로 만든 전투 배경 PNG 4장(2172×724). 회화 원본과 이전 시안은 보존했다.
배경에 캐릭터보다 부드러운 명암과 자연스러운 색을 쓰고, 풍경은 계단형 픽셀 윤곽으로 표현했다.
일반 전투에서 10라운드마다 한 장을 선택한다. 수평 도로의 높이는 원본 PNG별로 맞췄으며 병사 뒤는 장애물 없이 비웠다. 정식 회귀 테스트와 Windows 빌드는 일괄 검증으로 미룬다.

- [1–10: 풍차와 밀밭](meadow.png)
- [11–20: 안개 낀 과수원](orchard.png)
- [21–30: 얼어붙은 폭포와 협곡](frost.png)
- [31–40: 뿌리와 바위 아치가 있는 균사 동굴](nest.png)

## 공통 생성 프롬프트

> Use case: stylized-concept. Original 3:1 2D PIXEL ART game background asset for a sophisticated grounded medieval side-scrolling game. Generate a single full-bleed opaque ultra-wide panorama, approx 2172×724. Aim for a crisp logical low-res grid of about 724×241, nearest-neighbor enlarged, finely placed hard-edged pixel clusters with intentional stepped contours and occasional ordered dithering. The pixels should be visibly authored in sky, terrain and foliage, no smooth digitally painted brushstrokes, no photo-filter, no soft antialias. Visual design: nuanced realistic lighting and ecology, irregular silhouettes, credible scale and weight, muted but differentiated local colors. Like a mature 32-bit pixel adventure environment with atmospheric perspective and quiet value grouping, NOT cute cartoon, cel shading, thick outlines, chibi scenery, glossy color, clutter or bright saturated accents. Soft natural light comes from top left with coherent contact shadows and faint rightward cast shadows. Character sprites overlaid later have very dark outlines, cream/terracotta/teal pixels, and are about 30–50 logical pixels tall; therefore the background never uses strong black outlines and keeps value variation restrained in the gameplay area. Exact side-on horizontal layout: natural scenery and landmarks concentrated above 64% height; entirely open, muted medium-light band from 64% to 78% height behind sprites; ruler-straight walkable road horizontally across entire width, back edge at 78%, near edge at 85%, never curving or receding. Below that, subdued cutaway with material appropriate to location. Keep both sides visually quiet for mirror tiling. No people, sprites, enemies, characters, letters, signs, text, UI, frames.

## 챕터별 추가 프롬프트

> R01–10: Wind through a straw-gold wheat field with soft blue-sage ridges and one modest old stone windmill on a middle-distance rise at 38% width. The only man-made structure, small but recognizable; no houses or town. Slightly warm light on the left, shaded right face and a clear contact shadow. Dry muted honey and soft slate-blue distance, a tan road.

> R11–20: Old apple orchard, broad spacing between irregular trunks, reddish brown and olive foliage, pale ground fog far behind. A narrow creek in the middle distance with a little muted cool reflection and a few mossy rocks. Keep apples rare and at real scale. No houses, buildings, bridges or watermills. Warm ochre and tobacco midtones; plain clay walking road.

> R21–30: Alpine gorge, several snowbound ledges, a frozen waterfall layered against grey stone at 45% width and distinct distant fir ridges. Beige-white morning light, slate blue shade, subdued teal ice. No buildings or man-made elements except the straight compacted snow route. Keep white snow and waterfall detail out of the lower combat strip, whose tones are soft dusty blue-grey.

> R31–40: Natural wet stone cavern with a memorable eroded arch and twisted roots, pale light entering a roof fissure left of frame, layered distant mist. Tiny shelf fungi and a few dim desaturated lilac or teal pixels in distant crevices. No glowing giant mushrooms or magic crystals. Mossy grey-green open troop strip is medium-light enough for dark sprites. Muted mossy stone road.
