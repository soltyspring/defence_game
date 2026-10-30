# 01-director handoff
Updated: 2026-10-31 +09:00
Status: Q1 (theme) unanswered and the only open user question. Coordinator findings C01–C03 corrected and pushed. All decisions D1–D12 are DEFAULT; none is user-approved.

## Read receipts
BRIEF.md, OWNERSHIP.md (incl. new roles 05–08), GIT_WORKFLOW.md, QUALITY_REVIEW.md incl. Completion gate, coordinator-to-01-director.md through Dispatch R4 + Completion review gate, gongmojeon SKILL.md (applied as a method only: evidence classes, core-assumption tests, hostile rejection → fix → retest; no contest invented), 04-client-to-01-director R1/R2, src/ui/ui_text.gd, hud.gd/hud_top.gd format call sites, ENGINE.md/INTERFACES.md v1.0.
Last processed: requests coordinator-to-01 (Dispatch R3, R4, Completion gate), 02-engine-to-01 R1 (no newer 02 reply), 04-client-to-01 R1+R2.

## C01–C03: original-report critique → correction → rerun
| ID | Critique of my earlier output | Correction | Rerun evidence |
|---|---|---|---|
| C01 | RELEASE_DESIGN_REVIEW §8 asked ≥ 5 testers to reach 95/90/85% rates. At n = 5 one player = 20 pp, and 5/5 is consistent with 57–100% (Wilson 95%). Targets were arbitrary. The same defect was in ROUNDS.md assumption 1 and the §2.2 table | §2.2 is now internal intent with no percentages. §8 is split into 8.1 automated correctness, 8.2 exploratory pilot (counts plus pre-set decision rules, e.g. ≥ 2/5 stuck same step > 60 s → P1), 8.3 later validation sized by margin (43 / 97 / 385 players for ±15 / 10 / 5 pp; 35 at p ≈ 0.9), 8.4 count-only reporting. ROUNDS.md is bot-only. The 30 s first-deploy target is labelled arbitrary | Python stats script output (Wilson CIs for 0–5/5; detection probabilities 0.23/0.41/0.67/0.84/0.97 for 5/10/20/31/50% problems). grep of docs/design shows no remaining human win-rate targets |
| C02 | Parser, parity and bot wins were implicitly treated as quality. No claim → counterargument → test mapping existed. RESEARCH.md had only 2 primary sources | New QUALITY_BAR.md: evidence classes C/A/O/M/U and 10 critical claims with evidence, counterargument, smallest test and decision rule. Hostile summary §2: no human has played; workers and melee look dominant; content volume is low. RESEARCH.md: 10 sources with URLs (S1–S10, accessed 2026-10-31), observation vs inference split, no hands-on play claimed. Sim requests to 02 (R3) and checks to 07 (R1) | Analytic (not engine): worker payback 27/35/45/59/76/99 s for workers 1–6, so buying all workers may be dominant. A simplified r01 hero-solo model has the hero dying at ~75 s with the enemy base at 375/800. Both are labelled analytic and routed to the 02 sim |
| C03 | 04 requested 47 UI/toast keys. data/text had none, so the UI ran on hard-coded fallbacks | Added 49 keys (47 requested + ui.round_n + ui.coins) to ko/en. Kept %d. ui.title is a provisional placeholder. ui.coins = "골드" (D12) | One-off Python check: keys ko 109 / en 109, no missing or extra; placeholder sequences equal per key and equal to FALLBACK_KO; all 47 requested + 49 fallback + all `ui.*`/`toast.*` literals in src/ present → ALL_OK=True. Verified Hangul code points by unicode escape (the console garbling was only the code page). Format-argument count per call site (d) checked only by reading hud.gd/hud_top.gd, not by code → regression asked of 04 (R3) and 07 (R1) |
Also fixed stale numbers found while rechecking: GDD hero armor 15 → flat 3, ROUNDS tank armor 30 → 3 and enemy cap 40 → 36, ECONOMY "~60% of tracks" → "62% of upgrade spend".

## Still unproven (strongest rejection reasons)
No human play; no engine sim. Claims 1–10 in QUALITY_BAR are open. Content volume is far below the genre leaders. The theme is undecided.

## Effort
The requested max effort cannot be read back in this session. The actual accepted effort is unverified, so I don't claim it.

## Next task (01)
1. Q1 answer → record the literal answer, interpretation and affected roles in DECISIONS.md and here; update names in text; send requests to 02/03/04/07; publish.
2. Then Q2 (business model), one question at a time.
3. When the 02 R3 sims arrive: apply the QUALITY_BAR decision rules (B27), retune data, re-validate, publish.

## Git
- e42f809 [Design] initial design/data → PUSHED
- ec657bc [Fix] en keys → PUSHED
- abdb664 [Docs] release design review → PUSHED
- 4cd16ee [Docs] handoff SHA record → PUSHED
- f8823ac837ca93b5fa2592cc972c6f65d79455c9 [Feat] UI·알림 텍스트 키 49개 한영 추가 (ko/en + 04 request) → PUSHED origin/main
- e07b7a3d5cf6586d99d82cc50537ae1e01ded71f [Docs] 품질 기준·연구 근거 보강과 플레이테스트 판정 기준 재작성 (13 files) → PUSHED origin/main
