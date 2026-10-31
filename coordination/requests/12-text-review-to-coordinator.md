# 12-text-review → coordinator: 스토어 문서 발견 (docs/services/**는 Q2 보류로 고치지 않음)
2026-11-01 09:00 KST, 세션 sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2. 읽기만 했다.
| ID | 파일·위치 | 지금 | 게임 안 문구와의 차이 | 제안 (Q2가 풀리거나 06/09가 다시 열 때) |
|---|---|---|---|---|
| S-01 | STORE_LISTING_DRAFT.md `full.ko` "세 가지 기술로 위기를 넘기세요" | 기술 | 게임은 "스킬"(tut_skill_slam "스킬 버튼"); en은 skills | "세 가지 스킬로" |
| S-02 | STORE_LISTING_DRAFT.md `full.ko/en` 마지막 줄 "광고와 인앱 결제가 없습니다. [수익화 결정 시 변경]" / "No ads and no in-app purchases." | 수익 모델에 대한 약속 문장 | Q2는 보류(어느 안도 승인 아님). 이 문장은 보류된 결정을 미리 "없음"으로 공개 약속한다 | 사용자 지시(광고·결제·상점 문구 금지)에 맞춰 Q2 결정 전에는 이 줄을 빼는 쪽을 검토 |
| S-03 | STORE_GRAPHICS.md 표 3번 그림 문구 "반죽을 모아 병력을 구워라" | 반죽 | 자원은 밀가루(D25). 문서 안에도 "wording conflict"로 적혀 있지만 그대로 남아 있음 | "밀가루를 모아 병력을 구워라" 등 |
| S-04 | STORE_LISTING_DRAFT.md "Where config/name still shows" 표(창 제목 Lane Defence, "no window_set_title call"), STORE_GRAPHICS.md "its title still says Lane Defence" | 창 제목이 Lane Defence | 지금 HEAD의 src/core/app.gd `_apply_window_title()`(780c30a)가 창 제목을 `ui.title`로 바꾼다 | 설명을 지금 코드에 맞게 고치기 (데스크톱 user:// 폴더 이름만 Lane Defence로 남음) |
그 밖의 스토어 문구(제빵사·밀가루·제빵 대장·곰팡이 군단·별 3개)는 게임 안 용어와 같다. "Mould Defense"(KIPRIS)는 일부러 넣은 영국식 검색어라 문제 아님.
