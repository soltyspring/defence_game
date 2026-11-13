# 챕터별 반복 배경 레이어

일반 전투에서 10라운드마다 바뀌는 배경 PNG 10장이다. 같은 방향으로 반복하고 도로는 게임이 따로 그린다. 기존 회화와 도트 원본은 보존한다.
PNG 하단 36개 단색 행 중 16개만 화면에 사용해 배경과 도로 사이의 여백을 줄인다. 41–100라운드 배경은 별도 100라운드 캠페인 데이터가 들어왔을 때 사용된다.

| 라운드 | 배경 | 생성본에서 평지 시작 행 |
|---|---|---:|
| R01–10 | [밀밭 마을](meadow.png) | 565 |
| R11–20 | [가을 과수원](orchard.png) | 510 |
| R21–30 | [얼어붙은 제분소](frost.png) | 535 |
| R31–40 | [균사 동굴](nest.png) | 547 |
| R41–50 | [설원 채석장](frost_quarry.png) | 640 |
| R51–60 | [포자 습지](spore_marsh.png) | 623 |
| R61–70 | [얼어붙은 요새](frozen_bastion.png) | 644 |
| R71–80 | [뿌리 전당](root_vault.png) | 633 |
| R81–90 | [오로라 빙하](aurora_pass.png) | 626 |
| R91–100 | [균사 핵실](mould_heart.png) | 629 |

내장 `image_gen`으로 제작하고 `tools/art/export_chapter_tile.ps1`로 논리 픽셀 1024×176, 32색으로 정리한 뒤 보간 없이 4배 확대했다. 좌우 끝 열은 반전 없이 동일한 색으로 연결된다. 하단 36행은 단색이며 도로와 흙 단면은 포함하지 않는다. 네 PNG 모두 실제 크기, 4×4 블록, 색상 수, 끝 열 일치와 하단 단색을 확인했다.

## 생성 프롬프트

> Use case: stylized-concept. Generate one opaque BACKGROUND LAYER for a pixel-art lane defence game. Ultra-wide 64:11 (target 4096x704, logical 1024x176). Fit the FULL composition in the aspect given; if platform cannot reach 64:11, compose a horizontal panoramic strip with these proportions across full canvas width and keep vertical proportions within your actual canvas (will be normalized). True sparse hand-placed pixel art: crisp small pixel clusters and large flat shapes, no painterly texture, AA, blur, gradients or dither, 32 total colors maximum, flat 3–5 tone ramps. 1 logical px own-hue dark outline on close landmarks, never black. Soldier scale 32 logical px; door 20, cottage 48–64, windmill 80–100, trees 40–70. Upper-left light with warm lit faces and cool shaded faces, rightward shadows and narrow contact shadows. Muted naturally saturated palette, low detail. Top 40% cooler distant sky/forest/mountains, landmarks at staggered distances and heights; ALL landmarks end before 79.5% image height. From 79.5% to 100% show ONE SOLID flat calm ground color, empty, no texture whatsoever. No road, path, soil cutaway, foreground grass strip, stones, roots in the bottom area. True horizontal wrap (not reflected): the leftmost 6% and rightmost 6% contain an identical quiet sky and gently layered low far field in identical colors and heights at both edges; keep buildings, trees and high contrast shapes away from both edges. No frame, figures, UI, words. Draw an actual game background, not a mockup.

> CH1 meadow (R1–10): sunlit wheat village in late morning; golden wheat fields, sage hills, a stone flour windmill as the main landmark, two or three small timber-and-plaster cottages with terracotta roofs and thin chimney smoke, a few round oak trees, low dry-stone walls.

> CH2 orchard (R11–20): autumn cider orchard in afternoon light; rows of apple trees with copper leaves and a few red apples, a timber cider press shed, an old stone watermill by a narrow stream in the middle distance, lavender mist on the far forest; the right third slowly turns grey and mould-sick (dead branches, pale grey-teal fungus caps). Return to a quiet matching distant silhouette at the extreme edge only.

> CH3 frost (R21–30): frozen mill pass on a clear winter afternoon; snowy fir forest, layered blue-grey alpine peaks, a stone flour mill with a frozen waterwheel and a small granary with heavy snow on the roofs, two warm amber windows; icy teal and periwinkle shadows.

> CH4 nest (R31–40): inside a vast mould nest cavern; grey-green rock arches and root ribs, hanging glowing spore sacs in teal and violet as the only bright accents, dim misty depth; light comes from a cold opening high on the upper left. Distant cavern replaces sky. Root ribs are overhead only, never in the ground zone.

동굴은 집과 인공 구조물을 제거하고 자연 암석 아치로 대체하도록 내장 이미지 편집으로 한 번 더 수정했다.
