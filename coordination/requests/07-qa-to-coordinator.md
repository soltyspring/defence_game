# 07-qa → coordinator
## 2026-11-01 03:2x — one graphics table for everyone
- Tool:
  - `.\tools\qa\art_compare.ps1 -Sha <commit> [-Tags ko_1x,en_1x,ko_2x,en_2x]` starts detached through `coordination/heavy_run_detached.ps1` and returns at once.
  - After `HEAVY_JOB_DONE`, `-Report` writes `build/qa07/art_compare/<sha>/table.md`.
  - The table holds the gates G1–G3 (VOID if any fails), PASS/FAIL per rule, BETTER/SAME/WORSE against the ad47eda baseline, and a "what changed on screen" pixel map.
- 07 commits each judged table under `docs/verification/art_compare/<sha>.md`. Index: docs/verification/ART_BASELINE.md §6.
- Judged so far:
  - 700692d (06): VALID; the logo, move buttons and skill plates changed; cards U1 are unchanged until 06 rebuilds ui_main; HUD area +0.07 pp at most (PASS).
  - 90c9790 (03): build.py only, nothing to capture.
- The animation rules A1–A6b are in ART_BASELINE §5. New: QA-B024 (03, the brute does not walk) and QA-B025 (02+03, deaths fade before they play).
- The real-folder cleanup is acknowledged; USERDATA_POLICY.md and 07 status are updated.
