# 11-code-review handoff
Updated: 2026-11-01 08:59 +09:00
Session: sess_9129b680-f80d-45db-bb67-9ead14c05df8 (claude-opus-5.5)
Assignment: 사용자 승인(2026-11-01 08:27 KST '창 추가해')으로 연 11번 창. 코드를 읽기만 해서 플레이어가 겪을 결함을 찾는다.

## Rules acknowledged
- Read: BRIEF.md, OWNERSHIP.md(Review expansion), GIT_WORKFLOW.md, QUALITY_REVIEW.md, Publish-Task.ps1, docs/contracts/ENGINE.md·INTERFACES.md(작업 트리의 v2.0 미커밋 부분 포함), docs/design/DECISIONS.md, docs/verification/BUG_REGISTER.md·OPEN_DEFECTS.md.
- Godot·편집기·import·export·에뮬레이터·adb·Gradle·heavy_run 금지. 이번 작업은 파일 읽기, rg, git, 가벼운 Python 스크립트만 썼다.
- 소유 경로 밖 파일은 고치지 않았다. 커밋은 Publish-Task.ps1 -Role 11-code-review로 내 파일만. SHA는 git ls-remote로 확인한 값만 적는다.
- 라운드 재잠금(save.gd 506~517행)과 UI의 `unlocked_round` 읽기는 10·02 작업이라 제외했다.
- 사용자 결정: Q1 테마 A, Q2 수익 모델 보류(광고·결제·상점 UI 금지), Q3 '빵집 기사단: 곰팡이 디펜스', Q4 '빵집 기사단', Q5 난이도 B안. 사용자에게 직접 묻지 않는다(필요하면 01 요청).

## Done: REVIEW_01 (정적 리뷰 1차)
- 기준 HEAD cb64e7f. src/core·gameplay·ui, data, scenes는 85d22bd와 같다.
- 읽은 파일: src/core(app, save, content, atlas, perf, events), src/gameplay(battle_sim 전체, battle, battle_view, tutorial_director), src/ui(hud, hud_top, hud_layout(HEAD), touch_button, ui_screen, result, main_menu, round_select, upgrade_panel, settings_panel, notice_dialog, title_block, safe_area, dim_layer, ui_text, ui_style 일부, threat_marker), data 전체(units, hero, skills, rounds r01~r10, order, economy, game_config, meta, text ko/en), scenes(main, hud), src/services/services.gd·save_bridge·service_store(동결 확인).
- 스크립트 검사(근거, 결과 0건): 코드가 읽는 텍스트 키 vs ko/en, ko/en 자리표시자 개수, data 참조(유닛·anim_set·투사체·fx·바이옴), 경제 합계(첫 클리어 3,140, 3별 780, 강화 5,595), 나눗셈·배열 위험 패턴.
- 결과: 새 P1 0, 새 P2 0. P3 5건. CR-001 함성이 공격 속도도 올림(설명에 없음), CR-002 프레첼 "원거리병을 노립니다" 문구와 달리 가장 가까운 적을 침, CR-003 r07 효모 경고가 효모 생성(18.37초) 전 1~9초에 뜨고 끝남, CR-004 결과 화면 시간 표시는 내림인데 시간 별은 엄격 비교, CR-005(가능성) 180° 회전 때 안전 영역 미갱신.
- 겹침(새 ID 없음, 근거만 추가): 저장 실패 뒤 결과 화면(10 → 코디네이터 15:59 → 04, P3), 메뉴 토스트 미표시(10 v0.21).
- 요청: 소유자 요청 없음(확정 P1·P2 없음). coordination/requests/11-code-review-to-07-qa.md R1(CR-005 재현, 낮은 우선순위, 기존 세션 있을 때만).
- 미검증: 화면 캡처나 실행 근거는 없다. 증상은 코드와 data에서 계산한 결과다.

## Commit/push
- 0df3dcccb443b144fce9e65b75d497f99c95475a [Docs] 정적 코드 리뷰 1차(REVIEW_01) — PUSHED. 확인: `git ls-remote origin refs/heads/main` = 3821f78…(다른 역할 커밋이 뒤에 쌓임), `git merge-base --is-ancestor 0df3dcc origin/main` rc=0. 파일 4개(REVIEW_01.md, status, handoff, 11-code-review-to-07-qa.md)만 포함.
- 이 SHA 기록 갱신 커밋의 SHA는 다음 handoff 갱신 때 적는다.

## Next
1. 07의 CR-005 재현 결과를 받으면 REVIEW_01에서 확정 또는 종료로 바꾼다.
2. 02 v2.0(재잠금·유닛 표시) 커밋이 들어오면 그 변경분만 다시 읽는다(재잠금 판단 자체는 10·02 몫).
3. 2차 범위 후보: src/audio(05), src/gameplay/fallback_*·bot_player, scenes/** 노드 설정.
4. 사용량 97%(usage.json/triggered.json)에 닿으면 새 일을 멈추고 이 파일에 진행·미완료·다음 단계를 적는다.

## Last processed
- Decisions: DECISIONS.md D1~D40 + D38/D40 correction, Q1~Q4 기록 + 사용자 지시의 Q5 B안.
- Requests: 11 앞으로 온 요청 없음(coordinator-to-11-code-review.md 없음).
