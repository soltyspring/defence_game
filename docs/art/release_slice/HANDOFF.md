# 대표 화면(R01) 아트 — 인수인계

- **기준 SHA**: `9999750` 위에서 작업(2026-11-12). 캡처 당시 작업 트리에는 Codex의 미커밋 변경이 있었다(`src/gameplay/backdrop_scenes.gd`, `battle_view.gd`, `assets/backgrounds/ansimuz/` 등). ‘이전’ 화면은 그 트리의 기존 아트다.
- **실행**: `godot --path . res://scenes/art_preview/slice_preview.tscn` (기존 아트로 보려면 `-- --slice=off`, 다른 라운드는 `-- --round=r05`). 실제 R01 전투·카메라·HUD·입력이 그대로 돌고 그림만 바뀐다. 저장은 `user://art_preview/save.json`만 쓴다.
- **실제 바꾼 파일(전부 새 파일, 기존 파일 수정 없음)**
  - `tools/art/release_slice/` — `lib.py`(덩어리·재질 램프·질감), `bases.py`(두 기지 3상태×2프레임), `backdrop.py`(전장 조각 14개), `build.py`(아틀라스·매핑), `sheets.py`(증거 시트), `chars.py`(캐릭터 3종), `chars_sheets.py`(캐릭터 증거 시트)
  - `assets/art/release_slice/` — `slice_atlas.png`(1024×1024, 사용 562행), `slice_atlas.json`, `integration.json`
  - `src/art_preview/` — `slice_backdrop.gd`, `slice_adapter.gd`, `slice_preview.gd` · `scenes/art_preview/slice_preview.tscn` · `tests/art_preview/capture_slice.gd`
  - `docs/art/release_slice/` — 이 문서, `STYLE.md`, `INTEGRATION.md`, `captures/`
- **재생성**: `python tools/art/release_slice/build.py` → 캡처 `godot --path . --resolution 640x360 -s tests/art_preview/capture_slice.gd -- --out=<절대경로> --mode=after|before [--frames=8]` → `python tools/art/release_slice/sheets.py <before> <after> docs/art/release_slice/captures`
- **실제 캡처**: `docs/art/release_slice/captures/` — `pair_*_640x360.png`(왼쪽 기존, 오른쪽 새 아트: home·mid·nest·crowd·melee·damaged_home·damaged_nest), `pair_melee_480x270.png`·`pair_melee_1280x720.png`, `after_home|nest_480x270|1280x720.png`, `gray_melee_640x360.png`, `strip_melee_640x360.png`(엔진 출력 8프레임). 모두 실제 게임 렌더다. Python 합성본은 넣지 않았다.
- **캡처 방식**: Windows Godot 4.7.2 `opengl3`, `heavy_run_detached.ps1` 잠금, 별도 APPDATA. 가상 디스플레이가 없어 창을 두 모니터 밖 좌표(`--position 6000,6000`)에 만들었다. 화면에는 보이지 않지만 창 자체는 생성된다(포커스 이동 여부는 확인하지 못함).
- **만든 것**: A 전장 세트(하늘·원경 마을·밀밭/오염 밭·길·기지 주변), B 두 기지 정상·손상·붕괴, **C 캐릭터 3종**(영웅 `hero_captain`, 식빵병 `melee_basic`, 곰팡이 졸개 `e_grunt`).
- **캐릭터(2026-11-13)**: `tools/art/release_slice/chars.py` → `assets/art/release_slice/slice_chars.png`(512×512, 사용 352행)·`slice_chars.json`. 프레임 크기·피벗·프레임 수는 빌드가 `assets/atlases/char_player.json`과 대조해 다르면 실패하고, fps·loop·`hit_frame`·events는 그 파일에서 그대로 복사한다(영웅 공격 6프레임 타격 3, 식빵병 5프레임 타격 2, 졸개 4프레임 타격 2). 전장·기지 페이지(`slice_atlas.*`)는 건드리지 않았다. 어댑터는 `Adapter.apply(app, atlas, chars)`로 켜고 끈다(`slice_preview.tscn -- --chars=off`).
  - 캡처: `captures/chars/` — `pair_home|crowd|grunts|melee|duel_640x360.png`(왼쪽 기존 캐릭터, 오른쪽 새 캐릭터, 전장은 둘 다 새 아트), `zoom_piles_3x.png`(식빵병 8명·졸개 8명·혼전 3배 확대), `strip_duel_old|new.png`(엔진 출력 12프레임, 공격 준비→접촉→회복).
  - 8명 밀집 확인 결과: 8명을 21px 안에 세우면 게임 대형이 3줄로 겹쳐 그리므로 기존·새 그림 모두 얼굴은 앞줄만 보인다. 새 그림에서 구분되는 것은 줄마다 겹친 머리의 경계(식빵 껍질 테두리+붉은 머리띠, 졸개의 갓 윗면)와 무기 방향(위로 선 빵칼, 앞으로 뻗은 갈고리)이다. 8개를 하나씩 셀 수는 없다.
  - 약한 점: 식빵병 무더기에서 칼날 여러 개가 왼쪽 위에서 엇갈려 지저분하다. 졸개는 겹치면 눈이 앞줄만 보인다. 사망 프레임은 선 자세를 회전한 것이라 가장자리가 거칠다. 영웅 `cast`는 밀대를 세워 드는 동작뿐이다.
