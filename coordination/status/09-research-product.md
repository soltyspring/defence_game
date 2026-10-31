# 09-research-product status
Updated: 2026-10-31 ~19:10 KST
Session: sess_6ce8ebb1-4e45-454d-a561-e0bad09a8be5 · claude-opus-5.5 / trust-all
Status: MILESTONE DONE (v17 first-session comparison, 3a8c340546b8ccb2315044e12a236a705055877d PUSHED). Waiting for 07 R09-07-2 and 01 R09-01-16.
READ: Codex task "첫 세션 경험을 경쟁작과 같은 단위로 비교 (a) 첫 전투까지 시간·화면 수 (b) 튜토리얼 안내 횟수·방식 (c) 첫 결과 화면 정보·버튼".
Done: SUCCESS_ANALYSIS §36.
- (a) Battle Cats EN fresh install (LVI8CNUGnC8): 6 screens, about 3:00 video time. Waggle KR (h52yfbelEnE): 3 screens, about 15–20 s from the title (pre-title [U]). Ours (static code): menu only, 1 tap; time not measured.
- (b) Stage 1 prompts: Battle Cats EN 3 (modal, red arrows, dimming), Waggle 2–3 (spotlight, curved arrows; hand pointer only after the first clear), ours 4 text strips with no pointer. KR Battle Cats videos showed no stage-1 prompt at a 10 s step [U cause].
- (c) First result: Battle Cats XP only + Ok/SNS, then about 8 popups (one paid offer) in about 3:00; Waggle WIN + level bar + 1 reward, no buttons seen. Ours: stars, time, kills, reward, 4 buttons, 1 tap to r02.
- Candidate K1 (pointer on r01 hints ① ②) sent to 01. Design/code gaps sent to 01: RELEASE_DESIGN_REVIEW §2.1 item 1 (single Play button) and item 5 (first-upgrade nudge) are not in the code.
- 07 R09-07-2: fresh-save launch timing, real-time hint log, first-win 4-button result capture.
- Monetization popups are listed in the comparison only and excluded. 몽글뭉치: no source.
No Godot was used by 09.
Next: track R09-07-2, R09-01-13/14/15/16, R09-02-5/6, R09-10-2, R09-04-11, the 07 timing items, the 04 1x capture, the 03 icon and the 06 KIPRIS check.
