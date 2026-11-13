# Fable 작업 이어받기

**기준: 이 문서를 담은 커밋(2026-11-14, `origin/main`에 푸시).** 직전 기준 `1a5b4cb`. 이 기록은 마지막 기준선이며 현재 작업 트리의 검증을 대신하지 않는다. 작업이 이어지면 이 문서를 최신 상태로 교체한다.

- **원칙(2026-11-14 사용자)**: 새 그림은 ChatGPT가 그린다. Fable은 참고 이미지와 `PROMPTS.md` 키트를 만들고, 돌아온 그림을 정리(격자·자홍 배경 제거·팔레트·자르기)해서 아틀라스로 연결한다. 기존 그림 연결·색 보정·코드로 그리는 테두리·그림자·UI 동작은 Fable이 직접 한다.
- **그래픽 개선 8항목 상태**
  1. 다시 그린 보스·도전 적·유닛 연결 — 끝(`d542fb5`).
  2. 새 스킬 효과 — 끝: GPT 그림 연결(아래 GPT 그림 항목).
  3. 챕터별 적 둥지 — 끝: GPT 그림 10종 연결.
  4. 눈 배경 유닛 가독성 — 끝: `battle_view.gd`의 1px 어두운 테두리(`HALO_OFFSETS`·`_halo_a`, 밝은 챕터에서 진하게 `_bright_chapter`)와 계단형 발밑 그림자.
  5. 길가 소품 — 끝: GPT 그림 5테마 × 8개 연결.
  6. 카드바·상단바 연출 — 끝: `src/ui/hud_skin.gd`(미리보기 폴더에서 옮김)를 `hud.gd`의 `_build`가 붙인다. 버튼을 다시 그리지 않고 겹친 레이어 두 개(`HudCardSkin`·`HudTopSkin`)가 상태가 바뀔 때만 다시 그린다(08 H15 테스트).
  7. 공격 예고 — 끝: `battle_view.gd`의 `_draw_telegraph_zones`(유닛 아래 줄무늬 위험 구역, 양끝에서 조여드는 충전) + `_draw_telegraphs`(유닛 위 얇은 진행선, 넘침 표시).
  8. 타격 효과 — 끝: GPT 그림 연결. 결과 화면 — 끝: `result.gd`의 `_draw_crown_stars`(받침 탭 위 큰 별이 하나씩 착지), `_counted_coins`(보상 카운트업), 패배 시 붉은 테두리.
- **GPT 그림**: 원본 시트 `docs/art/gpt_sources/{skillfx,hitfx,nest,props}/`, 변환 `python tools/art/gpt_import.py`(자홍·격자선 제거 → 도트 위상 찾기 → 블록 중앙값 축소 → 40색 정리 → 프레임 자르기·포장, 미리보기 `docs/art/gpt_sources/preview_*.png`). 결과 `assets/art/gpt/`:
  - `gpt_fx`(그룹 fx): `skill_*` 7종, `hit_spark`·`hit_spit`·`explosion`·`death_poof`·`dust`·`spawn`. 매니페스트 `anim_sets`가 이 페이지를 가리켜 `battle_view._draw_fx`가 그림으로 그린다. 구역 스킬(`TILED_FX`: 오븐 16px, 얼음 44px 간격)은 구역 폭만큼 반복. 시뮬레이션이 만들지 않는 생성 연기·적 쓰러짐·영웅 출발 먼지·침 튐은 `_track_vfx`/`_draw_vfx`가 화면에서만 그린다(시뮬레이션 불변).
  - `gpt_nest_c01`–`c10`(그룹 nest): `base_enemy_cNN`. `battle.gd`가 이 라운드 챕터 페이지만 적재(`ViewS.nest_set`), `_draw_base`가 적 기지에 쓴다(뒤집지 않음).
  - 기력 스킬 아이콘 7종: 원본 `docs/art/gpt_sources/skillicon/skill_icons.png`(약 40px 격자로 그려 와서 블록 축소 대신 24×24 Lanczos + 아이콘별 24색 맞춤, `python tools/art/gpt_import.py icons`) → `assets/art/skills/<id>.png`. `UiStyle.SKILL_BADGES`가 `ui_icon`과 `icon_texture`(전투 HUD가 넘기는 ui_main 프레임) 둘 다에서 이 파일을 쓰게 한다. 옛 생성기 `tools/art/release_slice/skill_icons.py`는 쓰지 않는다.
  - `gpt_props`: `painted_chapter_backdrop.gd`의 `Props`가 챕터 테마(`PROP_THEME`)의 소품 8개를 무작위 배치·좌우 반전으로 그린다. 시트가 없으면 이전 코드 도형.
- **실행한 검증**(Windows Godot 4.7.2, 격리 APPDATA, 창은 보조 모니터 `--screen 1`): UI 3,419/3,419, UI 통합 49/49, 캠페인30 351/351, 캠페인100 973/973, 도전 핵심 251/251, 챕터 배경 721/721, 스킬 캡처 CHECK 11/11, acceptance PASS 155 · FAIL 1(MON-01 iap_catalog, 이전부터). 캡처: 챕터별 R5–R95 둥지·소품, 스킬 4종, R8·R57 병력.
- **미확인**: 사람 손으로 본 예고 가독성과 카드 반짝임 빈도, 1280×720 이상 해상도 캡처, Android 실기.
- **다음 시작점**: 사람 손으로 본 효과 크기·빈도 의견 반영. GPT 시트를 바꾸면 `tools/art/gpt_import.py`만 다시 돌린다.
