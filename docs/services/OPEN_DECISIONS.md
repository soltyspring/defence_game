# Open decisions for release (owner: 06-services; asked only by 01, one at a time)
Version: 1 (2026-10-31). 06 does not ask the user. 01 asks these **one at a time**, in order, and records each answer in docs/design/DECISIONS.md. Nothing below is decided. Every later question depends on earlier answers, so skip the ones the earlier answers make irrelevant.

## User decisions (business, account, legal)
| Order | Question for the user | Why it matters (RELEASE_READINESS_SERVICES.md IDs) | Skip if |
|---|---|---|---|
| U1 | **DEFERRED by user 2026-10-31 16:09 KST ("수익모델은 보류").** Business model: paid app / free + rewarded ads / free + one-time purchases / both (01's Q2, options in ECONOMY.md §4) | Decides whether any of B1–B9 or A1–A6 apply | — |
| U2 | Play developer account: personal or organisation? | Personal (created after 2023-11-13) needs a 12-tester, 14-day closed test (C2); organisation needs a D-U-N-S number (C3); the named entity must appear in the privacy policy (V2) | — |
| U3 | Who is the privacy contact and where is the privacy policy hosted (public URL)? Hosting choices H1–H4 and steps: PRIVACY_POLICY_HOSTING.md | Required for every release, even with no data collected (V1, V2, V5) | — |
| U4 | Target audience: does the game target children, or can children see it? (01's Q5) Options T1–T3 with Families consequences: FAMILIES_ASSESSMENT.md | Families rules for ads (A5), consent and personalised ads (A2) | U1 has no ads |
| U5 | Ads only: which ad network, and is serving ads in the EEA/UK/Switzerland acceptable (needs certified CMP)? | A2, A3, A6, Data safety answers | U1 has no ads |
| U6 | Purchases only: product list (01's Q4) and purchase verification approach — (A) keep purchases off until a server exists, (B) own verification server with hosting cost, (C) client-side check only, labelled tamperable, low-value items only; minimum bar and risks for C: NO_SERVER_MINIMUM.md; sandbox test steps: BILLING_SANDBOX_TEST_PLAN.md | B4–B6 need a server; without one nothing can be verified or revoked reliably | U1 has no purchases |
| U7 | Remote analytics at launch: none / own minimal endpoint / vendor SDK (routed in M3) | Data safety (V1), consent | — |
| U8 | Legal review of the Korean 개인정보 처리방침 and refund notice: who does it? | V5 could not be verified by tool; amendments reported effective 2026-09-11 | — |
| U9 | Store title: pick one candidate (STORE_LISTING_DRAFT.md §2: 빵집 기사단 / 빵집 기사단: 곰팡이 디펜스 / 빵집 기사단 대 곰팡이 군단; en: Bakery Knights / Bakery Knights: Mold Defense / Bakery Knights vs Mold Legion) after a trademark/name search | Store listing; privacy policy {{APP_NAME}} | — (independent of U1–U8; theme A decided 2026-10-31 09:03) |

Recommendation from 06 (not a decision): U1 first; for U6 option A until a server is budgeted; for U7 "none".

## Design decisions for 01 (no user question needed)
| ID | Decision | Current internal default | Note |
|---|---|---|---|
| DD1 | Reward callback that arrives after the ad closed (REWARD_STATE_TABLE R11) | Dropped | AdMob policy (A1) requires delivering a promised reward on completion. 06 recommends: grant if the occasion is still valid (results screen still open, or a rescue whose battle has not ended), otherwise show "reward could not be applied". Needs 01's choice before ads go live |
| DD2 | Grant-sink contract violation (R8/P2) | Lose that one reward, never duplicate | Unchanged from M3 |
| DD3 | Proposed analytics events `ftue_step`, `save_recovered` | Not in schema | Routed in M3 |
