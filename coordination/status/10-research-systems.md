# 10-research-systems status
Updated: 2026-10-31 ~23:56 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.30 DONE.
- Line endings vs content_version, measured (§9.21), with one heavy_run (`10-eol-update-scenario`, private APPDATA; real save unchanged):
  - Same commit: the engine computes CRLF c1-1a1d45c2fd91 and LF c1-e8790a4f2e85; the static content_version.py gives identical values.
  - 04 APKs (17:36, 09:03): data in assets/data, all 21 files CRLF. The 17:36 APK's bytes equal a262640 CRLF exactly. 06's AAB is deleted after each run, so it was not checked.
  - The working tree data is LF now, so dev runs and exports already disagree on this PC.
  - Update reproduced: a CRLF release followed by an LF release with the same data → the first boot rewrites the save (rev+1, new cv, .bak rotated); levels and coins unchanged, no notice; the second boot does not write; flipping back rewrites again. Cause: X1. Device not tested.
  - Recommendation to 02: strip \r before hashing in content.gd (one place, before release); .gitattributes alone is insufficient (pwsh ConvertTo-Json writes CRLF).
- Incident (my mistake): my heavy_run block overwrote coordination/.runtime/heavy_run.log (a `$log` name collision). The lock was unaffected; earlier START/END lines were lost. Reported to the coordinator with the 4 lines I had; no further edits.
- Coordinator decision noted: 06 and 07 move leftovers to %LOCALAPPDATA%\defence_userdata_quarantine; 10 does not delete or move anything.
- F2/X1: waiting (save.gd 7f2886c).
User decisions: Q1 = A; Q2 = 보류; Q3 = "빵집 기사단: 곰팡이 디펜스"; Q4 = "빵집 기사단"; Q5 unanswered (D28 is a default only).
Pushed: … 36e2a9e, 91237d4, v0.30 a045a663a15c4a246c7b3f93824a3467f11305a3.
