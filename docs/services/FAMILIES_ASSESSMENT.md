# Could Google Play treat the game as child-directed? Families policy assessment (owner: 06-services)
Version: 1 (2026-10-31). Status: **assessment for decision U4 (target audience), not a decision.** Basis: Q2 deferred by the user (no ads, no purchases, no data collection, no user interaction), theme A (bread knights vs mold legion), current art and text. Aligned with 09-research-product (docs/research/product/SUCCESS_ANALYSIS.md §25.3), which found no direct evidence about children's reactions and could not judge whether cute bread characters count as child-targeting imagery.

## 1. Rules (Google Play Console Help, checked 2026-10-31, paraphrased)
| ID | Rule | Source |
|---|---|---|
| F1 | The developer declares target age groups in Play Console (App content → Target audience and content). Before that section: the ads declaration, app-access instructions and a privacy policy must be done | https://support.google.com/googleplay/android-developer/answer/9867159?hl=en |
| F2 | Designed primarily for children under 13, or for everyone including children → Families policy applies (including Families Self-Certified Ads SDKs only, for children and users of unknown age). Not designed for children → general policies only | https://support.google.com/googleplay/android-developer/answer/9867159?hl=en |
| F3 | Pick several age groups only if the app is really designed for each; pick mixed adult+child groups only if truly designed for all ages, not just to be available to everyone. Under-21 targets must be checked against local definitions of "child" | https://support.google.com/googleplay/android-developer/answer/9867159?hl=en |
| F4 | Age-group guidance: under 5 and 6–8 count as children in most locales; for 5 and under, violence, fighting, weapons and characters in danger are listed as unsuitable; for 6–8, realistic aggression or injury is unsuitable; 9–12 count as children in most locales; 13–15 and 16–17 may count as children in some locales | https://support.google.com/googleplay/android-developer/answer/9867159?hl=en |
| F5 | If the app is not primarily for children but the store listing suggests otherwise (youthful animation, young characters in graphics), Google Play may reject it; the fix is either removing those marketing elements or targeting children under 13 and complying with Families | https://support.google.com/googleplay/android-developer/answer/9867159?hl=en |
| F6 | Families policy text: imagery and terms that could be seen as targeting children can change Google's assessment of the declared audience, regardless of the Console declaration | https://support.google.com/googleplay/android-developer/answer/9893335?hl=en (as quoted by 09 §25.3 and the Play search snippet, 2026-10-31) |
| F7 | Google reviews the declared target audience; some reviews take up to 7 days or longer | https://support.google.com/googleplay/android-developer/answer/9867159?hl=en |
Content was rephrased for compliance with licensing restrictions.

## 2. Signals in this game
| Signal | Points toward "appeals to children" | Points away | Evidence |
|---|---|---|---|
| Theme | Cute food characters (bread knights), bakery setting | Combat strategy genre | Q1 decision; GDD §1 |
| Art | Small pixel characters, warm palette | Battle scenes, weapons, death animations, mold/insect enemies and two bosses | docs/art/ART_DIRECTION.md |
| Gameplay | Simple taps, short rounds | Fast decisions (worker vs unit timing), losing rounds, resource management, reading skill text | GDD §2–3; F4 lists quick reactions and penalties as unsuitable for 5 and under |
| Text | — | Korean/English UI text required to play (skills, cards) | data/text |
| Comparable listings (09 §25.3, Play KR shown ratings) | CookieRun: Kingdom and a mold-raising game show 전체이용가 | Plants vs. Zombies 7+, PvZ 2 12+, Cat War 2 7+ | 09 evidence; a content rating is not a target-audience declaration |
| Data/ads | Nothing collected, no ads, no social features (Q2 deferred) — Families data rules would be easy to meet today | — | DATA_SAFETY_DRAFT.md §2a |
06 reading: the game is not designed for under-9s (F4: fighting, weapons, quick reactions, penalties). It may still **look** child-appealing in the store because of cute bread characters (F5/F6). 09 reached the same "cannot judge" conclusion on the imagery question.

## 3. Options for U4 (01 asks the user; 06 does not decide)
| Option | Declaration | Consequence now (Q2 deferred) | Consequence if ads are added later | Store-listing implication |
|---|---|---|---|---|
| T1 | 13+ only (13–15, 16–17, 18+) | General policies; Families not applied | Any ad SDK allowed under general policy; consent rules still apply | Listing art should avoid looking made for young children (F5); screenshots should show battles, not only cute portraits |
| T2 | All ages incl. 9–12 (or 6–8) | Families policy applies; with no ads, no data and no social features, the main extra duties are policy compliance and accurate disclosures (06 view, verify at submission) | Only Families Self-Certified ads SDKs for children/unknown age, no personalised ads, rewarded ads closable after 5 s, neutral age screen for mixed audiences (RELEASE_READINESS_SERVICES.md A5) | No restriction on cute art; must be suitable for the youngest selected group (F3/F4) |
| T3 | Children only (under 13) | Full Families compliance | All ads Families-certified only | Not consistent with the game's design per F4 |
06 observation: T1 needs no product change today but carries a listing-review risk (F5); T2 removes that risk but binds any future ads to Families rules. With Q2 deferred, T2's extra cost is small today and grows only if ads are chosen later.

## 4. Effect on other drafts
- CONTENT_RATING_DRAFT.md: the IARC content rating and the target audience are separate declarations; the rating answers do not change with U4.
- PRIVACY_POLICY_DRAFT.md §7 / privacy_site: `{{CHILD_AUDIENCE_STATEMENT}}` is written after U4 (legal review U8).
- STORE_LISTING_DRAFT.md: under T1, choose screenshots and feature graphic that show the battle game (09 §25.2 also notes the chef-hat hero may read as a tycoon game).
