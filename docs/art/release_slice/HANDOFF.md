# 대표 화면(R01) 아트 — 인수인계

- **기준 SHA**: `9999750` 위에서 작업(2026-11-12). 캡처 당시 작업 트리에는 Codex의 미커밋 변경이 있었다(`src/gameplay/backdrop_scenes.gd`, `battle_view.gd`, `assets/backgrounds/ansimuz/` 등). ‘이전’ 화면은 그 트리의 기존 아트다.
- **실행**: `godot --path . res://scenes/art_preview/slice_preview.tscn` (기존 아트로 보려면 `-- --slice=off`, 다른 라운드는 `-- --round=r05`). 실제 R01 전투·카메라·HUD·입력이 그대로 돌고 그림만 바뀐다. 저장은 `user://art_preview/save.json`만 쓴다.
- **실제 바꾼 파일(전부 새 파일, 기존 파일 수정 없음)**
  - `tools/art/release_slice/` — `lib.py`(덩어리·재질 램프·질감), `bases.py`(두 기지 3상태×2프레임), `backdrop.py`(전장 조각 14개), `build.py`(아틀라스·매핑), `sheets.py`(증거 시트)
  - `assets/art/release_slice/` — `slice_atlas.png`(1024×1024, 사용 562행), `slice_atlas.json`, `integration.json`
  - `src/art_preview/` — `slice_backdrop.gd`, `slice_adapter.gd`, `slice_preview.gd` · `scenes/art_preview/slice_preview.tscn` · `tests/art_preview/capture_slice.gd`
  - `docs/art/release_slice/` — 이 문서, `STYLE.md`, `INTEGRATION.md`, `captures/`
- **재생성**: `python tools/art/release_slice/build.py` → 캡처 `godot --path . --resolution 640x360 -s tests/art_preview/capture_slice.gd -- --out=<절대경로> --mode=after|before [--frames=8]` → `python tools/art/release_slice/sheets.py <before> <after> docs/art/release_slice/captures`
- **실제 캡처**: `docs/art/release_slice/captures/` — `pair_*_640x360.png`(왼쪽 기존, 오른쪽 새 아트: home·mid·nest·crowd·melee·damaged_home·damaged_nest), `pair_melee_480x270.png`·`pair_melee_1280x720.png`, `after_home|nest_480x270|1280x720.png`, `gray_melee_640x360.png`, `strip_melee_640x360.png`(엔진 출력 8프레임). 모두 실제 게임 렌더다. Python 합성본은 넣지 않았다.
- **캡처 방식**: Windows Godot 4.7.2 `opengl3`, `heavy_run_detached.ps1` 잠금, 별도 APPDATA. 가상 디스플레이가 없어 창을 두 모니터 밖 좌표(`--position 6000,6000`)에 만들었다. 화면에는 보이지 않지만 창 자체는 생성된다(포커스 이동 여부는 확인하지 못함).
- **만든 것**: A 전장 세트(하늘·원경 마을·밀밭/오염 밭·길·기지 주변), B 두 기지 정상·손상·붕괴.
- **만들지 않은 것**: **C 캐릭터 3종(영웅·식빵병·곰팡이 졸개)은 기존 그림 그대로다.** D 타이틀 구성안, 참고작 조사 문서, 드로우콜 실측, 흑백 외의 색각 확인. 붕괴 상태는 스프라이트만 있고 전투 중 캡처가 없다(체력 0이면 전투가 끝난다).
- **미검증**: 사람이 본 미술 판단, 임포트된 텍스처 경로(지금은 PNG 직접 디코드), 내보낸 빌드, Linux, 실제 플레이 중 성능. 테스트 스위트는 돌리지 않았다(기존 코드 변경 없음).
- **가장 약한 장면**: 중앙의 오염 경계(`pair_melee`, `pair_mid` 오른쪽). 밭 구조는 이어지지만 회색 면이 넓고 평평하다. 그다음은 제분소 날개와 `제분소` 표지판이 겹치는 것, 길 돌무늬가 256px마다 반복되는 것.
- **통합 접점**: `INTEGRATION.md`. 요약 — `Atlas.anim_sets`의 `base_player`/`base_enemy`를 새 페이지로, `battle_view.environment`를 `slice_backdrop.gd`로 교체. 기본 실행에는 아직 적용되지 않는다.
- **다음에 열 파일**: `tools/art/release_slice/backdrop.py`의 `_fields`·`mid_edge`(오염 경계), 그다음 캐릭터는 `tools/art/chars_fable.py`의 계약(프레임 수·피벗)을 읽고 `tools/art/release_slice/chars.py`를 새로 만든다.
- **라이선스**: 외부 에셋·이미지 도구 없음. 모든 그림은 이 저장소의 Python 생성기(`tools/art/release_slice/*.py`, numpy·Pillow)가 만든다.
