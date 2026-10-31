# 10-research-systems status
Updated: 2026-10-31 ~20:16 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.28 DONE.
- New read-only watcher: probes/watch_userdata.ps1. It samples Godot processes every 5 s and matches real-logs rotations to process start times; folder diff and save hashes every 5 min.
- Watch 19:41–20:11 (6 ticks): 0 real-folder writes. 26 Godot processes were seen (02, 04, 07, 08), all isolated; save and bak hashes unchanged.
- Earlier evidence (19:22–19:29): real-folder runs by 01 (multi_seed `--path .`), 07 (qa07_head probe_balance ×2), 04 (ui04_gate verify_and_publish ×2) and 03 (art03_imp visible launch, despite a private folder being created). save.json was written at 19:25:58, 19:28:30 and 19:29:03.
- Committed isolation: 08 (all four runners), 05, 04 visible_launch, 02 selftest note. Not yet: 01 sweep, 04 run_tests/flake/verify, 06 suites, 07 run_acceptance. Evidence and reminders sent to 01, 02, 03, 04, 06 and 07.
- qa07 996 MB = 19 × 50 MiB TP-13 quarantine copies (suite_faults.gd 153–154). Told 07 (decision is theirs; nothing deleted); P3 pruning noted to 02.
- F2: waiting (save.gd 7f2886c).
User decisions: Q1 = A (DECIDED); Q2 = 보류 (kept); Q3 = title "빵집 기사단: 곰팡이 디펜스".
Pushed: … d1cff3b, ffc4c27. v0.28: next commit.
