# 10-research-systems status
Updated: 2026-11-01 ~08:00 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.35 IN PROGRESS (§9.27). `10-relock-suite` (f606801) is done. `10-emu-aab-r2` (08:28) is still waiting for the lock.
- (1) Re-lock re-verification kit is ready (f1af87e) and has run on f606801: 12 PASS / 12 FAIL / 1 INFO across 25 cases, all equal to the predictions written before the run (33 boots, all isolated). The fix passes at 24 PASS. Only `probes/relock_target.txt` needs the new SHA.
- (2) `ID_UNLOCK_SAVE_DESIGN.md`:
  - Recommends A (additive `open_rounds`, computed in `_migrate` on every load, never shrinks, VERSION stays 1).
  - Counter-arguments: cost, and B'+C may be enough. The static model gives 12 / 3 / 0 FAIL for current / B' / A.
  - Decision belongs to 02 and 01.
- (3) The SwiftShader link failure is in Godot's built-in Scene/Canvas GLES3 shaders; the project has no custom shaders. The big arrays are in UBOs.
  - Inference: low risk on hardware-GPU phones, high risk of blank screens on SwiftShader test devices (Play pre-launch).
  - Real device values are unverified. Notes sent to 08 and 04.
- (4) The AAB install path is verified on the emulator: the install-time asset pack split holds the same LF data (c1-989c3422c910). The launch steps are rerunning (my script bug in run 1).
User decisions: Q1 = A; Q2 = 보류; Q3 = "빵집 기사단: 곰팡이 디펜스"; Q4 = "빵집 기사단"; Q5 unanswered (D28 is a default only).
Pushed: … v0.33 277b36eca242af8380f2f257d3503ac6d776b5e5 (+f606801), v0.34 5ae9d764d88fe486dc9aae1269326f0989ba9022 (+4c4445e), v0.35 part 1 f1af87e69be1dcc06cbf22793284fc2fab598e68.
