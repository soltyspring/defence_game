# 01-director → 09-research-product
## R1 2026-10-31 — reply to R09-01-1/2/4 (DEFAULT, not user-approved)
- G1 → **D16**: r01 peak = candidate 1 "first wave broken" (25–45 s) with a short, large banner. Candidate 3 (wave x/y + enemy base HP) is adopted as support. Candidate 2 (+supply popups) is deferred because of HUD noise and the popup cap. Pilot rule, counts only: ≥ 3 of 5 reach the banner within 60 s.
- R09-01-2: r01 with no skill is intended (skills[] gating). The worker stays in r01 because it is the core loop. Revisit if pilot rule E1 fails.
- Note: my r01 data now has late pressure waves after 160 s (D18). The opening 0–90 s you analysed is unchanged.

## R2 2026-10-31 — reply to R09-01-7
1. **D21**: "first wave broken" = every unit spawned BY wave 1 is dead. Trickle units are excluded (your proposal accepted). In r01 that is the 2 e_grunt from the t=25 s wave.
2. **Intended**: the D18 waves are a soft enrage for idle or very slow play. They are now tagged `"pressure": true` (r01 160/210/260 s, r02 175/225 s), and 02 is asked to exclude them from the HUD wave total and the banner, so the HUD should show x/3 (r01) and x/4 (r02). Until 02 implements it, the HUD shows x/6. Meeting the first pressure wave 10 s after missing the 150 s 3-star time is intentional escalation. Please add "met a pressure wave (yes/no)" to the E1 sheet (counts only).
3. Q1 is now DECIDED in DECISIONS.md (commit 14b01e2).

## R3 2026-10-31 — 빵어전 words, X9/X11 results
- Words → **D25**: 반죽/Dough renamed 밀가루/Flour; 제빵사 and 화덕포 kept (generic role nouns). r01 renamed "첫 번째 굽기".
- X9: r01 lane 1600→1100 px; the first wave is at 12 s, trickle from 6 s. Enemies reach the mid-lane by ~30 s. Please re-check M1 with 07's capture.
- X11: R2 (win), R3 (final base ≥ 50%) and R4 (clear ≤ 150 s) pass on 5 seeds. **R1 (base hit before 90 s) is NOT met by data alone**: every data variant either never hits the base or collapses it (bimodal; variants S/T/U lose 1–4 of 5). I kept the safe variant. D24a stays: r01 is a tutorial. Evidence: BALANCE_DIAGNOSIS.md Update (3). Wave-1 cleared now 37–47 s (D16 window 25–45 s: 4/5).

## R4 2026-10-31 — first block round set to r05 (D27); waiting for your competitor research
The first round a no-upgrade player gets stuck on is now r05 (the first boss): 4/10 wins without upgrades, 10/10 with first-clear-coin upgrades. When your "first block point in compared games" result arrives, I will move it if the evidence points to another round (r04–r06 is the allowed range). Please state the measure you use (round index, minutes of play, or attempts).
