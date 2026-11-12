# 기존 런타임에 연결하는 방법

개발용 장면은 기존 파일을 고치지 않고 `src/art_preview/slice_adapter.gd`로 연결한다. 기본 게임에 넣을 때 Codex가 고를 수 있는 두 방법이다.

## 지금 동작하는 연결(어댑터, 파일 수정 없음)

| 대상 | 기존 계약 | 어댑터가 하는 일 |
|---|---|---|
| 아군·적 기지 | `assets/atlases/bases.json`의 `base_player`·`base_enemy`: 96×128, 피벗 (48,127), `idle`/`damaged`/`ruined` 각 2프레임, fps 3/5/5 | `Atlas.pages["release_slice"]`를 메모리에 등록하고 `Atlas.anim_sets[...]`를 그 페이지로 돌린 뒤 `_invalidate_recs()`. `battle_view._draw_base()`는 그대로 |
| 영웅·식빵병·졸개 | `assets/atlases/char_player.json`의 `hero_captain`(48×48, 피벗 22,47)·`melee_basic`·`e_grunt`(32×32, 피벗 13,31): 프레임 이름·수·fps·`hit_frame` | `Atlas.pages["release_slice_chars"]`(`slice_chars.png`) 등록 후 세 `anim_sets`를 그 페이지로. `battle_view._draw_unit()`은 그대로 |
| 배경 | `lane_backdrop.gd`: `build(length, ground, biome, player_x, enemy_x, round_index)`, `present(camera, zoom, device_scale, seconds)`, `live_update(...)`, `v2`, `set_texture`, `SET_MILL`, `village_texture` | `view.environment`를 같은 인터페이스의 `slice_backdrop.gd` 노드로 교체 |
| 제분소 | `bakery_supply.gd`가 `environment.set_texture`의 `SET_MILL`(112×112)을 `(mill-56, ground-111)`에 그림 | `slice_backdrop.gd`가 같은 이름으로 새 제분소 영역을 제공 |

판정·능력치·입력·세이브·카메라는 건드리지 않는다. `Adapter.restore(atlas)`가 원래 매핑으로 되돌린다.

## 기본 게임에 넣을 때 필요한 최소 수정안

0. 캐릭터: `assets/manifest.json`의 `atlases`에 `release_slice_chars`(`slice_chars.json`/`.png`, group `character`)를 추가하고 `anim_sets.hero_captain`·`melee_basic`·`e_grunt`를 그 id로 바꾼다. 다른 유닛은 `char_player`에 그대로 둔다. 텍스처 512×512 RGBA8 = 1 MiB 추가.
1. `assets/manifest.json` — `atlases`에 `{"id": "release_slice", "frames": "res://assets/art/release_slice/slice_atlas.json", "image": "res://assets/art/release_slice/slice_atlas.png", "group": "base"}` 추가, `anim_sets.base_player`·`base_enemy`를 `"release_slice"`로. 이유: 기지가 일반 경로로 로드·해제된다.
2. `src/gameplay/battle_view.gd` `setup()` — `environment = Backdrop.new()` 자리에서 R01(또는 밀밭 챕터)일 때 `preload("res://src/art_preview/slice_backdrop.gd").new()`를 쓴다. 이유: 배경 노드 한 줄 교체로 끝난다. 파일을 `src/gameplay/`로 옮길지는 Codex 판단.
3. `slice_atlas.png`를 Godot에서 임포트(`--import`)한다. 지금은 임포트 파일이 없어 `Image.load_from_file`로 읽는다. 내보낸 빌드에서는 임포트가 필요하다.
4. `slice_backdrop.gd`의 `live_update()`는 비어 있다. 보스 연출(`lane_backdrop.gd`의 `Live`)이 필요한 라운드에 쓰려면 그 노드를 자식으로 붙인다.

## 수치

- 텍스처: 1024×1024 RGBA8 한 장 = 4 MiB(8 MiB 목표 이내). 실제 사용은 위쪽 562행이라 1024×576으로 줄일 수 있다(2.25 MiB). 기존 `bases` 페이지(1 MiB)와 `lane_set_v2.png`를 대체한다.
- 그리기: 배경은 캔버스 아이템 6개(하늘·구름·원경·밭·기지 주변·길), 텍스처 한 장. 드로우콜은 실측하지 않았다.
- 레이아웃 값(시차·y·오염 시작 비율)은 `assets/art/release_slice/integration.json`의 `layout`.
