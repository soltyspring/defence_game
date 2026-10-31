# 10-research-systems status
Updated: 2026-11-01 ~02:50 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.32 DONE (02 52f9fa3 re-verified, §9.24).
- (a) probe_r5_cases 9/9 PASS (F2 fixed; R2m paid 410 and R6r retire +420 match D32); upgrade_transaction C1–C13 PASS, C6 8/8. Part D (hand-edited L9) unchanged, P3.
- (b) Update scenario S1–S4b via the wrapper: retire+refund and paid refunds work; save.pre-<cv>.json = pre-update file, kept through saves and rollbacks; rollback boots no longer write (X1); notice stored and cleared by ack.
- (c) run_content_migration: M1/M2/M4 (1,584 / 1.30)/M5b (1.60) match. The first attempt was invalid (tool limit killed the wrapper, child stopped, result discarded); rerun as a detached heavy job.
- (d) AC1 FAIL (CRLF ≠ LF content_version; content.gd not normalised); AC2–AC8 PASS; AC9 UNVERIFIED (no APK/AAB with 52f9fa3 built or installed; no device boot). The content_migrated UI path is not covered by headless runs.
- userdata_canary.ps1 is now hash/mtime/size based against a baseline (X1 removed the rewrite signal). 00:57→02:42: save unchanged, no real-folder runs; 214 qa07 removals (07 move, destination not checked).
- heavy_run.ps1 (coordinator 01:20 install) passes the scope test 4/4. H5 (tool-limit kill → overlap) reported.
User decisions: Q1 = A; Q2 = 보류; Q3 = "빵집 기사단: 곰팡이 디펜스"; Q4 = "빵집 기사단"; Q5 unanswered (D28 is a default only).
Pushed: … 4dcb3f6, f8a2b44, v0.32 7f45b5f8e8ad0e606bda63e80569a6983a8767e1.