- **만들지 않은 것**: D 타이틀 구성안, 다른 라운드, 일꾼(`worker`)·다른 병과·보스, 참고작 조사 문서, 드로우콜 실측, 흑백 외의 색각 확인. 붕괴 상태는 스프라이트만 있고 전투 중 캡처가 없다(체력 0이면 전투가 끝난다).
- **미검증**: 사람이 본 미술 판단, 임포트된 텍스처 경로(지금은 PNG 직접 디코드), 내보낸 빌드, Linux, 실제 플레이 중 성능. 테스트 스위트는 돌리지 않았다(기존 코드 변경 없음).
- **가장 약한 장면**: 중앙의 오염 경계(`pair_melee`, `pair_mid` 오른쪽). 밭 구조는 이어지지만 회색 면이 넓고 평평하다. 그다음은 제분소 날개와 `제분소` 표지판이 겹치는 것, 길 돌무늬가 256px마다 반복되는 것.
- **통합 접점**: `INTEGRATION.md`. 요약 — `Atlas.anim_sets`의 `base_player`/`base_enemy`를 새 페이지로, `battle_view.environment`를 `slice_backdrop.gd`로 교체. 기본 실행에는 아직 적용되지 않는다.
- **다음에 열 파일**: 타이틀은 `src/ui/main_menu.gd`(읽기만)와 `slice_backdrop.gd` 조각 재사용. 캐릭터를 더 다듬을 때는 `tools/art/release_slice/chars.py`의 `toast`(무더기 칼날), `_fall`(사망).
- **라이선스**: 외부 에셋·이미지 도구 없음. 모든 그림은 이 저장소의 Python 생성기(`tools/art/release_slice/*.py`, numpy·Pillow)가 만든다.

## R02–R40 확장(2026-11-13)
- **실행**: `slice_preview.tscn -- --round=r25`처럼 라운드를 고르면 그 라운드 구성으로 나온다. 기본 실행에는 아직 적용되지 않는다(Codex 통합 필요, `INTEGRATION.md`).
- **파일**: `tools/art/release_slice/chapters.py` → `assets/art/release_slice/slice_ch1..4.png/.json`(챕터별 전장 세트·랜드마크)·`rounds.json`(라운드별 하늘색·오염 경계 위치·적 기지 주변·랜드마크). `src/art_preview/slice_backdrop.gd`가 `round_index`로 이를 읽는다. 캡처 `tests/art_preview/capture_rounds.gd`, 시트 `tools/art/release_slice/round_sheets.py`.
- **챕터**: 1 밀밭 마을(가게·울타리·연기가 점점 무너짐), 2 오염 과수원(풍차 원경, 과수원→회색 밭, 수레·상자·압착기), 3 서리길(설산, 얼음 벽, 사일로·굴뚝, 눈 덮인 빵집 마당), 4 둥지 심부(동굴 갈비뼈, 포자 주머니, 기둥·굴, 전진 야영지). 챕터 안에서 오염 경계가 적 쪽에서 아군 쪽으로 다가오고 하늘이 저물거나 어두워진다.
- **캡처**: `captures/rounds/` — `rounds_ch1..4_front.png`(챕터별 10라운드, 실제 게임 렌더 절반 크기), `pair_rNN_*.png`(왼쪽 기존, 오른쪽 새 아트). 120장 전부 실제 게임 렌더(off-screen 창, 별도 APPDATA).
- **안 바꾼 것**: 영웅·식빵병·졸개 외 유닛과 보스, 둥지 기지 스프라이트(모든 챕터 같은 기지), 타이틀. `live_update`는 비어 있어 R40 핵 노출 배경 연출은 기존 `lane_backdrop`의 것이 빠진다.
- **약한 점**: 챕터 2 둥지 앞은 적 기지 스프라이트가 주변 세트를 대부분 가려 `enemy_a/b` 차이가 거의 안 보인다. 챕터 4는 어두운 청록 한 톤이라 라운드끼리 차이가 기둥·굴 정도다. 랜드마크는 라운드마다 2–3개뿐이라 긴 레인(2000px+)에서는 빈 구간이 길다.

