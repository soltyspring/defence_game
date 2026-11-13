# Fable 작업 이어받기

**기준: 이 문서를 담은 커밋(2026-11-14, `origin/main`에 푸시).** 직전 기준 `d542fb5`. 이 기록은 마지막 기준선이며 현재 작업 트리의 검증을 대신하지 않는다. 작업이 이어지면 이 문서를 최신 상태로 교체한다.

- **원칙(2026-11-14 사용자)**: 새 그림은 ChatGPT가 그린다. Fable은 참고 이미지와 `PROMPTS.md` 키트를 만들고, 돌아온 그림을 정리(격자·자홍 배경 제거·팔레트·자르기)해서 아틀라스로 연결한다. 기존 그림 연결·색 보정·코드로 그리는 테두리·그림자·UI 동작은 Fable이 직접 한다.
- **그래픽 개선 8항목 상태**
  1. 다시 그린 보스·도전 적·유닛 연결 — 끝(`d542fb5`).
  2. 새 스킬 효과 — GPT 키트 `docs/art/release_slice/skillfx_regen/`. 그림 대기.
  3. 챕터별 적 둥지 — GPT 키트 `docs/art/release_slice/nest_regen/`. 그림 대기.
  4. 눈 배경 유닛 가독성 — 끝: `battle_view.gd`의 1px 어두운 테두리(`HALO_OFFSETS`·`_halo_a`, 밝은 챕터에서 진하게 `_bright_chapter`)와 계단형 발밑 그림자.
  5. 길가 소품 — GPT 키트 `docs/art/release_slice/props_regen/`. 그림 대기.
  6. 카드바·상단바 연출 — 끝: `src/ui/hud_skin.gd`(미리보기 폴더에서 옮김)를 `hud.gd`의 `_build`가 붙인다. 버튼을 다시 그리지 않고 겹친 레이어 두 개(`HudCardSkin`·`HudTopSkin`)가 상태가 바뀔 때만 다시 그린다(08 H15 테스트).
  7. 공격 예고 — 끝: `battle_view.gd`의 `_draw_telegraph_zones`(유닛 아래 줄무늬 위험 구역, 양끝에서 조여드는 충전) + `_draw_telegraphs`(유닛 위 얇은 진행선, 넘침 표시).
  8. 타격 효과 — GPT 키트 `docs/art/release_slice/hitfx_regen/`. 결과 화면 — 끝: `result.gd`의 `_draw_crown_stars`(받침 탭 위 큰 별이 하나씩 착지), `_counted_coins`(보상 카운트업), 패배 시 붉은 테두리.
- **GPT 그림을 받으면**: 효과(2·8)는 칸을 잘라 4배/8배 축소 → 같은 이름의 아틀라스 애니(`skill_flour/play`, `hit_spark/play` 등)로 `assets/manifest.json`에 넣으면 `battle_view._draw_fx`가 코드 도형 대신 그린다. 둥지(3)는 `bases.json`의 `base_enemy` 형식(96×128, idle/damaged/ruined 2프레임)으로 챕터별 세트를 만들고 `_draw_base`에서 챕터로 고른다. 소품(5)은 `lane_backdrop.gd`/`backdrop_scenes.gd`의 근경 소품 그리기를 스프라이트로 바꾼다.
- **실행한 검증**(Windows Godot 4.7.2, 격리 APPDATA, 창은 보조 모니터 `--screen 1`): UI 3,419/3,419, UI 통합 49/49, 캠페인30 351/351, 도전 핵심 251/251, acceptance PASS 155 · FAIL 1(MON-01 iap_catalog, 이전부터). 캡처: R22·R45·R68·R88 눈 배경, R34·R40 예고, R57 병력, 첫 실행 결과 화면.
- **미확인**: 사람 손으로 본 예고 가독성과 카드 반짝임 빈도, 1280×720 이상 해상도 캡처, Android 실기.
- **다음 시작점**: 사용자가 GPT 그림을 넘기면 위 연결 방법대로 처리한다. 그림 없이 할 일은 없다.
