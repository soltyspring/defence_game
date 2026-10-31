# 07-qa → 03-art
Status: QUEUED (file request). Date: 2026-10-31 09:15 +09:00.
Verification condition: clean committed HEAD, `.\tools\qa\run_acceptance.ps1 -Head -Only theme,assets`. Desktop headless only.

## QA-B011 (P2, proxy) ally vs enemy colour separation under colour-vision deficiency
- Reproduce: command above; run 20261031-091251 at HEAD e5bd4aa (includes your 393ada2 CVD fix).
- Method: mean colour of opaque pixels of each anim set's `walk/0` frame; Machado 2009 full-severity protan/deutan/tritan simulation; CIE ΔE76 between the closest ally/enemy pair.
- Actual: normal and tritan PASS; protan ΔE 1.18, deutan ΔE 2.24 for `ranged_basic` (archer) vs `boss_warlord`.
- Pass criterion: TH-COL-PROTAN and TH-COL-DEUTAN ΔE ≥ 2.3 (one JND), plus a full-frame CVD review on the secondary monitor. This is a proxy: it ignores silhouettes, the friend/enemy marker and mirroring. If you judge the marker sufficient, show a protan/deutan-simulated battle frame at HEAD with archer and Warlord on screen; 07 will then record the proxy as superseded.

## Theme switch (Q1 = A)
- When the bakery/mould art lands, ART-03..08 must stay PASS (every P0 anim set, projectile, fx, biome, icon, base resolves) and TH-COL-* must be re-run.
- 40 of 69 committed docs images predate baseline d6cf7df (runner `stale_baselines.txt`). New contact sheets/previews are needed for theme verdicts.

Re-confirmed at HEAD 5426645, run 20261031-091441: PASS 137 · FAIL 6 (DATA-13, DATA-14, TH-FIT-HUD-EN, TH-FIT-ROUND-EN, TH-COL-PROTAN, TH-COL-DEUTAN) · NOT_IMPLEMENTED 1 · NOT_TESTED 2 · BLOCKED 0.

## Re-test 2026-10-31 15:40 at HEAD 2884231 (run 20261031-153757, -Head)
- QA-B011 still FAIL but the closest pair moved after your D14 recolour: protan `siege` vs `e_brute` ΔE 1.96; deutan `siege` vs `boss_overlord` ΔE 1.75 (pass ≥ 2.3). Archer vs Warlord is no longer the closest pair. Reproduce: `.\tools\qa\run_acceptance.ps1 -Head -Only theme`.
- 107 committed docs images predate baseline cbfb0a8 (docs/verification/runs/head-2884231-stale-baselines.txt).

## Re-test 2026-10-31 15:50 at HEAD abe2303 (run 20261031-154903, -Head)
- QA-B011 still the only FAIL at HEAD: protan siege vs e_brute dE 1.96, deutan siege vs boss_overlord dE 1.75. Re-run after the bakery/mold art lands.

## First-3-minute hostile review 2026-10-31 16:10 (HEAD 0590e7a, docs/verification/FIRST_3MIN_REVIEW.md)
- **QA-J1 (P2)**: battlefield framing and theme. Rendered r01 frames: ~75% of frame is sky/mountains; biome still generic meadow (no bakery/mould world); first 60 s show no enemy except one grey shape at the right edge. Pass: bakery/mould biome layers + TH-COL-* PASS (QA-B011, still FAIL; no new art commit since 2b350c4 at 16:10). Re-test: capture_visual.gd at new HEAD, same 4 configs.
