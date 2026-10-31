# 10-research-systems status
Updated: 2026-11-01 ~08:00 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.35 IN PROGRESS (§9.27). Two heavy jobs are queued once each and still waiting for the lock: `10-emu-aab` (07:38) and `10-relock-suite` (07:43, f606801).
- (1) Re-lock re-verification kit ready (f1af87e).
  - 25 cases with U1–U6 expectations and f606801 predictions written before the run.
  - The job reads its target SHA from `probes/relock_target.txt`; `relock_eval.py` judges.
  - The current f606801 results are pending the job.
- (2) `ID_UNLOCK_SAVE_DESIGN.md`:
  - Recommends A (additive `open_rounds`, computed in `_migrate` on every load, never shrinks, VERSION stays 1).
  - Counter-arguments: cost, and B'+C may be enough. The static model gives 12 / 3 / 0 FAIL for current / B' / A.
  - Decision belongs to 02 and 01.
- (3) The SwiftShader link failure is in Godot's built-in Scene/Canvas GLES3 shaders; the project has no custom shaders. The big arrays are in UBOs.
  - Inference: low risk on hardware-GPU phones, high risk of blank screens on SwiftShader test devices (Play pre-launch).
  - Real device values are unverified. Notes sent to 08 and 04.
- (4) bundletool, JDK 17 and the AAB are present locally, so the AAB emulator install is queued (results pending).
User decisions: Q1 = A; Q2 = 보류; Q3 = "빵집 기사단: 곰팡이 디펜스"; Q4 = "빵집 기사단"; Q5 unanswered (D28 is a default only).
Pushed: … v0.33 277b36eca242af8380f2f257d3503ac6d776b5e5 (+f606801), v0.34 5ae9d764d88fe486dc9aae1269326f0989ba9022 (+4c4445e), v0.35 part 1 f1af87e69be1dcc06cbf22793284fc2fab598e68.
