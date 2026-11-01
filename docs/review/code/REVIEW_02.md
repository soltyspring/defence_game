# 정적 코드 리뷰 2차 (11-code-review)
작성: 2026-11-01 09:20 KST, 세션 sess_9129b680-f80d-45db-bb67-9ead14c05df8.
기준: origin/main 140daeb(코드 기준은 ba567f9와 같고, 그 뒤 140daeb가 data/rounds/r01.json 튜토리얼 순서와 data/text를 바꿨다). cb64e7f(1차 기준) 이후 실행에 쓰이는 파일 변경은 data/text ko·en(8e3ef2f, 140daeb), data/rounds/r01.json(140daeb), assets/audio(3821f78), assets/manifest.json disk_bytes(46dd340), assets/branding PNG 3개(1f15719·e3a7756)뿐이다. src/**, scenes/**, project.godot, export_presets.cfg는 그대로다.
방법: 파일 읽기, rg, git, 가벼운 Python(WAV·PNG 헤더, JSON 대조)만 썼다. Godot·편집기·import·export·에뮬레이터·adb·Gradle·heavy_run은 실행하지 않았다.

## 1. 1차 결함 전달 상태
| ID | 심각도 | 전달 | 상태(09:20) |
|---|---|---|---|
| CR-001 함성 공격 속도 | P3 | 01 결정 D42 → 01이 02에 R14(8e3ef2f) | 02 코드 수정 대기 |
| CR-002 프레첼 문구 | P3 | 01 결정 D43, ko/en 문구 수정(8e3ef2f) | 새 문구 "가장 가까운 적을 먼저 칩니다"는 `_find_target`(battle_sim.gd:721) 동작과 맞다. 닫아도 된다 |
| CR-003 효모 경고 시각 | P3 | 11 → 02 R1(ba567f9) | 02 대기 |
| CR-004 시간 표시와 시간 별 | P3 | 11 → 04 R1(ba567f9) | 04 대기 |
| CR-005 180° 회전 안전 영역 | P3 가능성 | 11 → 07 R1(0df3dcc) | 07 재현 대기 |
| CR-006 이펙트 마지막 프레임 잘림 | P3 | 11 → 02 R2(이번 커밋) | 아래 §3 |
| CR-007 이미 한 행동의 안내가 1프레임 깜빡임 | P3 | 11 → 02 R3(이번 커밋), cc 01 | 아래 §3. 140daeb(D44, r01 순서 변경)를 읽다가 찾음 |

## 2. 05·06 최근 커밋이 경로·길이·import 참조를 깨는지
### 2.1 05 3821f78 (폭발음 0.7초 → 0.5초 재생성)
| 확인 | 결과 |
|---|---|
| audio_manifest.json의 모든 variant(48개): 파일 존재, `bytes`, `seconds`(±0.011초), `.import` 존재 | 48개 모두 일치, 문제 0 |
| explosion.wav 헤더 | 모노 16bit 22,050Hz 11,025프레임 = 0.500초, 22,094바이트. manifest `seconds` 0.5·`bytes` 22094와 같다 |
| explosion.wav.import | 이번 커밋에서 바뀌지 않았다. `edit/trim=false`, `edit/loop_mode=0`, `edit/loop_end=-1`, `compress/mode=2`라 길이가 줄어도 어긋나는 샘플 위치 값이 없다 |
| 코드가 길이를 쓰는지 | src/audio/audio_manager.gd는 manifest `seconds`를 읽지 않는다(rg 0건). 스트림은 `ResourceLoader`로 읽는다(:161~162) |
| 신호 이름 | 엔진은 `_fx("explosion")`에서 `explosion` 신호를 낸다(battle_sim.gd:715 효모 자폭, :958·:966 범위 투사체 = 화덕포 포탄). manifest `cues.explosion`이 있다. 짧아진 소리는 화덕포 착탄에도 쓰인다(05 문서는 효모만 언급) |
| 05의 전제(사망 애니메이션 0.5초) | char_player 12세트, boss 2세트의 `death`가 모두 5프레임/10fps 또는 6프레임/12fps = 0.500초. 전제와 맞다 |
판정: 경로·길이·import 참조를 깨지 않는다. 참고: `.godot/imported`가 옛 소리를 가진 작업 트리에서는 다시 import하기 전까지 0.7초 소리가 난다. 이것은 로컬 캐시 문제이고 export나 깨끗한 HEAD 복사본에서 import하는 07 실행에는 해당하지 않는다.

### 2.2 06 최근 커밋 (85d22bd~be150a6)
| 확인 | 결과 |
|---|---|
| 실행 파일을 바꾼 커밋 | 1f15719, e3a7756만. 바꾼 파일은 assets/branding의 launcher_main_192, launcher_adaptive_foreground_432, launcher_adaptive_monochrome_432 PNG 3개이고 이름은 그대로다 |
| 크기 | 192×192, 432×432(배경 포함 4개 모두 RGBA). Godot Android 키 이름(main_192x192, adaptive_*_432x432)과 같다. `.import` 4개 존재, 이번 커밋에서 안 바뀜 |
| 빌드가 이 파일을 쓰는지 | export_presets.cfg에 `launcher_icons/*` 키가 없고 project.godot `config/icon`은 res://icon.svg다. 그래서 06의 새 아이콘은 지금 APK에 들어가지 않는다. 이미 06-services → 02 요청(`06-services-to-02-engine.md` 137~146행)으로 추적 중이라 새 ID를 주지 않았다 |
| UI 아이콘 이름 | 코드가 찾는 ui_main 프레임 22개(card_<유닛> 5, skill_<스킬>·icon_<스킬> 6, 버튼·자원·잠금·둥지·해골·별 11)가 ui_main.json에 모두 있다 |
| 아틀라스 9장 | PNG 실제 크기 = manifest `size` = 프레임 파일 `size`, 애니메이션이 가리키는 프레임 누락 0, `disk_bytes` = 파일 크기, `.import` 모두 존재 |
판정: 경로·크기·import 참조를 깨지 않는다.

### 2.3 01 140daeb (문구 통일, r01 튜토리얼 순서)
- 코드가 읽는 텍스트 키·data 키는 ko/en에 모두 있고(빠진 키 0, 한쪽에만 있는 키 0), `%d`·`%s`·`{…}` 자리표시자도 ko/en이 같다(1차와 같은 스크립트 재실행).
- 순서 변경은 키 이름을 바꾸지 않아 로더·tutorial_director 참조는 깨지지 않는다. 다만 순서 때문에 흔해진 깜빡임이 CR-007이다.

## 3. 대조 중 찾은 결함
| ID | 파일:줄 | 무엇이 잘못되는지 | 플레이어에게 보이는 증상 | 근거 수준 | 재현 방법 | 통과 기준 | 심각도 | 소유자 |
|---|---|---|---|---|---|---|---|---|
| CR-006 | src/gameplay/battle_sim.gd:715, 958, 966, 968, 976~979 · src/gameplay/battle_view.gd:388, 395 · assets/atlases/fx_combat.json(92a1718) | 시뮬이 정한 이펙트 수명이 09의 새 이펙트 애니메이션보다 짧다. 폭발 `explosion` 7프레임/16fps = 0.4375초인데 수명은 범위 투사체 0.35초(958·966), 효모 자폭 0.40초(715). 원거리 타격 `hit_spark` 5프레임/20fps = 0.25초인데 투사체 명중 수명은 0.20초(968). 이펙트는 `t >= dur`에서 사라지고(979) 화면은 `rec_index(rec, t)`로 프레임을 고른다. | 화덕포 착탄 폭발은 마지막(7번째) 프레임이 한 번도 그려지지 않는다. 효모 자폭은 7번째 프레임이 시뮬 1단계(1/60초)만 보인다. 롤빵병·포자 뱉개·기지 탑 명중 불꽃은 마지막(5번째) 프레임이 그려지지 않는다. 폭발과 불꽃이 사라지는 마지막 장면 없이 뚝 끊긴다. 근접 타격(0.25초, 702)·밀대·포격(0.5·0.6초)은 길이가 충분하다. | 코드로 확정(수명·프레임 계산). 눈에 띄는 정도는 가능성 | 화덕포가 있는 r06에서 화덕포 착탄 1회, r07에서 효모 자폭 1회, 롤빵병 명중 1회의 이펙트 프레임 번호를 프레임마다 기록한다(또는 위 수식으로 계산: 1/60초 단계로 수명 0.35초 안의 마지막 t = 0.3333초 → `int(t*16)` = 5, 수명 0.20초 안의 마지막 t = 0.1833초 → `int(t*20)` = 3). | `play` 애니메이션이 있는 이펙트는 수명 동안 모든 프레임이 60fps에서 한 번 이상 그려진다. 숫자로: explosion 수명 ≥ 0.4375초(또는 화면이 수명 전체에 7프레임을 나눠 그림), 투사체 hit_spark 수명 ≥ 0.25초(또는 5프레임 분배). 수명을 늘리는 경우 fx 상한 48 안에서 r08 군중 장면 동시 fx 최대값이 08 기준 안인지 함께 적는다. | P3 | 02(수명·그리기 규칙), 09(cc, 애니메이션 길이) |
| CR-007 | src/gameplay/tutorial_director.gd:50~61, 66, 83 · src/gameplay/battle.gd:229~230 · data/rounds/r01.json:133~134(140daeb, D44) | 튜토리얼 단계는 조건이 맞으면 일단 보여 주고 다음 프레임에 완료를 검사한다. 그래서 행동을 이미 한 단계는 1프레임만 보였다가 사라진다. D44가 r01 순서를 `tut_deploy_unit` → `tut_move_hero`로 바꾼 뒤, 먼저 ◀▶를 눌러 본 플레이어(`moved`는 단계와 관계없이 230행에서 켜짐)에게는 이동 안내가 매번 이렇게 된다. | r01 첫 판에서 영웅을 먼저 움직이고 병사를 보내면, 병사 안내가 사라진 직후 "◀ ▶ 버튼을 누르고 있으면…" 문장이 한 프레임(60fps에서 1/60초) 깜빡이고 사라진다. 같은 일이 일꾼을 먼저 산 뒤의 `tut_buy_worker`, 이미 보낸 병종의 `tut_<x>_unit`, 이미 쓴 스킬의 `tut_skill_<x>`에도 생긴다(D44 전부터 있던 규칙, r01 순서 변경으로 흔한 경우가 됨). | 코드로 확정 | 진행 없는 세이브로 r01 시작 → t = 1~2초 ▶ 누름 → t = 5초 식빵병 카드 → `Events.tutorial_step` 기록. 지금 예상: "tut_deploy_unit"(≈1초) → ""(배치 다음 프레임) → "tut_move_hero" → 다음 프레임 "". | 트리거 순간에 이미 완료 조건이 참인 단계는 표시하지 않고(`tutorial_step` 발신 0회) `done`에만 기록한다. 위 입력에서 "tut_move_hero" 발신 0회, `BattleResult.tutorial_done`에 tut_move_hero 포함. 움직이지 않은 플레이어는 지금처럼 배치 뒤 이동 안내가 이동하거나 20초가 될 때까지 보인다. 다른 라운드 단계의 표시·완료 시각은 그대로. | P3 | 02(규칙), 01(cc, D44) |

## 4. 02 재잠금 수정
원격 main에 올라오지 않았다. 근거: `git log origin/main -- src/core/save.gd`의 마지막 커밋은 52f9fa3(2026-11-01 00:43)이고, 10의 02b5d98 묶음(25건) 이후 02의 save.gd 커밋이 없다. save.gd 506~517행은 1차 때와 같고, 공유 작업 트리의 save.gd도 수정되지 않은 상태다. 그래서 25건별 PASS 예상 표는 만들지 않았다. 02 커밋이 올라오면 그 diff를 02b5d98 기준으로 읽는다.
