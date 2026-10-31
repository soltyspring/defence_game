# Store listing draft — Google Play (and App Store fields) — ko / en (owner: 06-services)
Version: 2 (2026-10-31). Status: **DRAFT, not submitted.**
- Theme: decided by the user 2026-10-31 09:03 KST, A "빵집 기사단 vs 곰팡이 군단" (coordinator-to-06-services.md, "Q1 answered").
- Title: **working title** decided by the user 2026-10-31 16:19 KST (coordinator-to-06-services.md, "Q3 answered"): "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense". The final store name is confirmed only after a person runs the KIPRIS class 9 and 41 search (docs/services/KIPRIS_MANUAL_CHECK.md). **That search has not been done.**
- Unit, hero and enemy names follow 01's text (data/text/ko.json, en.json, `provisional_theme: false`).

Machine-checked by `tests/services/test_services_listing.gd` (lengths, banned wording, brands, competitor phrases, emoji, ALL CAPS, keyword repetition, word lists, conditional markers). Only text between `BEGIN`/`END` markers is store text.

## 1. Policy and limits used (official sources, checked 2026-10-31)
| Rule (paraphrased) | Source |
|---|---|
| Play: app name ≤ 30, short description ≤ 80, full description ≤ 4,000 characters; limits count full- and half-width characters the same | https://support.google.com/googleplay/android-developer/answer/9859152?hl=en |
| Play: repetitive or irrelevant keywords in name/short/full description can lead to suspension | same page; https://support.google.com/googleplay/android-developer/answer/9898842?hl=en |
| Play: metadata must be accurate and clearly written; no unattributed or anonymous testimonials; no comparisons with other apps or brands; no word blocks or keyword lists | https://support.google.com/googleplay/android-developer/answer/9898842?hl=en |
| Play: title, icon, developer name have no emojis/emoticons, no repeated special characters, no ALL CAPS unless part of the brand | same |
| Play: no text implying store performance or ranking (e.g. "#1", "best", "popular", awards), price or promotion ("free for a limited time", "% off"), or Play programs ("Editor's choice", "New") | same |
| Play: listing must suit a general audience; screenshots/videos must show the real app; no brand logos or celebrity names without permission | same |
| Play: a contact email is required on the listing; a website is recommended | https://support.google.com/googleplay/android-developer/answer/9859152?hl=en |
| App Store: app name 2–30 characters; subtitle ≤ 30 characters; privacy policy URL required | https://developer.apple.com/help/app-store-connect/reference/app-information |
| App Store: subtitle should sum up the app and avoid generic claims such as "world's best app"; avoid names too similar to existing apps; do not use other apps' names or trademarks | https://developer.apple.com/app-store/product-page/ |
Content was rephrased for compliance with licensing restrictions.

House rules on top of policy (06):
- Describe only features that exist in the current build.
- No play-time or difficulty numbers that are design targets rather than measurements.
- Statements about ads and purchases carry a change marker, because monetization is deferred by the user (16:09 KST).
- Keep clear of the signature wording of the similar game "Bread Defense / 빵어전" (§7). Do not name it anywhere in store text.

## 2. Title (working title, Q3 16:19 KST; final after KIPRIS)
Play title and App Store app name use the same text. **KIPRIS class 9/41 search: NOT DONE** (KIPRIS_MANUAL_CHECK.md). Earlier web/Play name checks: NAME_SEARCH_LOG.md.

<!-- BEGIN title.ko -->
- 빵집 기사단: 곰팡이 디펜스
<!-- END title.ko -->

<!-- BEGIN title.en -->
- Bakery Knights: Mold Defense
<!-- END title.en -->

Not chosen in Q3 (kept for history only, not store text): 빵집 기사단 / Bakery Knights; 빵집 기사단 대 곰팡이 군단 / Bakery Knights vs Mold Legion.

Home-screen label (icon caption) is not a store field. Long names are cut on launchers; whether to set a shorter Android label (e.g. "빵집 기사단") is for 01/04.

## 2a. App Store subtitle (≤ 30 characters; only if an iOS build is made)
Says what kind of game it is without repeating the title or making a generic claim.

<!-- BEGIN subtitle.ko -->
한 줄 전장, 빵 병사 대 곰팡이 군단
<!-- END subtitle.ko -->

<!-- BEGIN subtitle.en -->
Lane battles: bread vs. mold
<!-- END subtitle.en -->

## 3. Short description (≤ 80 characters)
<!-- BEGIN short.ko -->
빵 병사를 보내고 제빵 대장을 직접 움직여, 곰팡이 군단의 기지를 무너뜨리세요.
<!-- END short.ko -->

<!-- BEGIN short.en -->
Send bread troops, steer the Head Baker and break the Mold Legion's base.
<!-- END short.en -->

## 4. Full description
Marker `[수익화 결정 시 변경]` / `[CHANGES IF MONETIZED]` = the sentence must be rewritten when ads or purchases are turned on. Remove markers before submission.

Wording choice: the game's own resource and worker names (반죽/Dough, 제빵사, 화덕포) are the same words Bread Defense uses, so the store text describes them by role ("일꾼", "수입", "공성") instead. The in-game names themselves are 01's call (request 06-services-to-01-director.md, Q3 update).

<!-- BEGIN full.ko -->
곰팡이 군단이 빵집 마을로 밀려옵니다. 빵집 기사단을 이끌고 한 줄 전장을 밀고 나가 적의 기지를 무너뜨리세요.

한 줄 전장에서 맞붙는 병력 전투
- 일꾼을 고용해 수입을 늘리고, 모은 자원으로 병사를 출동시킵니다.
- 지금 병사를 보낼지, 일꾼을 더 고용할지, 강한 병사를 위해 아껴 둘지 고르세요.
- 근접, 원거리, 방패, 돌격, 공성 다섯 병종의 빵 병사가 각자 다른 적에 강합니다.

