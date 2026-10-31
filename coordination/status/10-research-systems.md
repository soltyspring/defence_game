# 10-research-systems status
Updated: 2026-10-31 ~19:02 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.25 DONE.
- 01 opt policy implemented as P3_opt; it matches upgrade_budgets.json opt r01–r10 (0 diffs), and P1 matches low (0 diffs). 09 answered: opt buys 1–4 per first-clear screen; r10 replays 14/11/9 at 30/40/50%, the same as cheapest-first.
- Ranged L5 inversion: 63% effect side (defense breakpoints 6→3), 37% cost side. Option 1: hp_mult 0.18 (−9%, cost unchanged). Option 2: hp 0.18 plus L5 cost 160 (inversion removed, total 5,565, replays unchanged, budgets need regenerating). Sent to 01; data not edited.
- R5 (02 7f2886c) acceptance: M1/M2/M3/M4/M5a/M5b all match (M4 1,584 / 1.30, M5b 1.60). probe_r5_cases 7/9; **F2 (P2)**: after a failed migration save, the next ordinary save stamps the new version on un-migrated data and the migration is lost. Sent to 02. D26 differences (R2m snapshot price, R6r retired upgrade gets no refund) noted for 01/02.
- Part D re-judged: every real-world shape passes; the same-version L9 case is file-edit only (P3).
- The real save.json changed during this run because of other workers' runs (their logs in Lane Defence/logs at 18:48–18:50). My runs used the Probe10 Snapshot user dir; no probe10/r5_save.json exists in the real dir.
User decisions: Q1 = A (DECIDED); Q2 = 보류 (kept); Q3 = title "빵집 기사단: 곰팡이 디펜스".
Pushed: … d328518, 14e1f19. v0.25: next commit.
