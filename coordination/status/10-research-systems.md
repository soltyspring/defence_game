# 10-research-systems status
Updated: 2026-11-01 ~07:45 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.34 DONE (§9.26). Resumed after the 03:55 BSOD: my two queued jobs never started (nothing to discard), files intact, each job queued once again.
- (1) Round re-lock cause confirmed:
  - The cause is save.gd step 5 (lines 506–517) recomputing unlocked_round from stars on every content_version change. The rule is 10's own v0.15 §9.6 proposal, not D32 (DECISIONS.md has no unlock rule).
  - Real boots, isolated 17/17. A real-play save (r01–r05 cleared, unlocked 6) loses cleared rounds with no notice when an update:
    - inserts 2 rounds (6→3), or 1+1 across two updates (7→3),
    - moves a cleared round to the end,
    - or renames 2 rounds without round_renames (6→3).
  - Safe: cap/cost/bytes changes, one insert, one removal, rename with map.
  - The v0.33 L2 6→3 came from my inconsistent test save. Correction: an all-cleared save is rewritten on any content change (11→10), so §9.24 AC2 is FAIL for that save.
  - release_guard.py now flags ROUND_RELOCK. P1 request to 02 with U1–U5; rule questions to 01; TP-05 cases to 07.
- (2) AC9: emulator confirmed, not verified on a real phone. Ran LaneDefence_Phone with -no-window and SwiftShader, and installed the eb8d5c4 APK.
  - The device computes c1-989c3422c910, the same as the package and repo LF.
  - Refund 250, pre-backup, notice, restart and Back-ack all match desktop. refund_unknown shows in logcat. 0 app crashes.
  - The screen could not be judged: SwiftShader failed to link the GLES3 shaders (uniform limit 261), so the frame was blank. AAB install not tested.
- (3) git archive table: 16 code calls.
  - 4 LF-pinned (including both release paths), 1 autocrlf=false only, and 9 with no flags in 07/04/05/08 files.
  - 2 of mine had no flags and are now LF-pinned (not rerun).
  - No working-tree or release export script exists yet.
  - Requests sent to the owners. .gitattributes has no owner in Publish-Task (coordinator).
- Canary 07:00/07:24: no change (614A1FAC560FBB78).
User decisions: Q1 = A; Q2 = 보류; Q3 = "빵집 기사단: 곰팡이 디펜스"; Q4 = "빵집 기사단"; Q5 unanswered (D28 is a default only).
Pushed: … v0.32 7f45b5f8e8ad0e606bda63e80569a6983a8767e1 (+67ddd04), v0.33 277b36eca242af8380f2f257d3503ac6d776b5e5 (+f606801), v0.34 5ae9d764d88fe486dc9aae1269326f0989ba9022.