직접 움직이는 영웅, 제빵 대장
- 제빵 대장을 앞뒤로 움직여 전선을 지키고, 세 가지 기술로 위기를 넘기세요.
- 쓰러져도 잠시 후 아군 기지에서 다시 나옵니다.

곰팡이 군단의 다양한 적
- 빠른 초파리 떼, 멀리서 포자를 뱉는 적, 단단한 멧돼지, 닿으면 터지는 효모, 그리고 두 보스가 기다립니다.

10개 라운드와 별 3개 도전
- 승리 시간과 기지 체력에 따라 라운드마다 별을 최대 3개까지 받을 수 있습니다.
- 진 라운드는 바로 다시 도전할 수 있습니다.

인터넷 연결 없이 플레이할 수 있습니다.
광고와 인앱 결제가 없습니다. [수익화 결정 시 변경]
<!-- END full.ko -->

<!-- BEGIN full.en -->
The Mold Legion is pushing into the bakery village. Lead the Bakery Knights down a single lane and break the enemy base.

Single-lane army battles
- Hire workers to raise your income, then spend it to send soldiers into the lane.
- Choose every few moments: send troops now, hire another worker, or save up for a stronger unit.
- Five kinds of bread soldiers (melee, ranged, shield, rush and siege) each counter different enemies.

A hero you control: the Head Baker
- Move the Head Baker forward or back to hold the line, and use three skills to turn a fight.
- If he falls, he returns to your base after a short wait.

A varied enemy legion
- Fast fruit flies, spore spitters, tough boars, yeast puffs that burst on contact, and two bosses.

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
| Single lane, destroy the enemy base to win | IMPLEMENTATION_BRIEF.md §2 (core loop, via GDD §3); data/text `tut_destroy_base` ("오른쪽 끝의 적 기지를 부수면 승리!") |
| 5 ally unit types (melee, ranged, shield, rush, siege); workers raise income | data/units/units.json (melee_basic, ranged_basic, tank, fast, siege); economy.json; `cmd_buy_worker` in INTERFACES.md |
| Hero you move (제빵 대장 / Head Baker), 3 skills, respawn | data/heroes/hero_captain.json, data/skills/ (slam, rally, barrage), data/text `hero.hero_captain.name`, GDD §4 |
| Enemy types and 2 bosses | data/units/units.json (e_grunt, e_swarm, e_spitter, e_brute, e_bomber, boss_warlord, boss_overlord); names in data/text `enemy.*` |
| Up to 3 stars, instant retry | INTERFACES.md BattleResult `stars`, `cmd_retry` |
| Works offline | export_presets.cfg `permissions/internet=false`; services disabled (test_services_integration D1, D6) |
| No ads, no in-app purchases | services `disabled` mode, no SDK (D1–D5); user deferred Q2 16:09 KST. **Changes if monetized** |
Not claimed on purpose: meta upgrades (no finished upgrade screen verified by 06), play time per round (design target only), device performance, "family friendly"/age suitability (needs the content rating questionnaire and U4), "tower defense" (the game is a lane battle, not tower placement), any comparison with other games.

## 6. Still needed before submission (not 06 decisions)
- KIPRIS class 9 and 41 search by a person, then final store name (user; KIPRIS_MANUAL_CHECK.md).
- Store-text differentiation wording review (01; candidates in 06-services-to-01-director.md).
- Contact email (required) and website (user).
- Screenshots and feature graphic from the real build (03/04), content rating questionnaire (user/04).
- en/ko proofreading by a native speaker.

## 7. Similar game: wording to keep away from (checked 2026-10-31)
"Bread Defense / 빵어전" by ETERNAXCODE (Google Play `com.eternaxcode.bbangeojeon`; App Store KR id6805946937, subtitle "온기를 굽는 타워디펜스"). Found by 09 (docs/research/product/SUCCESS_ANALYSIS.md §28). It is a bread-themed tower defense: dough pieces placed on a path, bread cards, a warmth resource, a hearth, Moisties from the fog, damp trails, spore clouds, bakers and assistants, bread warriors, hearth duels, a collection, and the tagline about defending the village with warm bread before the last ember fades.

What differs in our game, and is stated in our text: one horizontal lane with both sides sending troops; workers and income; a hero the player moves; destroying the enemy base to win; a mold legion with named bosses; 10 rounds; offline; no ads or purchases (for now).

The lint group `listing_competitor_overlap` fails if any store field (title, subtitle, short, full) contains one of the phrases below. "Defense"/"디펜스" is shared with every defense game and is allowed (part of the user's title).

| ko phrase (blocked) | en phrase (blocked) | Why |
|---|---|---|
| 빵어전 | bread defense | competitor name |
| 반죽 | dough | their core path piece; also our resource name |
| 화덕 | hearth | their base and PvP mode |
| 온기 | warmth | their resource and subtitle |
| 빵 카드 | bread card | their deck item |
| 눅눅이 | moistie | their enemy name |
| 축축 | damp trail | their enemy mechanic |
| 홀씨 | spore cloud | their enemy |
| 불씨 | ember | their tagline |
| 빵전사 | bread warrior | their late-game unit |
| 대련 | duel | their PvP mode |
| 따뜻한 빵 | warm bread | their tagline |
| 타워디펜스, 타워 디펜스 | tower defense | their genre label; not our genre |
| 제빵사 | assistant | their unit names (en "baker" stays: part of "Bakery" and our hero "Head Baker") |
| 도감 | — | their collection screen |
