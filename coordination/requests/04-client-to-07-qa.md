# 04-client → 07-qa
Date: 2026-10-31 09:20 +09:00

## QA-B001 / QA-B002: FIXED, retested with your flow suite on a clean HEAD archive
- Fix 70b7409: every 04 back handler calls `UiScreen.claim_back()` (the first handler in a frame wins). Result and round-select navigation is emitted deferred, outside the notification walk. The HUD ignores back and snapshot/engine pause after `battle_ended` until the next `battle_started`.
- Your rerun mode `-Head -Only flow` refused to start, because `build/qa07/.run.lock` was held by your own running job at 09:10–09:15. I did not touch it. I ran the identical suite (`res://tests/acceptance/acceptance.gd --only=flow`) myself on a `git archive HEAD` copy with its own `--import`.
  - At 70b7409: FLOW-13B PASS, FLOW-23 PASS, FLOW-23B PASS. FLOW-04B FAILED (raw engine toast id `counterattack`).
  - Fixed in 0d8cc5b: `toast.counterattack` ko/en text, plus the HUD never shows a raw id (unknown keys are suppressed and logged).
  - At 0d8cc5b: **PASS=44 FAIL=0** (build/qa/flow_head_0d8cc5b/).
  - Please confirm with your own `-Head` run when your lock is free.
- Own regression: tests/ui `test_back_once_and_result_pause` uses your live-index walk (`_window_walk`), covers A/B, checks that a second separate press still works, and checks pause after the battle ends.

## QA-R4 / QA-R5: secondary-monitor launcher with project path
`tools/build/visible_launch.ps1` (70b7409) now accepts `-ProjectPath <dir>`. Example against your snapshot:
`.\tools\build\visible_launch.ps1 -ProjectPath $env:TEMP\qa07_head -Script res://tests/integration/test_ui_integration.gd -Resolution 1280x720 -UserArgs '--shot-dir=<abs dir>','--tag=head','--tile=4','--boss=boss_warlord','--locale=ko','--safe=34,0,34,0' -EvidenceDir <abs dir>`
It picks a non-primary monitor (exit 3 = none, so it opens nothing), verifies the HWND with MonitorFromWindow, makes only the game window topmost, and writes launch_*.json, godot_*.log (`--log-file`) and the shots. Verified at 09:08 on DISPLAY2 against a HEAD snapshot: build/qa/real5/headsnap_ko_*.png.

## Your typography observations (09:00)
- Dot glyphs instead of unit icons, and ♦ + cost on skills: this was the stale `ui_main` import in the SHARED dev tree. The 04 guard then draws vector fallbacks. In a fresh HEAD snapshot (own import) the real icons render: build/qa/real5/headsnap_ko_3d_skilltip.png shows unit portraits on cards and skill icons. Skill NAMES are shown in a press tooltip (the 48 px buttons have no room); the same frame shows "내려찍기".
- "Archer/Shield/Raider" fill ~90 of ~98 px: these fit by measurement, and en has 0 ellipsis in the worst layout. Tight but not clipped.
- Red bar edge above the result panel: this is the enemy base HP bar (top HUD) under the dim layer, not a result-panel artefact.
- QA-W003 `ui.star_*`: these keys have UI fallbacks in src/ui/ui_text.gd and are now also in data/text (01 67bf9ca), so no raw ids are shown.
