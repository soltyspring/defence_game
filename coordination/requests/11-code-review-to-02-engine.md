# 11-code-review → 02-engine
## R1 2026-11-01 09:10 KST — CR-003: r07 부푼 효모 경고가 효모보다 먼저 뜨고 끝남 (P3, 코드로 확정)
출처: docs/review/code/REVIEW_01.md CR-003. 기준 origin/main bacb018(src/gameplay·data/rounds는 cb64e7f와 같음). 정적 읽기만 했고 Godot은 실행하지 않았다.

### 무엇이 잘못되는지
- `tut_bomber_warning`에는 전용 조건이 없어 일반 규칙을 탄다: 표시 `return sim.t >= 1.0`(src/gameplay/tutorial_director.gd:79), 끝 `DEFAULT_TIMEOUT` 8초(:17, :102). 끝나면 `done.append(key)`(:58)로 `BattleResult.tutorial_done`에 들어가고 App이 저장하므로 다시 나오지 않는다(setup :36~40이 완료 키를 건너뜀).
- 8초 타이머는 프레임 시간(`get_process_delta_time()`, src/gameplay/battle.gd:231)으로 줄고 일시정지 중에는 0이다.
- r07 첫 `e_bomber`: 트리클 `start` 10, `pattern` [e_grunt, e_bomber, …], `interval` 8.5, `ramp_per_min` 0.8, `interval_min` 6(data/rounds/r07.json:113~124) → 두 번째 트리클 10 + max(6, 8.5 − 0.8×10/60) = **18.37초**, 위치 x = 1900 − 40 − 22 = **1838**(적 둥지 앞). 웨이브 1(r07.json:27, 25초)에도 효모 1기가 있다. r07 `tutorial` = ["tut_bomber_warning"](r07.json:160).
- 결과: 진행이 없는 세이브로 r07을 처음 하면 경고는 t ≈ 1.0초에 뜨고 t ≈ 9.0초에 사라진다. 그때까지 효모는 0기다. D39가 r07 효모를 "못 보고 당함" 위험 지점으로 꼽은 라운드다.

