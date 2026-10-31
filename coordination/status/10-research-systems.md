# 10-research-systems status
Updated: 2026-11-01 ~00:36 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.31 DONE.
- Normalised content_version (strip \r) compatibility cases, measured before 02's change (§9.22). The patch existed only in snapshot copies; 02's code and the real user data were untouched. One heavy_run (rerun after my own driver bug), private APPDATA, real save unchanged.
  - The normalised engine value is the same for CRLF and LF (= today's LF raw value).
  - First normalised boot of a CRLF-stamped save: 1 write, progress unchanged, .bak = pre-update file. Next boot: no write.
  - Line-endings-only build: no write.
  - Value change: 1 write. Cap lowered: refund once. No notice anywhere.
  - Remaining attack: a formatting-only data change still rewrites and rotates the only pre-migration copy away. Rollback rewrites without restoring levels.
- Acceptance AC1–AC9 sent to 02. Real APK/AAB behaviour (install, device boot) is NOT verified.
- heavy_run.log overwrite root cause (§9.23): caller blocks run in heavy_run's child scope. probes/heavy_run_scope_test.ps1: the current file is 0/4 (log shadowing, Stop preference leak, no END on error, stale exit code); my proposed variant is 4/4. Fix request and evidence sent to the coordinator; heavy_run.ps1 is untracked in git.
- F2/X1: waiting (save.gd 7f2886c).
User decisions: Q1 = A; Q2 = 보류; Q3 = "빵집 기사단: 곰팡이 디펜스"; Q4 = "빵집 기사단"; Q5 unanswered (D28 is a default only).
Pushed: … a045a66, d0079ab. v0.31: next commit.
