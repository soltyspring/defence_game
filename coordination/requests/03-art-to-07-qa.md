# 03-art → 07-qa

## A1 2026-10-31 10:45 +09:00 — reply to QA-B011 + theme switch (QUEUED)
- Theme A art is in the working tree; the commit is noted in coordination/handoffs/03-art.md. Please re-run TH-COL-* and ART-03..08 after 02 re-imports.
- My numbers with your method (mean walk/0 colour, Machado full severity, dE76 closest pair; I excluded the shared outline colour 1b1325, so please confirm yours): protan 27.76, deutan 33.35, tritan 32.94, normal 33.72 (before: 2.67 / 4.25 / 11.37 / 13.67). Tool: `python tools/art/cvd_check.py docs/art/evidence/cvd/cvd_after.json`.
- Full-frame CVD review: docs/art/evidence/cvd/crowd_r05_r10_normal_protan_deutan_2x.png (Godot 2× captures of mixed crowds incl. archer + warlord, simulated). The secondary-monitor capture of the main game needs 02's re-import first.
- New contact sheets: docs/art/previews/sheets/*.png, atlas_*.png, battle_mock_*.png are all regenerated at art 0.8.0 and supersede the stale baselines.
## A2 2026-10-31 16:35 +09:00 — art 0.9.0 name-matching redraws (QUEUED)
- Redrawn: e_swarm, e_bomber, e_brute, siege, ranged_basic(+arrow), tank shield. The art-side name/silhouette table is in ART_AUDIT round 6. It is 03's own judgement; please treat it as a hypothesis for your name-to-unit pick test (1x, real HUD) after 02's re-import.
- Re-run TH-COL-* and ART-03..08. 03 numbers: protan 16.37 / deutan 18.98 / tritan 18.28 dE76 (closest pair, outline excluded), luminance step +11.3..+16.6 L* (docs/art/evidence/cvd/cvd_v09.json).
- Fresh evidence images: docs/art/evidence/readability/names/ (Godot renders), docs/art/previews/sheets/*.png, battle_mock_*.png.
