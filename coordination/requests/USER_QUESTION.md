# USER_QUESTION (asked in CLI 01, one at a time)

## Q1 — 테마/캐릭터: ANSWERED 2026-10-31 09:03 KST
User's words: "모두 고치고 A) 빵집 기사단 vs 곰팡이 군단이걸로". DECIDED = A 빵집 기사단 vs 곰팡이 군단 (DECISIONS.md Q1).

## Q2 — 수익 모델 (PREPARED, asked in CLI 01 after Q1)
Status: WAITING FOR USER ANSWER
질문: 게임으로 어떻게 수익을 낼까요?
A) 무료 + 선택형 보상 광고(결과 화면 골드 2배, 기지 수리 1회) + 광고 제거·후원 팩 1회 구매 (추천)
   과금 없이 1장을 끝까지 깰 수 있습니다. 광고 SDK, 동의 화면, 결제·구매 복원 작업이 필요합니다.
B) 유료 앱(처음에 한 번 구매)
   광고·결제 기능이 필요 없어 가장 단순합니다. 대신 설치 수가 적을 가능성이 큽니다.
C) 1장 무료 + 이후 장(챕터) 1회 구매
   광고 없이 콘텐츠에만 돈을 받습니다. 2장 콘텐츠가 먼저 있어야 합니다.
추천: A. 근거: docs/design/ECONOMY.md §4, RELEASE_DESIGN_REVIEW.md §4.
확률형 뽑기(가챠)는 공정 진행 원칙과 확률 공개 의무 부담 때문에 선택지에서 뺐습니다.
답변 전 기본값: 모든 광고·결제 기능은 꺼진 상태로 유지합니다(06 mock만). 기본값은 사용자 승인이 아닙니다.
