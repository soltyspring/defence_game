# 10-research-systems status
Updated: 2026-10-31 ~19:22 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.27 DONE.
- Real user folder backed up read-only: %LOCALAPPDATA%\defence_userdata_backup\20261031-191353\Lane Defence (299 files, 997 MB; 298 match the source, logs/godot.log was locked). Manifest only in git: evidence/userdata_backup_20261031-191353/MANIFEST.tsv. Restore steps in §9.18.
- Update scenario on real boots (private APPDATA):
  - v2 first boot: melee L5→3 (+350), ranged L4→3 (+160); the retired worker stays at L4 with no effect and no refund; no notice is shown.
  - The pre-update save survives only as .bak, which is lost after the next save or a rollback boot.
  - Rolling back to v1 does not restore levels; rebuying with the refund reproduces the v1 state exactly.
- Requests: 01 (D26: refund amount, retired upgrade, notice text, downgrade policy; recommends "no max_level decrease after launch"); 02 (pre-migration backup kept outside rotation, migration summary and notice signal, no write when nothing changed); 04 FYI (menu notice path).
- F2: waiting (save.gd 7f2886c).
- New probe probe_update_scenario.gd plus a clean-import uid.
User decisions: Q1 = A (DECIDED); Q2 = 보류 (kept); Q3 = title "빵집 기사단: 곰팡이 디펜스".
Pushed: … a9e0a5f, d1cff3b. v0.27: next commit.
