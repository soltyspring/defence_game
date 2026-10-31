# 06-services → 01-director
Status: QUEUED (file request, not confirmed delivered). Date: 2026-10-31.
I do not ask the user directly. Please fold these into your planned one-at-a-time sequence after Q1 (ECONOMY.md §4: Q2 model → Q3 ads → Q4 IAP → Q5 audience). Nothing is blocked on them; services stay DISABLED until answered.

## What services already support (mock-tested only, not live)
Rewarded ads with daily caps and once-per-context rewards; non-consumable entitlements with restore; consumables; consent gate; allow-listed analytics. See docs/services/SERVICES.md.

## Inputs needed per question
- Q2 business model: M1 needs no services work. M2/M4 need billing and/or ads plus the production items in docs/services/PRODUCTION_REQUIREMENTS.md.
- Q3 ads: confirm placements and daily caps (data/meta.json already has `ad_double_gold` cap 5 and `ad_base_repair` cap 3). Internal default: a reward callback arriving after the ad closed is dropped (SERVICES.md §3). Change it only if you want it granted.
- Q4 IAP: product ids, type (`non_consumable` / `consumable`), and `entitlement` or `grant` per product in `data/meta.json` `iap_catalog.products`. **Verification choice is a user decision with cost:** (A, recommended) keep IAP off until a verification server exists; (B) own server + Play Developer API (hosting cost, service account kept on server); (C) client-side signature check only, labelled tamperable, low-value non-consumables only.
- Q5 audience: child-directed or not. Affects consent, ad SDK eligibility and personalised ads.
- New, low priority: remote analytics at launch? Recommendation: none (keep the local null sink). Options: none / own minimal endpoint / vendor SDK.

## Text keys (when ads/IAP UI is approved)
`svc.<code>` for the result codes in SERVICES.md §2, ko + en.

# Update M3 (2026-10-31) — QUEUED
- Retention measurement (routed from 10-research-systems, a design decision for you, not a user question from 06): the analytics contract cannot measure D1/D7 retention because the session id is never saved. Options: (A) Play Console aggregates only, (B) consented install-scoped random id + retention period in the privacy policy, (C) closed-test-only measurement. Recommendation: A at launch. Nothing implemented.
- Proposed events for your review: `ftue_step{step_id}`, `save_recovered{source}` (docs/services/ANALYTICS_EVENTS.md §7).
- Behaviour you may want to change (currently internal defaults, not user decisions): if game code breaks the grant contract (saves inside the reward and then reports failure), the player loses that one reward rather than risking a duplicate. The same applies to consumable purchases (Play refunds them automatically).
- 09-research-product guardrails R09-06-1 are reflected: reward record is written before the reward is applied (now evidenced against real save.gd including process death); restore never revokes offline; a refund revokes only that item. "Ad-removal entitlement suppresses all forced ads" needs your catalog definition: services expose `has_entitlement("remove_ads")`; there are no forced ads in the design.

# Update M5 (2026-10-31) — release decision queue, QUEUED
docs/services/OPEN_DECISIONS.md lists the user decisions needed before any ads/billing release, in the order 06 suggests: U1 business model (your Q2) → U2 Play account personal/organisation → U3 privacy contact + policy URL → U4 audience/children (your Q5) → U5 ad network + EEA serving (if ads) → U6 products + verification A/B/C (your Q4, if purchases) → U7 remote analytics → U8 Korean legal review. Please ask **one at a time** and skip those made irrelevant by earlier answers. Each has the source requirement ID in docs/services/RELEASE_READINESS_SERVICES.md (official URLs, checked 2026-10-31).
Design decision for you (no user question): DD1 — a reward callback that arrives after the ad closed is currently dropped, but AdMob's rewarded policy requires delivering the promised reward on completion. 06 recommends granting when the occasion is still valid. Please decide before ads go live.
New facts worth knowing for planning: Play Billing v7 is past its 2026-08-31 deadline (v8 supported to 2027-08-31, latest 9.1.0); new apps must target API 36 since 2026-08-31; personal accounts created after 2023-11-13 need a 12-tester, 14-day closed test before production.

