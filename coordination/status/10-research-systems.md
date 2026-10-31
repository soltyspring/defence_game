# 10-research-systems status
Updated: 2026-10-31 ~18:52 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.24 DONE (Godot runs after the 18:30 quiet window).
- Economy policy table rerun on D27 data (HEAD fca9346, data 7b93d1f): coin and level columns identical to 40382b0. Card−enemy is negative r02–r05 and positive from r06 for P1 and P2. This agrees with D27 "r05 block"; the counterpoint (r02–r04 deficit larger, yet the sim wins) is noted. Economy flow is unchanged (5,595; 14/10 replays); integrity 0/0/0.
- Breakpoints per 100 coins recomputed (new aggregator effect_points_per_coin.py, validated against ee30b9d). Melee and fast now bend at L3→L4; ranged L5 is now the worst (4.7).
- F1 independently confirmed at a clean full snapshot (b4b33a7): C6 8/8, C1–C13 PASS; rotation 8/8; dedup 162/1.
- R5 not committed: migration and E1–E8 waiting. Part D: hp 2.20 vs cap 1.60.
- R09-10-2 answered to 09 (LOW cheapest-first result-screen coins and buys; r10 replays at 30/40/50%). 01's priority policy is not answered.
User decisions: Q1 = A (DECIDED); Q2 = 보류; Q3 = title "빵집 기사단: 곰팡이 디펜스".
Validation: all probe exits 0, 0 SCRIPT ERROR; real save.json hash 486C8160… unchanged before and after; snapshot dirs and app_userdata removed.
Pushed: … 2d65d56, d328518. v0.24: next commit.
