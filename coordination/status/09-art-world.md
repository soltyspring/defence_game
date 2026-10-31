# 09-art-world status
Updated: 2026-11-01 ~08:30 KST
Session: sess_6ce8ebb1-4e45-454d-a561-e0bad09a8be5 · claude-opus-5.5 / trust-all (formerly 09-research-product, closed eb8d5c4)
Status: art-world 1 = 92a1718 (accepted). External validation f0c1879. Art-world 2 (light street: C4 min 6.7 → 28.9, keep ring 12.6 → 28.9, nest_check PASS, proj_sep PASS) committed with this update; 07 real capture of it not run yet.
READ: user 01:0x KST "그래픽이 너무 별로야"; Codex "[09 다음 작업: 남은 FAIL 수정과 통과 기준의 외부 검증]"; HEAVY_RUN.md (detached runs only). Decisions unchanged: Q1 theme A, Q2 on hold (no ad/pay/shop UI), Q3/Q4 decided, Q5 unanswered (D28 is a default).
Done:
- External range: 6 Play screenshots of 4 landscape lane-defence games, same tool on our before/after frames (tools/art/world/ext_metrics.py, external_range.json/_out.json; images not committed). Decisions: P1/P2 become info only (they excluded the dark outline and passed while 07 C4 got worse); new governing line = 07 C4/C4m + 03 sil; street front behind units goes back to light (L* 75–80) with art-world 1's low chroma; P3 far line kept as a style choice (stricter than 4 of 5 external far layers); P4 25 kept as our target, not an external norm.
- 07 art_compare 92a1718 (-NoAnim, ko_1x): VOID (G2 state differs in r01_t10, r08_peak, r10_boss). BETTER: C3, C5, W1, W3, W3m. WORSE on state-equal scenes and caused by my street: C4 (11.1 → 66.7 %, 18.2 → 54.5 %) and C4m (25.6 → 9.8, 24.7 → 14.0).
Open: units in front of the keep's dark lower course (C4 0.6–3.8), bright stress variant boss_warlord sil 57.2 (03), 07 art_compare of the new commit, W8-1 sky opaque request (02/03). No human player test, no phone check.
