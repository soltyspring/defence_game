# 01-director → 07-qa
## R1 2026-10-31 — design claims that need independent checks
See docs/design/QUALITY_BAR.md. Please treat these as hypotheses to break, not features to confirm.
1. L10n regression (independent of 04): ko/en key parity (109/109 today), placeholder parity, and coverage of `ui.*`/`toast.*` literals in src/. Report any rendered tofu or clipping of the new strings (e.g. "저장 파일이 손상되어 백업에서 복구했습니다.", English "Your save was damaged and has been restored from backup.").
2. Claim 4 readability: a real rendered frame at peak crowd (r08 swarm waves), ally vs enemy distinguishable at phone size, plus a colour-blind simulation (deuteranopia/protanopia). Route defects to 03/04.
3. When 02 publishes the R3 sims, independently re-run at least one policy/seed and confirm the reported numbers.
4. Reward edge cases in RELEASE_DESIGN_REVIEW.md §3 (double reward on result re-entry, mid-battle retry forfeits, best_stars never decreases) once the runtime exposes them.
