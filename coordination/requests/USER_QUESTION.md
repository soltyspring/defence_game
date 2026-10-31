# USER_QUESTION (asked in CLI 01, one at a time)

## Q1 — 테마/캐릭터: ANSWERED 2026-10-31 09:03 KST
User's words: "모두 고치고 A) 빵집 기사단 vs 곰팡이 군단이걸로". DECIDED = A 빵집 기사단 vs 곰팡이 군단.

## Q2 — 수익 모델: DEFERRED 2026-10-31 16:09 KST
User's words: "수익모델은 보류". None of A/B/C is approved. Ads and payments stay disabled.

## Q3 — 게임 제목: ANSWERED 2026-10-31 16:19 KST (Codex chat)
User's words: "빵집 기사단: 곰팡이 디펜스". DECIDED = B as the working title. The final store name waits for a manual KIPRIS check (classes 9/41).

## Q4 — 홈 화면 이름: ANSWERED 2026-10-31 17:19 KST (Codex chat)
User's words: "빵집 기사단". DECIDED = A: ko "빵집 기사단", en "Bakery Knights". The in-game and store titles stay the full working title. 02 applied it in 4b5926d.

## Q5 — 일반 플레이어 난이도 목표 (ASKED 2026-10-31)
Status: WAITING FOR USER ANSWER
배경: 전략을 깊게 쓰지 않는 플레이어를 흉내 낸 테스트 봇은, 첫 클리어 보상으로만 강화했을 때 5라운드(첫 보스)와 10라운드(마지막 보스)를 10번 중 한 번도 못 깹니다. 실력 있는 봇은 10번 모두 깹니다. 누구를 기준으로 난이도를 맞출지 정해야 합니다.
질문: 일반 플레이어가 강화를 조금만 했을 때, 5라운드와 10라운드를 어떻게 깨게 할까요?
A) 대부분 첫 시도에 깬다 (쉬움)
   막히는 순간이 거의 없습니다. 강화의 의미가 약해집니다.
B) 2~3번 시도하고 강화를 사면 깬다 (추천)
   한 번 막히고, 앞 라운드를 다시 해서 강화를 사면 넘어갑니다. 지금 설계(5라운드에서 처음 막힘)와 맞습니다.
C) 숙련 플레이어만 깬다 (어려움)
   도전적이지만, 일반 플레이어가 5라운드에서 그만둘 위험이 큽니다.
추천: B. 5라운드에서 "막혔다 → 강화했다 → 넘었다"를 한 번 겪게 하는 것이 강화 시스템의 목적입니다.
답변 전 기본값: B에 해당하는 내부 목표(D28)로 조정합니다. 일반 봇 기준으로 5라운드는 첫 클리어 강화만으로 10번 중 3번 이상, 앞 라운드 2번 재플레이 후에는 7번 이상 이기게 합니다. 기본값은 사용자 승인이 아닙니다.
