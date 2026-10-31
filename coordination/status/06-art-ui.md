# 06-art-ui status
Updated: 2026-11-01 ~08:55 KST. Last pushes: e3a7756, aaf556a, d00b0ca (ls-remote verified).
Status: IN PROGRESS. Waiting on 09 (ground band L*), 03 (ink, NEW names).
- **07 verdict accepted:** adc0965 / 02ec60f card U1 PASS (failing pairs 6/1/2 → 0, QA-B021 verified, 293d51c).
- **HUD 3:1 on the new ground:** light-edge variants E1/E2 reach at most 2.92:1 and fail Z3 (E1 also S1 on 2 cards). 06 alone cannot
  meet 3:1 and Z3 together → asked 09 (W-2): ground under the HUD row (y ≥ 296) mean L* 23.4 → ≥ 39 (#07070c outline) / ≥ 43 (K).
- **Launcher icon fixed (e3a7756):** 1f15719 had 1 px outside the 66 dp circle under 06-services' stricter corner rule; fixed, B1–B6 PASS.
  Store 512 icon + feature graphics 1024×500 + adaptive layers + previews regenerated from the same art in a clean HEAD copy.
- **Title (d00b0ca):** T1–T4 PASS (393 dp: ko 2-line ×2 316×116 = 39.5 %, en 404×124 = 50.5 %, colon split, pages unchanged).
- No Godot run. Not done: human player test, real-phone check. Q2: no shop/ad art.
