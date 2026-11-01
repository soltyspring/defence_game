# 11-code-review → 04-client
## R1 2026-11-01 09:10 KST — CR-004: 결과 화면 시간 표시(내림)와 시간 별 판정(엄격 비교)이 어긋남 (P3, 코드로 확정)
출처: docs/review/code/REVIEW_01.md CR-004. 기준 origin/main bacb018(src/ui/result.gd, src/gameplay/battle_sim.gd는 cb64e7f와 같음). 정적 읽기만 했고 Godot은 실행하지 않았다.

### 무엇이 잘못되는지
- 표시: src/ui/result.gd:87 `var t := float(result.get("time", 0))`, :89 `"%d:%02d" % [int(t) / 60, int(t) % 60]` → 소수점 아래를 버린다.
- 판정: 별 줄은 :137 `won and t <= float(rules.time_3)`, 엔진 별 개수는 src/gameplay/battle_sim.gd:1186 `if t <= float(st.get("time_3", 180.0))` → 버리지 않은 t로 비교한다.
- 결과: 150 < t < 151이면 화면 시간은 "2:30"(150초)인데 "150초 안에 클리어"는 빈 별이다. 엔진과 결과 화면의 별 판정끼리는 같으므로 바꿀 곳은 표시다.

### 재현 입력
- result.tscn에 직접 넣기(07·04 UI 테스트 방식): `{"round_id":"r01","won":true,"stars":2,"time":150.4,"kills":20,"coins":30,"player_base_ratio":1.0,"first_clear":false,"next_round_id":"r02"}`. r01 `stars.time_3` = 150(data/rounds/r01.json:122).
- 지금 예상: 시간 칸 "2:30", 별 줄 3번째 "150초 안에 클리어" 빈 별(`row_markers[2]` = "hollow"), `reason_mismatch` = false.

### 통과 기준(숫자)
- 표시 시간과 시간 별 판정이 같은 반올림 값을 쓴다. 권장: 표시 초 S(t) = `ceili(t)`(올림)로 바꾸고 판정은 그대로(t ≤ time_3) 둔다. 모든 라운드의 `time_3`이 정수(150~380)라서 "t ≤ time_3"과 "ceili(t) ≤ time_3"은 같은 결과가 된다. 엔진 판정을 바꾸면 D24 길이 규칙의 기준이 최대 1초 달라지므로 권하지 않는다.
- 아래 7개 입력(r01, time_3 = 150) 모두에서 "S(t) ≤ 150"과 시간 별 달성이 같아야 한다.

| t | 화면 시간 | 시간 별 |
|---|---|---|
| 149.0 | 2:29 | 달성 |
| 149.99 | 2:30 | 달성 |
| 150.0 | 2:30 | 달성 |
| 150.01 | 2:31 | 미달 |
| 150.4 | 2:31 | 미달 |
| 150.99 | 2:31 | 미달 |
| 151.0 | 2:31 | 미달 |

- 경계 추가 확인: t = 59.5 → "1:00", t = 0.2 → "0:01". `reason_mismatch`는 7개 모두 false.
- 범위: result.gd만. 다른 화면에는 전투 시간 표시가 없다(정적 확인, HUD에는 경과 시간 칸이 없음).