### 재현 입력
- 세이브: `tutorial_done` = []인 새 세이브(격리된 user://).
- 실행: r07, 시드 아무거나(트리클·웨이브 시각은 시드와 무관), 입력 없음(idle)이면 충분.
- 기록: 0~60초 동안 `Events.tutorial_step`(키와 t), `e_bomber`가 처음 `_spawn_enemy`된 t, 그때 카메라 오른쪽 끝(`battle.view.cam_x + view_w/2`)과 효모 x.
- 지금 예상값: "tut_bomber_warning" t = 1.0 ± 1/60초, "" t = 9.0 ± 0.1초, 첫 e_bomber t = 18.37 ± 1/60초, `tutorial_done`에 tut_bomber_warning 포함.

### 통과 기준(숫자)
1. 뜨는 시각: 첫 `e_bomber`가 생성되기 전(현재 data로 t < 18.37초)에는 "tut_bomber_warning"이 뜨지 않는다. 다음 둘 중 하나를 골라 INTERFACES나 tutorial_director 주석에 적는다.
   - (a) 생성 기준: 첫 e_bomber 생성 단계에서 뜬다. 현재 data로 t = 18.37 ± 1/60초.
   - (b) 화면 기준: 첫 e_bomber가 카메라 오른쪽 끝 안(x ≤ 카메라 오른쪽 끝)에 들어온 단계에서 뜬다. idle(영웅이 기지 근처)이면 640×360 화면에서 약 47초(1838 → 550, 45 px/s)다.
2. 남는 시간: 뜬 뒤 최소 5.0초 남는다(`tut_boss_warning`과 같은 5초 이상, 지금 일반 규칙 8초를 써도 된다). 일시정지 중에는 줄지 않는다(지금 규칙 유지).
3. 완료 기록: 경고가 실제로 뜬 전투에서만 `tutorial_done`에 들어간다. 효모가 나오기 전에 전투가 끝나면(패배·다시하기·메뉴) tut_bomber_warning은 `tutorial_done`에 없다.
4. 회귀: r05·r10의 `tut_boss_warning`(boss_seen, 5초)과 다른 키(`tut_<x>_unit`, `tut_skill_<x>`, r01 4단계)의 표시·완료 시각은 지금과 같다. selftest PASS.
- 구현 방법은 02 판단이다. 예: battle.gd `_drain_events`가 이미 보는 생성 이벤트로 `tutorial.enemy_seen[unit_id] = true`를 두고 `tut_<x>_warning`(boss 제외)을 "id나 tag에 <x>가 들어간 적이 나왔을 때"로 일반화하면 앞으로 01이 추가할 경고 키에도 쓸 수 있다(bomber는 id `e_bomber`).
- 재검증은 07(또는 02 headless 시뮬)에 맡긴다. 11은 Godot을 실행하지 않는다.

## R2 2026-11-01 09:25 KST — CR-006: 폭발·명중 이펙트 수명이 애니메이션보다 짧아 마지막 프레임이 안 그려짐 (P3, 코드로 확정)
출처: docs/review/code/REVIEW_02.md §3. 기준 origin/main ba567f9. cc 09-art-world(fx_combat 애니메이션 길이 담당). 정적 읽기만 했다.

### 무엇이 잘못되는지
- 시뮬 이펙트 수명: 효모 자폭 `_fx("explosion", …, 0.4, …)`(src/gameplay/battle_sim.gd:715), 범위 투사체 `_fx("explosion", …, 0.35, …)`(:958, :966), 투사체 명중 `_fx("hit_spark", …, 0.2, …)`(:968). `_step_fx`가 `t >= dur`에서 끈다(:979).
- 화면: `atlas.rec_index(rec, f.t)`로 프레임을 고르고(src/gameplay/battle_view.gd:395), `play`는 반복하지 않는다.
- 09의 fx_combat.json(92a1718): explosion 7프레임/16fps = 0.4375초, hit_spark 5프레임/20fps = 0.25초.
- 계산(1/60초 단계): 수명 0.35초의 마지막 t = 0.3333초 → 프레임 번호 int(0.3333×16) = 5, 7번째(번호 6)는 안 그려짐. 수명 0.40초의 마지막 t = 0.3833초 → 번호 6이 1단계만 보임. 수명 0.20초의 마지막 t = 0.1833초 → int(0.1833×20) = 3, 5번째(번호 4)는 안 그려짐.
- 영향: 화덕포 착탄 폭발과 롤빵병·포자 뱉개·기지 탑 명중 불꽃이 사라지는 마지막 장면 없이 끊긴다. 근접 타격(0.25초, :702), 밀대(0.5초), 포격(0.6초)은 충분하다.

### 재현 입력
- r06(화덕포 있음)에서 화덕포 착탄 1회, r07에서 효모 자폭 1회, 아무 라운드에서 롤빵병 명중 1회. 이펙트가 살아 있는 동안 매 프레임 `rec_index` 값을 기록한다.
- 지금 예상: 착탄 폭발 최대 번호 5, 자폭 번호 6은 1프레임, 명중 불꽃 최대 번호 3.

### 통과 기준(숫자)
- `play` 애니메이션이 있는 이펙트는 수명 동안 모든 프레임이 60fps에서 한 번 이상 그려진다.
  - explosion: 착탄·자폭 모두 번호 0~6이 각각 ≥ 1프레임. 방법 예: 수명 ≥ 0.4375초(+1/60초 여유 → 0.46초), 또는 view가 `k = t/dur`로 7프레임을 수명 전체에 나눠 그림.
  - 투사체 hit_spark: 번호 0~4가 각각 ≥ 1프레임(수명 ≥ 0.25초 + 1/60초, 또는 같은 분배 방식).
- 회귀: 수명을 늘리면 fx 상한 48(`Content.caps().fx`) 안에서 r08 군중 장면의 동시 활성 fx 최대값을 전후로 적는다(08 기준 확인용). 소리 신호(`explosion`·`hit`)의 시각은 바뀌지 않는다(05 동기 기준 DEATH_SYNC_CHECK 유지).
- 수명은 시뮬 결과(피해·판정)에 영향이 없는 화면 값이라 봇 결과는 같아야 한다(selftest 시드 결과 동일).

## R3 2026-11-01 09:30 KST — CR-007: 이미 한 행동의 튜토리얼 안내가 1프레임 깜빡임 (P3, 코드로 확정)
출처: docs/review/code/REVIEW_02.md §3. 기준 origin/main 140daeb. cc 01-director(D44 r01 순서 변경). 정적 읽기만 했다.

### 무엇이 잘못되는지
- `update()`(src/gameplay/tutorial_director.gd:50~61)는 조건이 맞으면 단계를 먼저 표시하고(:51~54, 키를 돌려줌) 다음 호출에서야 `_completed`를 검사한다(:56~61).
- `tut_move_hero`의 조건은 항상 참(:66), 완료는 `moved`(:83). `moved`는 현재 단계와 관계없이 영웅이 움직이면 켜진다(src/gameplay/battle.gd:229~230).
- 140daeb(D44)가 r01 순서를 `tut_deploy_unit`, `tut_move_hero`, …로 바꿨다(data/rounds/r01.json:133~134). 먼저 ◀▶를 눌러 본 플레이어는 병사를 보낸 다음 프레임에 이동 안내가 뜨고, 그다음 프레임에 사라진다(1/60초 깜빡임).
- 같은 규칙으로 일꾼을 먼저 산 뒤의 `tut_buy_worker`, 이미 보낸 병종의 `tut_<x>_unit`, 이미 쓴 스킬의 `tut_skill_<x>`도 1프레임 깜빡인다.

### 재현 입력
- 진행 없는 세이브(`tutorial_done` = []), r01, 입력: t = 1~2초 ▶ 누르고 떼기, t = 5초 식빵병 카드 1회.
- `Events.tutorial_step` 기록. 지금 예상: "tut_deploy_unit"(t ≈ 1초, `moved`로 조건 충족) → 배치 다음 프레임 "" → 같은 또는 다음 프레임 "tut_move_hero" → 그다음 프레임 "".

### 통과 기준(숫자)
- 트리거 순간에 이미 `_completed`가 참인 단계는 `tutorial_step`을 0회 보내고 `done`에만 기록한 뒤 다음 단계로 넘어간다. 위 입력에서 "tut_move_hero" 발신 0회, `BattleResult.tutorial_done`에 tut_move_hero 포함.
- 움직이지 않은 플레이어(입력: t = 5초 카드만)는 지금처럼 배치 뒤 "tut_move_hero"가 뜨고, 이동하거나 20초(ACTION_TIMEOUT)가 되면 사라진다.
- 다른 라운드 단계(r02~r10)의 표시·완료 시각은 지금과 같다. 화면에 한 번이라도 뜬 안내는 최소 1프레임이 아니라 의도한 시간 동안 남는다(이 수정으로 표시 시간이 줄어드는 단계가 없어야 함).
- R1(CR-003, 효모 경고)과 같은 파일이므로 함께 고치면 재검증을 한 번에 할 수 있다.
