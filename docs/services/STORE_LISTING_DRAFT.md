# Google Play store listing draft — ko / en (owner: 06-services)
Version: 1 (2026-10-31). Status: **DRAFT, not submitted.** Theme decided by the user on 2026-10-31 09:03 KST: A "빵집 기사단 vs 곰팡이 군단" (coordinator-to-06-services.md, "USER DECISION … Q1 answered"; docs/design/DECISIONS.md still shows Q1 PENDING until 01 records it). The final title is NOT decided; the candidates below are for 01/user. Unit and hero display names are placeholders until 01 publishes the themed text (data/text/*.json).

Machine-checked by `tests/services/test_services_listing.gd` (lengths, banned wording, emoji, ALL CAPS, keyword repetition, word lists, conditional markers). Only text between `BEGIN`/`END` markers is store text.

## 1. Policy and limits used (official sources, checked 2026-10-31)
| Rule (paraphrased) | Source |
|---|---|
| App name ≤ 30, short description ≤ 80, full description ≤ 4,000 characters; limits count full- and half-width characters the same | https://support.google.com/googleplay/android-developer/answer/9859152?hl=en |
| Repetitive or irrelevant keywords in name/short/full description can lead to suspension | same page; https://support.google.com/googleplay/android-developer/answer/9898842?hl=en |
| Metadata must be accurate and clearly written; no unattributed or anonymous testimonials; no comparisons with other apps or brands; no word blocks or keyword lists | https://support.google.com/googleplay/android-developer/answer/9898842?hl=en |
| Title, icon, developer name: no emojis/emoticons, no repeated special characters, no ALL CAPS unless part of the brand | same |
| No text implying store performance or ranking (e.g. "#1", "best", "popular", awards), price or promotion ("free for a limited time", "% off"), or Play programs ("Editor's choice", "New") | same |
| Listing must suit a general audience; no graphic violence, profanity; screenshots/videos must show the real app; no celebrity names or brand logos without permission | same |
| A contact email is required on the listing; a website is recommended | https://support.google.com/googleplay/android-developer/answer/9859152?hl=en |
Content was rephrased for compliance with licensing restrictions.

House rules on top of policy (06): describe only features that exist in the current build; no play-time or difficulty numbers that are design targets rather than measurements; statements about ads and purchases carry a change marker because monetization is undecided.

## 2. Title candidates (≤ 30 characters; final choice by 01/user)
**Trademark and name-collision search not done** (user/legal). Store search for identical names not done either.

<!-- BEGIN title.ko -->
- 빵집 기사단
- 빵집 기사단: 곰팡이 디펜스
- 빵집 기사단 대 곰팡이 군단
<!-- END title.ko -->

<!-- BEGIN title.en -->
- Bakery Knights
- Bakery Knights: Mold Defense
- Bakery Knights vs Mold Legion
<!-- END title.en -->

## 3. Short description (≤ 80 characters)
<!-- BEGIN short.ko -->
빵 병사를 출동시키고 제빵장을 움직여, 곰팡이 군단으로부터 마을 빵집을 지키세요.
<!-- END short.ko -->

<!-- BEGIN short.en -->
Send bread soldiers, lead the head baker and save the village bakery from mold.
<!-- END short.en -->

## 4. Full description
Markers: `[수익화 결정 시 변경]` / `[CHANGES IF MONETIZED]` = sentence must be rewritten when ads or purchases are turned on. `[이름 확정 대기]` / `[NAMES PENDING]` = placeholder names until 01 text. Remove markers before submission.

<!-- BEGIN full.ko -->
곰팡이 군단이 마을 빵집으로 몰려옵니다. 갓 구운 빵으로 만든 기사단을 이끌고 가게를 지키세요.

한 줄 전장에서 펼쳐지는 디펜스 전투
- 꼬마 제빵사를 고용해 반죽 수입을 늘리고, 모은 반죽으로 병사를 출동시킵니다.
- 지금 병사를 보낼지, 제빵사를 더 고용할지, 강한 병사를 위해 아껴 둘지 고르세요.
- 식빵 기사, 바게트 투척병, 크루아상 방패병 등 다섯 종류의 빵 병사가 각자 다른 적에 강합니다. [이름 확정 대기]

직접 움직이는 영웅, 제빵장
- 제빵장을 앞뒤로 움직여 전선을 지키고, 세 가지 기술로 위기를 넘기세요.
- 쓰러져도 잠시 후 본진에서 다시 나옵니다.

곰팡이 군단의 다양한 적
- 빠른 날파리 떼, 멀리서 포자를 쏘는 적, 단단한 거구, 본진을 노리는 폭탄병, 그리고 두 명의 보스가 기다립니다. [이름 확정 대기]

10개 라운드와 별 3개 도전
- 승리 시간과 본진 체력에 따라 라운드마다 별을 최대 3개까지 받을 수 있습니다.
- 진 라운드는 바로 다시 도전할 수 있습니다.

인터넷 연결 없이 플레이할 수 있습니다.
광고와 인앱 결제가 없습니다. [수익화 결정 시 변경]
<!-- END full.ko -->

<!-- BEGIN full.en -->
The Mold Legion is creeping toward the village bakery. Lead a knightly order of fresh-baked heroes and hold the shop.

Lane defense battles
- Hire little bakers to grow your dough income, then spend dough to send soldiers into the lane.
- Choose every few moments: send troops now, hire another baker, or save up for a stronger unit.
- Five kinds of bread soldiers, such as the toast knight, baguette thrower and croissant shield, each counter different enemies. [NAMES PENDING]

A hero you control: the head baker
- Move the head baker forward or back to hold the line, and use three skills to turn a fight.
- If the hero falls, they return to the base after a short wait.

A varied enemy legion
- Fast fruit flies, spore spitters, armored brutes, bombers that rush your base, and two bosses. [NAMES PENDING]

Ten rounds and three-star goals
- Earn up to three stars per round for winning quickly and keeping your base healthy.
- Retry any lost round right away.

Play without an internet connection.
No ads and no in-app purchases. [CHANGES IF MONETIZED]
<!-- END full.en -->

## 5. Feature claims and their evidence (each claim must stay true)
| Claim | Evidence in repo (2026-10-31) |
|---|---|
| 10 rounds | data/rounds/order.json lists r01–r10 |
| 5 ally unit types, workers/dough income | data/units/units.json (5 player units); economy.json; `cmd_buy_worker` in INTERFACES.md |
| Hero you move, 3 skills, respawn | data/heroes/hero_captain.json, data/skills/ (slam, rally, barrage), GDD §4 |
| Enemy types and 2 bosses | data/units/units.json (5 enemy types, boss_warlord, boss_overlord) |
| Up to 3 stars, instant retry | INTERFACES.md BattleResult `stars`, `cmd_retry` |
| Works offline | export_presets.cfg `permissions/internet=false`; services disabled (test_services_integration D1, D6) |
| No ads, no in-app purchases | services `disabled` mode, no SDK (D1–D5). **Changes if monetized** |
Not claimed on purpose: meta upgrades (applied in battle_sim.gd, but no upgrade screen exists yet), play time per round (design target only), device performance, "family friendly"/age suitability (needs the content rating questionnaire), any comparison with other games.

## 6. Still needed before submission (not 06 decisions)
- Final title and themed unit names (01; user picks the title, one question at a time).
- Trademark / name search (user/legal).
- Contact email (required) and website (user).
- Screenshots and feature graphic from the real build (03/04), content rating questionnaire (user/04).
- en/ko proofreading by a native speaker.
