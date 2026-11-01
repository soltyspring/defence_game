# 12-text-review handoff
Updated: 2026-11-01 09:05 KST
Session: sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2 (Kiro CLI, claude-opus-5.5, trust-all; window opened by user approval 2026-11-01 08:27 KST "창 추가해")
Owner paths: docs/review/text/**, coordination/status|handoffs/12-text-review.md, coordination/requests/12-text-review-to-*.
Read and followed: BRIEF.md, OWNERSHIP.md (Review expansion), GIT_WORKFLOW.md (Publish-Task.ps1 only, explicit paths, no add ./-A, no reset/rebase/stash/force). Decisions read up to the "D38/D40 correction" row; user decisions Q1 A, Q2 보류, Q3 working title, Q4 launcher label, Q5 B (from the start prompt).
Never ran Godot, editor, import, export, emulator, adb, Gradle or heavy_run.

## Current task
TEXT_REVIEW_01 — DONE and pushed. No task in progress.

## Delivered (pushed)
| SHA (git ls-remote origin main after push) | Files |
|---|---|
| 3f70e92eeab7916a6fe5fe3e2a47d60032a10331 | docs/review/text/TEXT_REVIEW_01.md, measure_text.py, evidence/text_width_report.json, evidence/measure_text_stdout.txt; requests 12-text-review-to-{01-director,02-engine,03-art,04-client,coordinator}.md; this handoff and status (first versions) |

## Actual validation
- `python docs/review/text/measure_text.py` exit 0 (stdout saved in evidence/measure_text_stdout.txt).
- Width method vs Godot-measured widths: 106/106 equal (build/qa/typography_report.json 2026-10-31 17:28, 04 R4 name probe, 07 QA-B009). Without GPOS kern 94/106.
- 08:01 gate failure reproduced: 640×360 + notch 34/34, 5 cards/3 skills, t=40, first B order: card 41.33 → button 41 → name slot 35; all six ko card names are 36 px → 1 px over. HEAD 85d22bd slot 37, current 04 WIP slot 39.
- Limits: static calculation only, no rendered frame, no phone, no human. 04's hud_layout.gd WIP is uncommitted; numbers for it may change when 04 commits.

## Main findings (details in TEXT_REVIEW_01 §5)
P2: T-01 en wave line cuts the countdown (r05/r06/r10, 640+notch); T-02 `+x/s` income never drawn on 640-wide views (ko 0.68 px short); T-05 D31 hint lines wrap to 2 lines, not drawn yet; T-06 "기력" shown in r01 with no skill; T-08 r01 deploy hint waits for hero move (up to 20 s, wave 1 at 12 s).
P3: upgrade names 보급/일꾼/Base Armor, en Pretzel Riders vs card Twist, enemy names not shown on screen, "메뉴로" goes to round select, raw code in ui.upgrade_error, en Select Round at 10 px, 02 fallback content English names, 04 fallback drift.
Store (frozen, to coordinator): 기술 vs 스킬, "no ads/IAP" promise under Q2 보류, 반죽 caption, stale "Lane Defence" window-title notes.

## Next steps (for the next session)
1. Read replies appended to coordination/requests/12-text-review-to-{01-director,04-client,02-engine,03-art}.md and coordinator notes.
2. After 01 changes data/text or 04 commits hud_layout.gd/hud_top.gd: re-run `python docs/review/text/measure_text.py` (needs build/qa/typography_report.json only for calibration), compare with evidence/text_width_report.json, write TEXT_REVIEW_02.md with before/after per key, publish.
3. Not done yet (candidates): r02–r05 tutorial/skill wording walk (skill buttons show names only on press: which button is 갓 구운 함성 in r04), result/upgrade screen wording after D31 is drawn, en/ko tone pass of round names.
Dependencies: 01 (text), 04 (layout commit, D31 drawing). No user question pending from 12.

## Errors
None. Publish warnings were only LF→CRLF notices.