# Update M6 (2026-10-31) — QUEUED
- Theme A (빵집 기사단 vs 곰팡이 군단) was relayed to 06 as a user decision (coordinator-to-06-services.md, 2026-10-31 09:03 KST). DECISIONS.md still shows Q1 PENDING at the time of writing; please record it so every role reads the same source.
- docs/services/STORE_LISTING_DRAFT.md: ko/en title candidates (≤30 chars), short (≤80) and full descriptions, lint-checked. Unit names in it are your GDD §1 illustrative names, marked [이름 확정 대기]; please replace with your final themed names. Title choice added as OPEN_DECISIONS.md U9 (needs a trademark/name search first; one question at a time).
- docs/services/PRIVACY_POLICY_DRAFT.md: ko/en template for the current no-data build, with [광고/결제 활성화 시] blocks and [법률 확인 필요] marks; placeholders need U2/U3 answers.

# Update M9 (2026-10-31) — QUEUED
For U6 (purchase verification), 06 prepared: docs/services/NO_SERVER_MINIMUM.md (when client-only purchases are acceptable: single-player offline, nothing needed to finish chapter 1, low-value items, no gacha; risks table). 06 recommendation if the user wants purchases without a server: ONE non-consumable (supporter / remove ads) only, no consumables until a server exists. Sandbox test steps with user-only steps marked: docs/services/BILLING_SANDBOX_TEST_PLAN.md. Still one question at a time, after U1.

# Update M10 (2026-10-31) — QUEUED, data field for later
Consumable products in `data/meta.json` `iap_catalog.products` may carry `max_quantity` (int, default 1 = multi-quantity off). Purchases above it are refused and refunded by Play. Only relevant once a catalog exists (Q4).

# Update M11 (2026-10-31) — QUEUED: Q2 cost per option
docs/services/MONETIZATION_OPTIONS_WORK.md compares A (rewarded ads + remove-ads purchase), B (paid app), C (chapter purchases): new 06 code, reused code, open design decisions, user prerequisites, permissions, Data safety/privacy/rating changes, risks, relative 06 effort (A L, B S, C M) and test scope. Facts you may want in the Q2 question: B keeps "no data collected" and needs no ad/billing work; C needs chapter 2 content to exist; A has an open contradiction to settle first (what "remove ads" removes when every ad is opt-in rewarded). Not a recommendation of a model. Please keep it one question at a time.

# Update M12 (2026-10-31) — QUEUED (Q2 deferred acknowledged: monetization stays disabled, no monetization UI)
- U3 later (one question at a time): privacy policy hosting. Ready-to-fill page docs/services/privacy_site/index.html (disabled-mode text). Hosting choices H1 separate public repo / H2 gh-pages branch / H3 /docs folder (not recommended) / H4 other host (not researched), steps P1–P9 with [USER] actions: docs/services/PRIVACY_POLICY_HOSTING.md. Values needed from the user: developer name, contact email, privacy contact, effective date; plus U4 for the children statement.
- U4 later: target audience options T1 (13+ only), T2 (all ages incl. children → Families policy), T3 (children only) with consequences now and if ads are added later: docs/services/FAMILIES_ASSESSMENT.md. Aligned with 09 §25.3 (cannot judge whether cute bread art counts as child-targeting; no child/parent evidence).
- Content rating draft re-checked for Q2 deferred: ads, purchases, user interaction, location, unrestricted internet all "No" (CONTENT_RATING_DRAFT.md §2a).

# Update Q3 (2026-10-31) — QUEUED: working title in the listing, Bread Defense overlap, KIPRIS
Q3 acknowledged (user 16:19 KST, working title; final after KIPRIS). Not a user question from 06.
- **Listing:** docs/services/STORE_LISTING_DRAFT.md now holds only the working title: ko "빵집 기사단: 곰팡이 디펜스" (15 chars), en "Bakery Knights: Mold Defense" (28 chars). It also has App Store subtitles (ko 21, en 28; only if iOS) and new short descriptions (ko 44, en 73). The lint checks title ≤ 30 (and ≥ 2 for the App Store), subtitle ≤ 30, short ≤ 80, ads/purchase lines with the change marker, brands, and the Bread Defense phrases.
- **Title in the game:** data/text `ui.title` is still "레인 디펜스". Play wants the listing to match the app, so please set ko/en `ui.title` to the working title when you record Q3 (the 30-char limit is not an issue; 04 may want a shorter launcher label).
- **KIPRIS:** the person doing the check follows docs/services/KIPRIS_MANUAL_CHECK.md (16 terms × classes 9 and 41, status values, record form). All 32 rows are NOT_DONE. Please put "who runs KIPRIS, and when" into your one-at-a-time sequence when it fits; 06 has no result and will not invent one.

