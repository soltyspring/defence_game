# 빵집 기사단 — Claude Code 작업 지도

Godot 4.7.2 / GDScript 가로 라인 디펜스. 영웅을 직접 움직이면서 전투용 밀가루로 제빵사와 병사를 쓰고, 전투 보상 골드로 영구 강화한다. 본편 R01–30, 엔딩 뒤 도전 R31–40이 있다.

- 구체적인 작업은 사용자 요청이나 `프롬프트.md`가 정한다. 이어 하는 작업은 `docs/design/FABLE_HANDOFF.md`에서 마지막 검증·미완료·다음 시작점을 확인한다. 큰 문서를 이 파일에서 자동으로 불러오지 않는다.
- 시작할 때 `git log -1 --oneline`과 수정 후보 경로의 `git status --short -- <경로들>`만 확인한다. 이어 하는 작업에서 기준 커밋이 달라졌으면 해당 경로의 `git diff --stat <기준>..HEAD -- <경로들>`과 미커밋 diff만 확인한다. 기준 커밋을 찾을 수 없으면 현재 심볼과 필요한 데이터만 확인한다.
- 아래 표에서 **지금 하는 한 항목**을 골라 `rg -n`으로 심볼을 찾고 해당 함수와 호출부부터 읽는다. 기본 시작 범위는 핵심 파일 2–4개다. 구현에 필요한 의존성, 충돌, 실패가 확인되면 범위를 넓힌다. `build/`, `.godot/`, 전체 라운드 JSON, 장문 기록과 캡처는 미리 훑지 않는다.
- 같은 파일이나 로그를 다시 읽기 전 변경 여부를 확인한다. 테스트 출력은 요약과 첫 실패 구간부터 본다. 이전 검증은 기준선으로 재사용하고, 이번 변경에 영향을 받는 검사는 다시 실행한다.
- 작업을 넘길 때 기존 인수인계를 덮어 갱신한다. 최신 기준 SHA, 끝난 일, 실행한 검증, 다음에 열 파일·함수만 남긴다. 이전 진행 기록을 누적하지 않는다.

| 작업 | 먼저 볼 곳 |
| --- | --- |
| 부활 표시·입력 | `src/ui/hud.gd`의 `_on_snapshot`·`_layout`, `src/ui/hud_layout.gd`의 `compute`. 실제 사망/부활 이벤트가 필요하면 `src/gameplay/battle.gd`의 `_drain_events`. |
| 라운드·적 기믹 | 대상 `data/rounds/rNN.json`, `data/units/units.json`의 관련 ID. 규칙은 `battle_sim.gd`의 `_step_heavy`, 화면은 `battle_view.gd`의 `_draw_telegraphs`. |
| 해금·상점·경제 | `src/core/app.gd`의 `start_round`, `src/core/save.gd`의 `is_unlocked`·`buy_preview_gold`, `src/core/gold_shop_catalog.gd`. 가격/강화 수치만 필요하면 `data/meta.json`의 관련 ID. |
| 사운드 | `src/gameplay/battle.gd`의 `_drain_events`, `assets/audio/audio_manifest.json`의 관련 큐, `tools/audio/synth.py`의 해당 레시피. |

데스크톱 창을 조작하지 않고 실제 플레이어 저장과 다른 작업자의 변경을 보존한다. 검증과 푸시 규칙은 [AGENTS.md](AGENTS.md)를 따른다.
