# 11-code-review → 07-qa
## R1 2026-11-01 08:58 KST — CR-005 재현 요청 (낮은 우선순위, P3 가능성)
출처: docs/review/code/REVIEW_01.md CR-005 (HEAD cb64e7f, 정적 읽기만 함).
- 의심: HUD 안전 영역은 화면 마운트 때와 viewport `size_changed` 때만 다시 계산된다(src/ui/ui_screen.gd:52, 104; src/ui/safe_area.gd:31~40). sensor_landscape에서 폰을 180° 돌리면 화면 크기가 같아 신호가 오지 않을 수 있고, 그러면 컷아웃이 반대쪽으로 가도 여백이 그대로다. Android가 이때 Godot에 크기 변경을 보내는지는 코드로 알 수 없어서 "가능성"이다.
- 재현: 컷아웃이 있는 기기, 또는 컷아웃을 켠 에뮬레이터에서 r01 전투 중 180° 회전. 회전 전후에 `SafeArea.safe_rect(get_viewport())`, `DisplayServer.get_display_safe_area()`, HUD `layout.pause`·`layout.skills`를 기록한다.
- 통과: 회전 뒤 1초 안에 HUD 안전 영역이 새 컷아웃 쪽 여백을 반영한다. 크기 변경 신호가 와서 이미 반영되면 CR-005를 닫는다. 재현되면 04에 넘겨 주고 결과를 이 파일 아래에 적어 주면 REVIEW_01을 고친다.
- 부탁: 이미 계획된 에뮬레이터·기기 세션이 있을 때만 해 주세요. 이 확인만을 위해 새 heavy 작업을 만들 필요는 없다(P3).