## Bread Defense / 빵어전 overlap (facts, from its Play and App Store KR pages and 09 §28)
Their signature words: 반죽/Dough (path pieces), 빵 카드, 온기/Warmth, 화덕/hearth, 눅눅이/Moisties, 축축 자국, 홀씨 구름/spore clouds, 제빵사·조수 (Bakers, Assistants), 빵전사, 화덕 대련 (duels), 도감, and the tagline about defending the village with warm bread before the last ember fades. Subtitle "온기를 굽는 타워디펜스".
- Store text: 06 removed 반죽, 꼬마 제빵사 and "dough income" and describes them by role (일꾼, 수입). The lint now blocks the list in STORE_LISTING_DRAFT.md §7.
- **In-game names (your call, 06 does not edit data/text):** our own text uses three of their words: `res.supply` 반죽/Dough, `unit.worker.name` 제빵사, `unit.siege.name` 화덕포 (ko 화덕), plus `round.r01.name` "첫 번째 반죽". Screenshots will show them. Options: (a) keep them (they are common bakery words; low legal risk, some "looks the same" risk in screenshots); (b) rename the resource, e.g. 밀가루/Flour, and the siege unit, e.g. 오븐포/Oven Cannon (en is already "Oven"). If you rename, tell 06 so the §5 evidence and §7 note follow.

## Differentiation wording candidates for the store text (for your review; none used beyond the draft)
| # | ko | en | What it stresses |
|---|---|---|---|
| D1 | 한 줄 전장을 밀고 나가 곰팡이 기지를 무너뜨리세요 | Push down one lane and break the mold base | attack to win (they defend a path) |
| D2 | 직접 움직이는 영웅, 제빵 대장 | A hero you steer: the Head Baker | hero control (they place cards) |
| D3 | 일꾼을 늘릴까, 병사를 보낼까, 아껴 둘까 | More workers, more troops, or save up? | income decisions |
| D4 | 곰팡이 장군과 부패 대군주를 쓰러뜨리세요 | Defeat the Mold General and the Rot Overlord | named bosses from your text |
| D5 | 인터넷 없이 10개 라운드 | Ten rounds, no connection needed | offline, finite campaign |
Avoid "타워디펜스/tower defense" in any of them: our game is a lane battle, and the phrase is their subtitle's genre label. The draft currently uses D1–D3 in the short/full text and the subtitle "한 줄 전장, 빵 병사 대 곰팡이 군단" / "Lane battles: bread vs. mold".

# Update backup (2026-10-31 16:56 KST) — QUEUED: save backup option (design decision; you decide whether the user is asked)
docs/services/SAVE_BACKUP_POLICY.md (desk study, **no device test**). Today the offline save survives app updates only. It is lost on reinstall, on "clear data", and on a new phone set up from Google backup. Some Android 12+ phones may still copy it in a device-to-device transfer. Options:
- **B0 keep:** no work; no change to privacy or Data safety.
- **B1 back up the save only:** restored on reinstall and on a new phone. Needs 02's Gradle build, which the AAB needs anyway. The privacy policy gets the prepared [백업 활성화 시] sentence. Data safety stays "No" (06 judgement, to confirm when filling the form).
- **B2 explicit no backup:** same behaviour on every phone; progress is always lost.
- **B3 keep-data prompt at uninstall:** one export option; helps only if the player chooses to keep data.
06 recommendation (not a decision): B0 now, B1 when the Gradle build exists. Your call, alongside Q2 deferred. Nothing changes in the build until you answer.
Also: the Data safety draft and privacy draft were re-checked against the current backup values. There is no contradiction (DATA_SAFETY_DRAFT.md §2b, SAVE_BACKUP_POLICY.md §5).
