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
