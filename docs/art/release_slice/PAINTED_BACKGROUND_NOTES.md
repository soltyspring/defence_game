# 일러스트 배경(painted_chapters) 광원·건물 검토와 재생성 지침

대상: Codex가 만든 `assets/backgrounds/painted_chapters/{meadow,orchard,frost,nest}.png`(원본은 수정하지 않음).
사용자 의견(2026-11-13): "이전보다 훨씬 낫지만 너무 카툰 같다", "광원이랑 건물들이 부자연스럽다".

## 진단
1. **해가 없다.** 지붕 양쪽 경사면과 모든 벽 앞면이 고르게 밝다. 그림자 방향이 없어 시간대·광원이 읽히지 않는다.
2. **건물이 떠 있다.** 벽·나무가 땅과 만나는 곳에 접지 그림자가 거의 없다. 건물이 모두 한 기준선에 정면으로 서 있어 무대 소품처럼 보인다.
3. **원근이 평평하다.** 먼 집과 가까운 빵집의 선명도·채도·대비가 같다. 공기 원근(멀수록 푸르고 흐림)이 약하다.
4. **채도가 최대에 가깝다.** 하늘·밀밭·지붕이 모두 강한 원색이라 그림책 느낌이 난다.
5. 캐릭터가 2등신·굵은 외곽선이라 고급스러운 배경 위에서 더 장난감처럼 보인다(→ 캐릭터 작업으로 따로 처리).

## 코드로 고친 것(임시) — `tools/art/release_slice/relight.py`
결과: `assets/art/release_slice/painted_relit/*.png`(크기·도로·병사 줄 위치 동일, 원본 대신 끼워 쓸 수 있음).
- 높이별 공기 원근: 원경은 안개·저대비, 건물 띠는 약하게, 병사 줄·도로는 그대로.
- 한 방향 광원: 밝은 곳은 따뜻하게·어두운 곳은 차갑게(분할 톤), 왼쪽 위 해무리, 밝기를 높이장으로 본 램버트 조명(왼쪽 위 빛).
- 건물 기준선 아래 접지 그림자 띠(오른쪽으로 약간 밀림).
한계: 평평하게 칠해진 건물에 진짜 밝은 면/그늘 면, 오른쪽으로 떨어지는 그림자는 만들 수 없다. 개선 폭은 원경·깊이 쪽이 크고 건물은 작다.

## 재생성 때 프롬프트에 더할 문장(권장)
기존 프롬프트의 레이아웃 조건(30–64 % 건물, 64–78 % 병사 줄, 78 % 도로, 좌우 반복)은 그대로 두고 아래를 추가한다.
> Lighting: ONE low morning sun from the UPPER LEFT. Every building and tree has its left wall and left roof slope in warm light and its right side in cool blue-violet shadow. Cast shadows fall to the RIGHT across the ground. Dark soft contact shadows where every wall, cart, barrel and tree trunk meets the ground. Light shafts and haze catch the sun.
> Depth: buildings at several distances — nearer ones larger and overlapping, farther ones smaller, hazier, bluer and lower in contrast; not all standing on one baseline. Strong aerial perspective on hills and mountains.
> Rendering: natural daylight, restrained saturation (no pure primaries), painterly realism with visible brushwork, no outline strokes around buildings, no storybook cartoon look, no toy-like dollhouse symmetry. Weathered, lived-in materials.

## 다음
- 재생성본이 나오면 `relight.py`를 원경 안개·분할 톤만 남기고 약하게 다시 적용할지 비교한다.
- 실제 게임 확인: 2026-11-13 05:15 기준 `src/gameplay/painted_chapter_backdrop.gd`(Codex 미커밋)가 컴파일되지 않아 실게임 캡처는 못 했다.
