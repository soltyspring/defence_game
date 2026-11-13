# Fable 작업 이어받기

**기준: 이 문서를 담은 커밋(2026-11-14, `origin/main`에 푸시).** 직전 인수인계 기준 `bd8f34b`; 이번 회귀 검사 기준 `dbe3d36`와 후속 수정. 이 기록은 마지막 기준선이며 현재 작업 트리의 검증을 대신하지 않는다. 작업이 이어지면 이 문서를 최신 상태로 교체한다.

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
- **메뉴·강화·출전 UX(2026-11-14 사용자, 구성만 — 그림은 Codex)**
  - 로비: `main_menu.gd`의 `page == "lobby"`가 로고 없는 별도 화면(기사단 본부)이다. 머리줄(뒤로 · 제목 · 골드 · 상점) + 큰 카드 2장, 카드 아래 한 줄(`round_summary`: 다음 라운드·별 / `upgrades_ready`: 지금 살 수 있는 강화 수, 카드 배지에도 표시). `_draw_lobby`, `_layout`의 lobby 블록.
  - 강화: `upgrade_panel.gd`를 왼쪽 목록 + 오른쪽 상세로 바꿨다. 목록 `list_upgrades`(영웅 → 합류 라운드순 캐릭터 → 방앗간), 아직 합류 전 캐릭터도 `R%d에서 합류`로 보인다. 상세 `_draw_detail`: 이름·레벨, 설명, 공격 예시(`Demo` 내부 클래스: 실제 사거리 위치의 허수아비, 투사체, 범위 고리, 현재 레벨 피해 숫자, 15fps로 혼자 다시 그림, 선택한 캐릭터 아틀라스 페이지만 잡았다 놓음), 특성 줄 `traits_text`, 다음 레벨 수치 `stat_lines`. 구매 버튼은 `btn_buy` 하나. 테스트는 대상 ID를 선택한 뒤 단일 `btn_buy`를 누른다. 좁은 화면에서는 구매 버튼 폭과 예시 영역 높이를 줄여 닫기 버튼과 상세 줄에 공간을 준다. 상세 제목과 합류/다음 레벨 문구는 사용 가능한 폭에서 줄인다.
  - 출전: ‘편성’ 용어와 라운드 선택의 편성 버튼을 없앴다. 라운드를 누르거나 이어하기를 누르면 고를 것이 있을 때(`roster.gd`의 `needs_choice`: 유닛 6종 이상 또는 스킬 4개 이상) 출전 준비 화면을 거쳐 시작한다. 결과 화면: 첫 클리어로 캐릭터·스킬이 열리면 `result.gd`의 `_joined_now`·`_draw_joined`가 「새로 합류: …」 띠를 보여 주고, 고를 것이 있으면 다음 라운드 버튼(`_on_next`)이 출전 준비를 거친다. 그 밖의 다음/재도전은 이전 선택 그대로 바로 시작한다.
  - 해금: 확장 5종을 R30 바게트 · R40 마카롱 · R50 고추빵 · R60 도넛 · R70 와플로 옮겼다(`data/units/roster_expansion.json`, `tools/build/generate_campaign100.py`의 `NEW`). 기본 5종은 R1·2·3·4·6 그대로. 캠페인100 테스트는 해금 직전/도달 시점과 R42 출전 준비 진입을 확인한다. 확장 유닛을 실제로 고르는 경로의 난도는 별도 확인이 필요하다.
  - 합류 비용(2026-11-14 사용자): 확장 5종은 라운드에 도달해도 저절로 들어오지 않고 골드로 합류시킨다. `recruit_cost` 바게트 1,000 · 마카롱 1,200 · 고추빵 1,500 · 도넛 1,800 · 와플 2,400(각각 그 라운드 첫 클리어 보상의 약 1.4–1.5배, 직전 10라운드 첫 클리어 골드의 약 16%, 합계 7,900 = R1–100 첫 클리어 골드의 6%). `save.gd`의 `recruit`·`unit_owned`·`unit_recruitable`·`owned_roster`, 저장 키 `progress.recruited`. 합류 전에는 출전 목록(`selected_loadout`·`set_loadout`)과 강화(`_upgrade_locked`)에서 빠진다. 강화 화면에서 해당 행의 버튼이 `합류`가 된다(`upgrade_panel.gd`의 `hire_cost`·`_recruit`). 출전 준비 타일은 `합류 필요`, 결과 화면은 `합류 가능: …`, 로비·결과의 강화 배지는 합류 가능한 캐릭터도 센다. 봇은 합류를 사지 않는다. 가격은 `tools/build/generate_campaign100.py`의 `RECRUIT`와 같이 고친다.
  - 전투 HUD: 재사용 대기는 숫자 없이 버튼 전체가 회색에서 밝아진다(`touch_button.gd` `cd_fade`, 카드 스킨의 진행선 제거). 한 줄 배치(`hud_layout.compute`의 `fit`, 예: 480×270 + 좌우 노치)에서는 스킬·이동 버튼이 카드 높이(56px)를 쓴다. 노치 없는 480×270은 스킬이 오른쪽 세로 줄(40px)로 간다.
  - 2배속(2026-11-14, tower-defense 스킬의 빨리 감기 권고): 전투 HUD 오른쪽 위 `x1/x2` 버튼(`hud.gd`의 `btn_speed`, 영웅 따라가기 버튼과 같은 자리를 쓰고 정찰 중에는 따라가기가 보인다). 설정 `battle_speed`에 저장되고 `battle.gd`의 `player_speed()`가 프레임당 시뮬레이션 스텝 수만 늘린다(고정 스텝·별 시간 기준은 그대로). R1–R2는 항상 x1.
  - 설치한 스킬 기준 점검(2026-11-14): save-systems — 버전·임시 파일·`.bak`·격리·새 버전 저장 읽기 전용까지 이미 충족. audio-design — 버스, 제곱 슬라이더, 덕킹, 리미터, 피치 변주, 보이스 제한 충족(세션 LUFS 실측은 안 함). game-feel — 흔들림은 아군 기지 피격 때만 2–4px이고 끄기 설정 있음, 히트스톱은 없음(미적용). tower-defense — 다음 웨이브 시간 표시는 있고 구성 미리보기는 없음, `td_curve_check.py`는 타워 구매 모델이라 이 게임의 영구 강화 구조에 그대로 맞지 않아 돌리지 않았다.
  - 문구: `data/text/{ko,en}.json`의 `lobby.*`, `upg.*`, `roster.title`(출전 준비)·`roster.save`.