## 나머지 일반 유닛 9종·카드 초상(2026-11-13)
- **그림**: `tools/art/release_slice/chars2.py` → `slice_chars2.png/.json`(1024×512). 제빵사(작은 토크·밀가루 자루), 롤빵병(고글 띠 롤빵, 빵 부스러기 투척), 통식빵(긴 식빵+도마 방패), 프레첼(프레첼 기사+비스킷 조랑말), 화덕포(벽돌 화덕 수레+쇠 굴뚝 포), 포자 뱉개(구근 머리+주름 깃), 초파리 떼(파리 3마리), 썩은 멧돼지(곰팡이 갈기·엄니), 부푼 효모(곰팡이 핀 효모 공+도화선, 공격 때 터짐). 크기·피벗·프레임 수·fps·타격 프레임은 `char_player.json`과 대조해 다르면 빌드 실패. 사용처 e_guard/e_runner/e_mortar 등 같은 anim_set을 쓰는 적도 함께 바뀐다.
- **카드 초상**: `tools/art/release_slice/ui_portraits.py` → `slice_ui.png/.json`(ui_main 복사본, `card_*`·`portrait_e_*` 12칸만 교체, 배지 모양·색은 유지). 어댑터 `apply_ui()`가 `ui_main` 페이지 텍스처를 잠시 바꾼다(`start_round` 전에 호출). 통합 시에는 `ui_main.png`의 해당 칸을 교체하면 된다.
- **캡처(실제 게임)**: `captures/units/` — `r15_army_before|after_640x360.png`, `pair_r25_army.png`, `cards_old_top_new_bottom_3x.png`. `units_old_3x.png`·`units_new_3x.png`는 에셋 시트(게임 화면 아님).
- **남은 것**: 보스(곰팡이 장군·부패 대군주와 이를 쓰는 4보스), 도전 적 7종(`char_challenge`), 스킬 아이콘·HUD 패널 프레임, FX(`fx_combat`), 타이틀. 약한 점: 프레첼 기사 몸통(매듭)이 작아 매듭으로 안 읽힌다. 통식빵은 정면이 넓은 상자라 동작이 작다.

## 전투 화면 귀여움 보정(2026-11-13)
- 공통 얼굴 규칙: 눈 2×3 + 왼쪽 위 흰 하이라이트(`chars.py`의 `eye()`), 볼 홍조(`blush()`). 영웅·식빵병·제빵사·롤빵병·통식빵·프레첼(기사·조랑말)·화덕포에 적용. 적은 기존 발광 눈 유지.
- 개별 수정: 롤빵병 고글을 이마로 올려 눈이 보이게, 화덕포는 화덕 자체에 얼굴(눈·볼·입=화구), 프레첼은 매듭 구멍(두 번째 얼굴처럼 보이던 것)을 지우고 창을 비스듬히 들어 조랑말 얼굴이 보이게, 멧돼지 몸의 청록 반점(눈처럼 보이던 것)을 어두운 곰팡이 얼룩으로.
- 캡처: `captures/units/army_3x_before_cute.png`·`army_3x_after_cute.png`(실제 R15 전투 3배 확대), `r15_army_after_640x360.png`.
- 카드 초상: 사용자 의견(기존이 더 귀엽다)에 따라 보류 대상. `slice_ui`는 새 얼굴로 재생성만 했고 전용 초상은 그리지 않았다.
