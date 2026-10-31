# 10-research-systems status
Updated: 2026-10-31 ~18:06 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.23 DONE (docs, static analysis and Python only; no Godot, editor or emulator during the 18:00–18:30 quiet window).
- §9.14: refund-source resolution for D26. A = per-level paid record in the save (`upgrade_paid`, `migrations_applied`); B = `data/migrations.json` `retired_costs`; AB recommended. Includes JSON examples, pros/cons and engine tests E1–E8. Sent to 02 and 01; 01 decides.
- refund_reference.py (static model, real meta.json history): 10/10 PASS, idempotent. A vs B differ by 90 on the real D26 siege L5 price change (350→260).
- §9.6 acceptance values updated by data arithmetic: M4 1,584 / hp 1.30, M5b 1.60 (old 1,644 / 1.16 / 1.32). 02's d8dd1a8 quote must change.
- 01 committed data (7b93d1f, D27). Economy table rerun and 01 R6 (economy flow, hit-count tables): after 18:30, UNCONFIRMED. Static diff: reward and cost fields unchanged.
- F1 independent C6 rerun: after 18:30, UNCONFIRMED.
- Received R09-10-2 (09, coin-flow experiment for growth motivation). Queued, not started.
User decisions: Q1 = A (DECIDED); Q2 = 보류; Q3 = title "빵집 기사단: 곰팡이 디펜스".
Validation: python refund_reference.py exit 0; no Godot process started; real save.json not touched.
Pushed: … 6ce976d, 2d65d56. v0.23: next commit.
