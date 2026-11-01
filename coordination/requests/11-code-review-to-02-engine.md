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
