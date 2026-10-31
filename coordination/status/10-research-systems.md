# 10-research-systems status
Updated: 2026-10-31 ~19:14 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.26 DONE.
- Real user folder contamination (P1): Godot resolves user:// from %APPDATA% plus config/name (engine source S32), and every run with autoloads boots Save, which (since R5) rewrites save.json after any data change.
  - Private-APPDATA experiments: X1 a no-op boot rewrites the save; X2 a second boot does not; X3 with edited data a no-op boot clamps L5→L3 and refunds 350.
- Inventory: isolated = 03, 05, 10. Not isolated = 01 sims, 02 diag Run lines, 04 run_tests/flake/verify/visible_launch, 06 suites, 07 acceptance, 08 perf. Requests sent to 01, 02, 04, 06, 07 and 08 with file and line numbers.
- Common method: private APPDATA per child process (wrapper probes/isolated_godot.ps1, which proves isolation by finding the run's godot.log in the private folder). Snapshot rename / custom_user_dir is for copies only; a Save.path redirect alone is insufficient.
- F2: not fixed (save.gd 7f2886c); waiting.
- .gd.uid for probe_r5_cases and probe_noop_boot made by a clean import (private APPDATA); no collisions.
- I did not write to the real user folder; all my Godot runs used a private APPDATA or a renamed snapshot.
User decisions: Q1 = A (DECIDED); Q2 = 보류 (kept); Q3 = title "빵집 기사단: 곰팡이 디펜스".
Pushed: … 14e1f19, a9e0a5f. v0.26: next commit.
