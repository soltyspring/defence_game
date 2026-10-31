# 02-engine handoff — CHECKPOINT (user stop request)
Updated: 2026-10-31 09:25 +09:00
Status: STOPPED at a safe point. Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session (do not guess).

## User decisions
Theme decided: A "빵집 기사단 vs 곰팡이 군단" (data IDs unchanged). User: fix all reported defects.

## Done in this session (all pushed unless noted)
- 1eb4637 engine foundation; fdd4d86 Android APK + atlas import; e9dfaa4 tutorial/audio cues/battle_uid/sorted targeting.
- 08ef082 save hardening: QA-B004 P1 backup rotation, B003, B005, B006, B007, R6 fault hook, R3 battle_uid ledger; f807823 SHA notes.
- d660311 step 1: `--import` under build/.godot-import.lock (exit 0). ui_main, char_player_adv, char_enemy_adv, char_boss_warlord, char_boss_overlord: uid + lossless + no-mip, .ctex present. Headless residency: r01 6 pages 5.25 MiB, r05 9 pages 7.25 MiB, r10 10 pages 9.25 MiB, all `"source":"import"`.
- Step 2 + seam fix (this checkpoint commit, SHA at bottom):
  - Integer pixel scale that fills the screen. Measured: Godot `scale_mode="integer"` alone letterboxed (1600×900 window → 640×360 view). Fix: `App._apply_pixel_scale()` sets `root.content_scale_size = window / k`, k = max(1, min(w/640, h/360)), on boot and every resize; project.godot keeps `scale_mode="integer"`. Visible secondary-monitor runs (tools/build/visible_launch.ps1, DISPLAY2): 1280×720 → view 640×360; 1600×900 → 800×450; 1600×720 → 800×360. 2×2 block uniformity of captures: 99.51 / 99.74 / 99.67 %.
  - Camera bottom-anchored (`cy = 360 − vh/2`), background fills taller views (more sky).
  - 03 A4 white seams: `_draw_biome_layers` rounds the layer origin once and steps by exact tile widths. Same condition as 03 (r01 start, cam_x 230, 1280×720): columns 432 and 570 now contain 0 pale `#e3f3ff` pixels and match their neighbours (55/55 and 83/83 rows). 03 should rerun its own detector.
  - export_presets.cfg include_filter adds `assets/fonts/*.txt, assets/fonts/*.json` (OFL, 04 R12-1 / 03 A2b).
  - App boot/screenshot logs print view/window/scale.
  - Regression: selftest PASS; UI integration 31/31.

## Not done (exact next steps)
1. `-Head` reruns: `.\tools\qa\run_acceptance.ps1 -Head -Only faults` and `-Head -Only save` on the pushed HEAD (workspace run before was PASS 16 / FAIL 1, TP-13a coin cap 9 999 999 vs 07's 999 999).
2. Ask 04 to re-run the 2.5× capture (1600×900 → expected 800×450, odd-run %); ask 07 for an independent visual check. Request files not written yet.
3. 06 S1: add `Services="*res://src/services/services.gd"` after Audio in project.godot; run tests/services/test_services_integration.gd (expect I1–I4 no longer BLOCKED). Not started (line was reverted, unverified).
4. 05 A7: in App quit paths call `Audio.prepare_quit()`, wait 0.3 s wall-clock, then quit; verify with `--headless --verbose -- --round=r02 --quit-after=20` (no AudioStream/Ogg leaks). 05 A8 RefCounted cycle after deployments.
5. 01 open decisions: passive loss time (~258 s on 01's 09:04 data), 900 s timer rule.
6. 04 R12-2 release preset excludes, R12-3 emulator install slot; 08 P1/P4/P5; 07 QA-R1 hooks; 03 A3 shadows/markers/prop_mine.

## Processes
No Godot process of mine is running (all runs were `--quit-after`). The headless emulator `emulator-5580` (LaneDefence_Phone) started by 02 was shut down with `adb emu kill` at this checkpoint.
