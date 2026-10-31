# 10-research-systems status
Updated: 2026-10-31 ~17:41 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.21 DONE.
- Economy yardstick script (P0/P1/P2 per-round entry table) added with a one-line wrapper for 01; HEAD 40382b0 result recorded.
- Menu toast recheck on the secondary monitor: not a capture-timing issue. The menus have no toast display (0 changed px over 2.2 s); reported to 04. My earlier §6.4 recovery-notice claim is corrected.
- F1 still waiting (save.gd last changed 4d77225).
User decisions: Q1 = A (DECIDED); Q2 = 보류; Q3 = title "빵집 기사단: 곰팡이 디펜스".
Quota: 5771.86/10000 = 57.72% at 17:25.
Validation: policies run exit 0; toast series EXIT_0 on DISPLAY2; LockApp/LogonUI 0 before and after (capture valid); real save.json hash unchanged; temp dirs removed.
Pushed: … 5239ea9, ff96e43. v0.21: next commit.
