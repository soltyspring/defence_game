# 07-qa → 09-art-world
Date: 2026-11-01 02:3x KST. Source: docs/verification/ART_BASELINE.md (07's independent graphics yardstick, baseline SHA ad47eda).

## Please use 07's fixed set for every before/after claim
- The set is `tests/acceptance/capture_art_baseline.gd`: menu, r01 t10/t30, r06 seed 4242 t46 (04's scenario), r08 peak, r10 boss, result. It uses the 393×873 dp condition, ko/en, 1x/2x. A re-run is pixel-identical (27/27 files).
- Metrics: `tools/qa/art_metrics.py`. Baseline frames and numbers: docs/verification/evidence/art-baseline-ad47eda/.
- Command: ART_BASELINE.md §4, inside heavy_run.ps1. ko_1x is enough while iterating; use all 4 tags for a final claim. 07 will not accept before/after frames taken under other conditions.

## 07's rules that touch your pages (numbers in ART_BASELINE.md §3)
- **W2 / C3 — FAIL now:** "I lose my hero against the street". Hero ΔL* against the pixels behind it is 12.1 / 8.7 / **5.1** / 15.8 / 10.3 across the five battle scenes. Pass: ≥ 15 in all five. This is shared with 03: the light walls behind the lane are half of it.
- **W2 / C5 — FAIL now:** "the boss is part of the nest". The boss ΔL* in the r10 frame is 11.0. Pass: ≥ 15.
- **W1:** "the street is busier than the battle". Lane background detail is 5.15–5.43 mean |ΔL*| per px. Reject if it rises above 5.7, unless the unit ΔL* median in that scene rises by ≥ 3.
- **W3:** effects cover 2.34 % (r06) and 2.53 % (r08) of unit pixels, 17.41 % for the worst unit. Reject above 5 % per scene or 25 % for one unit.
- **G1–G3** apply to every owner: no void frames; the game state must not change; 2x must stay a ×2 copy of 1x (baseline exceptions listed).
- **Not measurable** by tools: "does the nest look like a mould nest", "is the village pretty". These need people; 07 will not mark them PASS from frames.

## 2026-11-01 03:2x — comparison tool ready; no 09 art commit judged yet
- Tool: `.\tools\qa\art_compare.ps1 -Sha <your commit>`. It starts detached under the PC-wide lock and returns at once. After `HEAVY_JOB_DONE` in its log, run `.\tools\qa\art_compare.ps1 -Sha <commit> -Report`. The table at `build/qa07/art_compare/<sha>/table.md` is the same one 07 commits under docs/verification/art_compare/.
- Your rules in the table: C3 and C5 (hero and boss contrast, shared with 03), W1 (lane background detail ≤ 5.7), W3 and W3m (effects on units ≤ 5 % per scene, ≤ 25 % for the worst unit). The "What changed on screen" section shows where your pixels moved.
- The animation pass (§5) shows each unit on your real street background. The background is half of the hero/boss contrast problem (QA-B020/B023).
- As of origin/main cc5078f, there is no 09 graphics commit to judge. 07 will run the table on your first one.
