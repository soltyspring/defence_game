# 10-research-systems status
Updated: 2026-11-01 ~03:55 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.33 DONE (release-path bytes and migration-notice UI path, §9.25).
- (1) One pinned commit, eb8d5c4, was built by 04 `build_android_debug.ps1` (APK) and 06 `try_debug_aab.ps1` (AAB) in one detached heavy job (`10-pkg-bytes`, no install).
  - Both packages hold 21 data JSON with 0 CR / 2,758 LF, byte-identical to each other and to the git blobs.
  - Both give content_version **c1-989c3422c910** = repo LF. **Verdict: the two paths are the same.** CRLF would be c1-40bde75d24c2.
  - The AAB keeps data in `assetPackInstallTime/assets/data/`. 10's content_version.py looked in `base/` and read 0 files at first; fixed and re-read.
  - The earlier claims are now split into measured and inferred: "APK/AAB = CRLF" held only for the old scripts. AC9 device part is still UNVERIFIED (no install, no device boot).
- (2) 04 test_migration_notice.gd: run once with a private APPDATA, 16/16 ok. It uses the real App and menu and reads the real file. The data change is emulated in memory, and its relaunch is in-process.
  - 10's real-boot probe (`10-notice-cases`) checked:
    - Two updates before an ack add up (2 levels / 350, from first, to last).
    - Pause keeps the notice.
    - A real restart shows it again.
    - Close clears it from the file.
    - A refund-0 update says "0 골드를 돌려드렸습니다".
  - Findings sent:
    - 04: leftover `.pre-*.json` per run, no CRLF gate in inspect_apk.py, capture request.
    - 01: refund-0 wording; round re-lock not in the notice.
- (3) No content.gd normalisation up to 02ec60f, so the AC1/AC4 rerun was skipped. AC1 is still FAIL.
- Canary 02:49:27 → 03:36:33: no change (save 614A1FAC560FBB78). All 11 10-run Godot boots isolated.
User decisions: Q1 = A; Q2 = 보류; Q3 = "빵집 기사단: 곰팡이 디펜스"; Q4 = "빵집 기사단"; Q5 unanswered (D28 is a default only).
Pushed: … f8a2b44, v0.32 7f45b5f8e8ad0e606bda63e80569a6983a8767e1 (+67ddd04); v0.33 SHA in the handoff after push.
