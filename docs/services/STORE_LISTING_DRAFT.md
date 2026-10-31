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

## 2b. Home-screen (launcher) name vs store title — Q4 DECIDED by user
**User decision Q4, 2026-10-31 17:19 KST** (Codex chat, original words "빵집 기사단"; coordinator-to-06-services.md "사용자 결정 Q4"): option A. The launcher name is ko `빵집 기사단`, en `Bakery Knights`. The in-game title and the store title stay the full working title. The final store name still waits for the KIPRIS check.

<!-- BEGIN launcher.ko -->
빵집 기사단
<!-- END launcher.ko -->

<!-- BEGIN launcher.en -->
Bakery Knights
<!-- END launcher.en -->

Relation checked by the lint (`launcher_label_note`): each launcher name equals the store title up to its ":" ("빵집 기사단" + ": 곰팡이 디펜스", "Bakery Knights" + ": Mold Defense"). Both are KIPRIS terms (T2/T3, T11/T12), and both pass the same banned-word, brand and Bread Defense checks as the store text. The APK check (`tests/services/test_services_android.gd` group `launcher_label`) reads the real label with aapt2 once 02 rebuilds.

Current launcher name in the build: `Lane Defence` (export_presets.cfg `package/name`, project.godot `config/name`; the 07e97ca APK shows `application-label:'Lane Defence'` in every locale, aapt2 dump badging). **06 does not change it** (02 owns these files and applies Q4). It must not ship, because it matches neither the store title nor the in-game title (`ui.title`).

What Play's rules say (official pages, checked 2026-10-31):
| Rule (paraphrased) | Source |
|---|---|
| The store "App name" is the app's name on Google Play, ≤ 30 characters, one localized name per language | https://support.google.com/googleplay/android-developer/answer/9859152 |
| Title and other metadata must be accurate and must not mislead; no performance, price or promotion words; no emoji or repeated special characters | https://support.google.com/googleplay/android-developer/answer/9898842 |
| Title and developer name must not make users download the wrong app or imply a relationship with someone else; do not use another app's name in a misleading way | https://support.google.com/googleplay/android-developer/answer/13393723 (App title, Impersonation) |
Content was rephrased for compliance with licensing restrictions.

06 found **no rule that the launcher name must equal the store title**. The pages above treat them separately: the store name is set in Play Console, and the launcher name comes from the app. The risk to manage is misleading users. How each Q4 option looked against these rules (06 reading, not legal advice; **the user chose A**):
| Q4 option | Launcher name | Same as store title? | Policy reading |
|---|---|---|---|
| A | 빵집 기사단 / Bakery Knights | first part of it | fine: a user who installs "빵집 기사단: 곰팡이 디펜스" sees the start of the same name |
| B | 곰팡이 디펜스 / Mold Defense | second part only | allowed, but weaker: "Mold Defense" alone is a generic phrase and loses the brand word; check it is not another app's name (KIPRIS terms T4/T5/T14 cover it) |
| C | full title | yes | fine; the launcher cuts it ("빵집 기사단: 곰팡…") |
Not verified: whether ko and en launcher names can differ in our build. Godot has `application/config/name_localized`, but 06 has not tested it with the prebuilt Android template (02 to confirm). Changing `config/name` also moves desktop `user://` folders (Windows `%APPDATA%/Godot/app_userdata/<name>`); Android saves are not affected (files dir is per package).

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

Wording choice (updated after 01 D25, a262640): the game's resource is now 밀가루 / Flour (it was 반죽 / Dough, Bread Defense's core word). 01 kept 제빵사 (worker) and 화덕포 (siege unit) as generic role nouns, so the store text uses the game's own words and matches what screenshots show. "반죽"/"dough" stay blocked. The lint group `game_text_overlap` checks every ko/en string in data/text against the §7 list and checks that the store text uses the game's resource name.

<!-- BEGIN full.ko -->
곰팡이 군단이 빵집 마을로 밀려옵니다. 빵집 기사단을 이끌고 한 줄 전장을 밀고 나가 적의 기지를 무너뜨리세요.

한 줄 전장에서 맞붙는 병력 전투
- 꼬마 제빵사를 고용해 밀가루 수입을 늘리고, 모은 밀가루로 병사를 출동시킵니다.
- 지금 병사를 보낼지, 제빵사를 더 고용할지, 강한 병사를 위해 아껴 둘지 고르세요.
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
- Hire little bakers to gather more flour, then spend it to send soldiers into the lane.
- Choose every few moments: send troops now, hire another baker, or save up for a stronger unit.
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
| 5 ally unit types (melee, ranged, shield, rush, siege); bakers (workers) gather flour | data/units/units.json (melee_basic, ranged_basic, tank, fast, siege); economy.json; `cmd_buy_worker` in INTERFACES.md; data/text `unit.worker.name` 제빵사/Baker, `res.supply` 밀가루/Flour (01 D25, a262640) |
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

The lint group `listing_competitor_overlap` fails if any store field (title, subtitle, short, full) contains one of the phrases below; `game_text_overlap` applies the same list to every string in data/text/ko.json and en.json, so store text and game text cannot drift apart again. "Defense"/"디펜스" is shared with every defense game and is allowed (part of the user's title). 제빵사 and 화덕 are allowed in both by 01's decision D25 (generic role nouns for our units).

| ko phrase (blocked) | en phrase (blocked) | Why |
|---|---|---|
| 빵어전 | bread defense | competitor name |
| 반죽 | dough | their core path piece; our resource was renamed to 밀가루/Flour (01 D25) |
| — (화덕 allowed: our siege unit 화덕포, 01 D25) | hearth | their base and PvP mode |
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
| — (제빵사 allowed: our worker unit, 01 D25) | assistant | their unit names (en "baker" stays: part of "Bakery", our worker "Baker" and hero "Head Baker") |
| 도감 | — | their collection screen |
