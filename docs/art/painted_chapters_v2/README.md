# 챕터 배경 재생성본

2026-11-13 · 내장 `image_gen` 사용. 기존 `assets/backgrounds/painted_chapters/` PNG 네 장을 각각 구도 참조로 사용했다.
이 디렉터리는 검토용이다. 기존 자산과 전투에서 불러오는 파일은 그대로 유지한다.

| 라운드 | 재생성본 | 광원과 공간 |
|---|---|---|
| 1–10 | [밀밭 마을](meadow.png) | 언덕 위 풍차와 제빵소, 그늘진 처마와 옅은 푸른 원경 |
| 11–20 | [가을 과수원](orchard.png) | 왼쪽 위 햇살, 착즙장 기둥 밑의 그림자와 개울 너머 물레방아 |
| 21–30 | [눈 덮인 제분소](frost.png) | 따뜻한 겨울 햇빛, 푸른 눈 그늘, 언덕 위로 물러난 저장고 |
| 31–40 | [균사 동굴](nest.png) | 왼쪽 천장 틈의 빛, 바위에 붙은 뿌리, 안개 속 은은한 균사 |

네 장 모두 2172×724. 원본과 같은 구도의 수평 도로와 그 위의 병사 영역을 유지했다. 도로와 병사 영역은 생성본 안에서 다시 그려졌으므로 원본과 픽셀 단위로 같지는 않다. 건물과 나무 밑의 그림자, 면마다 다른 조명, 먼 능선의 안개를 생성 단계에서 반영했다. 기존 임시 재조명본은 비교 대상으로 남겨 두었고 재생성본에는 후처리를 적용하지 않았다.

나중에 일괄 테스트할 때 실제 전투에서 발 위치, 배경 이음새, 병사와 경고 표시의 대비를 확인한다.

## 공통 프롬프트

> Use case: style-transfer, a full repaint of a game panorama. Input image 1 is the edit target and a locked layout reference. Output a single opaque 3:1 panorama at the same aspect and framing, no borders. Redraw the environment above the combat lane with grounded painterly realism and physical lighting; the old cartoon finish should be gone. Keep the reference's gameplay geometry: continuous ruler-straight level traversable road across the whole width at the same exact height and thickness as the input, the soil cutaway below it, and the quiet empty low-contrast band between about 64% and the road at 78–82% of frame height. Preserve the original reference road and low band as closely as possible, keeping its color family, lane edges, and position; keep cast shadows above that band. No prop, character, UI, lettering, glow, or obstacle in the combat strip. Keep a side-on horizontal camera; render buildings slightly turned and at varied depths, built from real materials with structural details. Near structures overlap vegetation and have strong local definition; far buildings are smaller, partially occluded, cooler, softer and lower contrast. Irregular terrain terraces in the background only; architecture must not all stand on a line. Lighting: ONE low motivated light source from upper left, warm light on left-facing planes, cooler diffuse shadows on right-facing planes. Shadows from separate objects must all project right across the terrain, with narrow dark contact shadows at the feet of walls, trees, and objects, plus soft outer edges. Controlled natural color and visible confident brushwork. No line art, glossy cartoon, dollhouse symmetry, oversaturation, heavy vignette, or generic gray color cast. Broad subtle texture and quiet edges at both sides for mirror tiling; keep dramatic details concentrated from 30% to 64% height. No characters, interface or text anywhere.

## 챕터별 추가 지시

### meadow

> Chapter direction: 1 / Wheat village: a working stone flour windmill left of center on a slightly higher grassy bank, weathered limewashed bakery at mid-right set into sloping land. Build believable masonry, a tar-dark timber extension and worn ochre clay tile with sunbleached ridges. Small field cottages at staggered distances partly behind hedges, olive and dry straw tones, distant layered blue-grey hills vanishing into haze. Natural warm sidelight through thin cloud from upper left; a pronounced cool cast shadow from the mill falls right over the hill, with deep shade under eaves. Use real wheat colors and muted blue sky. Road begins around 77.5% height as in source.

### orchard

> Chapter direction: 2 / Cider orchard: weathered oak cider press on a small raised terrace left of center, behind overlapping gnarled apple trees, broken stone watermill further back right along the stream. Real apple trees with sparse fruit, restrained copper, tobacco, muted olive, and lichen stone; no oversized fruit or saturated orange leaf carpet. Strong sun-through-haze from upper left, dappled but directionally consistent shadows, dusty subdued plum and cool grey hills in far background. Contact shadow anchors barrels, trunks, and footings. Road begins around 79% height as in source.

### frost

> Chapter direction: 3 / Frozen mill pass: stone watermill offset in the middle distance with one side face clear, icebound wheel, low timber storehouse further away behind spruce trees on another level. Snow should be cream-white where lit and muted blue-grey in shade, with atmospheric silhouettes of foothills in front of far snowy peaks. Low amber winter sun from upper left reflects faintly off fresh snow, clear rightward blue-violet cast shadows, physically plausible ice and snow accumulation, compacted dirt/snow on road, restrained warmth from the windows. Road begins around 82% height as in source.

### nest

> Chapter direction: 4 / Mycelium cavern: grounded dark fantasy cave with rough slate strata, real dark moist stone, tangled tree roots, weathered stone arch at mid-depth and irregular natural shelf fungi at different distances. No cartoon oversized evenly glowing caps or shiny neon veins. The single key comes from a narrow opening at the upper left, cool pale sunlight with a hint of warmth grazing the rock; give formations and roots a consistent cool deep shadow to the right and contact shadows into the bedrock. Restrained muted slate, ochre rock and deep moss teal; sparse weak turquoise bioluminescence and a small violet distant spore cluster are accents, not competing key lights. Layers of grey-green cave mist show depth. Keep the clear troop strip at the source's moderate brightness. Road begins around 77% height as in source.
