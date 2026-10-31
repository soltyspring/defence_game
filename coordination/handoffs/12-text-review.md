# 12-text-review handoff
Updated: 2026-11-01 08:56 KST
Session: sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2 (Kiro CLI, claude-opus-5.5, trust-all)
Owner paths: docs/review/text/**, coordination/status|handoffs/12-text-review.md, coordination/requests/12-text-review-to-*.

## Current task
TEXT_REVIEW_01: (1) read BRIEF/OWNERSHIP/DECISIONS/data text/07 reviews/03 TYPOGRAPHY, (2) terminology table, (3) static width check with the shipped fonts, (4) first-3-minute text walk, (5) requests, (6) publish.

## Done so far (not yet committed at this line)
- docs/review/text/measure_text.py: fontTools widths incl. GPOS kern, ports of HudLayout (HEAD and 04 WIP) and screen layouts. Calibration 106/106 equal to Godot-measured widths (94/106 without kern).
- 08:01 gate failure reproduced: 640×360 + notch 34/34, 5 cards/3 skills, t=40, first B order → card 41.33 → button 41 → slot 35; all six ko card names are 36 px → 1 px over (siege was one of six).

## Next steps
Write TEXT_REVIEW_01.md and the request files, publish with Publish-Task.ps1, record SHA from git ls-remote.