- **그림 키트**: `build/gpt_kits/6_lobby_cards.zip`(라운드 선택·강화 카드 삽화), `build/gpt_kits/7_upgrade_training.zip`(훈련장 배경). 각 ZIP의 PNG 3장과 `PROMPTS.md`를 ChatGPT에 올린다. 결과명은 `lobby_cards.png`, `upgrade_training.png`. 받은 두 시트는 `docs/art/gpt_sources/lobby/`에 기록했고, `python tools/art/import_lobby_art.py`로 자른 카드와 훈련장 배경을 게임에 연결했다. 상단 HUD 추가 아트는 `build/gpt_kits/8_battle_top_hud.zip`으로 요청한다. 밀가루·기력 영역은 그대로 두고 기지 체력·미니맵·배속의 외형만 교체할 예정이다.
- **검증**: 격리 Godot 4.7.2: UI 3,430/3,430, UI 통합 49/49, 서비스 강화 1,256/1,256, 캠페인30 351/351, 캠페인100 미리보기 1,009/1,009, acceptance PASS 157 · FAIL 0 · NOT_TESTED 2(실기 Android와 일부 오디오). 강화 패널 안전영역은 480×270, 640×360, 800×360에서 확인했다. 실결제는 비활성이고 로컬 미리보기 상품만 있는 상태를 MON-01이 구분한다.
- **밸런스 재검증**: 기본 5종, 숙련 봇, 60Hz, 시드 83, 실패 뒤 3,000원 상당 6,000골드 한 번: R36에서 3성 돌파, R60까지 클리어, R61에서 두 번째 팩을 넣어도 미클리어. 누적 가상 6,000원. 이전과 같은 결과이며, 영입에 골드를 쓰거나 새 유닛을 고르는 경로는 포함하지 않는다.
- **남은 확인**: 합류 캐릭터를 쓰는 편성별 밸런스, 480×270 극소형에서 스킬의 48px 폭, Android 실기와 실제 영어 화면의 가독성. 현재 쿨다운은 숫자 없이 밝기로 표시한다.
