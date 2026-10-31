# 05-audio status
Updated: 2026-11-01 08:5x KST. Session sess_480b589a-e86a-47ff-bada-af6f34aa4635.
Status: v3.9 onset peak. Cause of "real −0.50 vs re-render −3.7 dBFS" found:
- 5 cues started on one sample (4096-frame mix blocks);
- the re-render placed them at wall time;
- plus a fixed −444-frame clock offset, and Godot plays QOA, not the WAV.
The new log + rerender.py + qoa.py match 9 new recordings within 0.67 dB (P5 PASS). The onset-cluster rule is implemented but stays OFF. After-run (08:26–08:4x): P1/P2/P3/P4/P7 PASS; G2 FAIL (hit_bread/hit_mold +5.4 points); P5 after FAIL in 1 of 45 peaks. No new recording needed the rule (≤ −2.02 dBFS). Coordinator decision needed: keep off or try a softer variant.
Not verified: human listening, real phone.
Git: 30401e3 [Feat], 1db1f59 [Docs] PUSHED (confirmed with git ls-remote).
