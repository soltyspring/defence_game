# 02-engine handoff
Updated: 2026-10-31 07:00 +09:00

## Read receipts
BRIEF.md, OWNERSHIP.md (incl. 05–08 additions), GIT_WORKFLOW.md (acknowledged: Publish-Task.ps1 only, explicit owned paths, bracket convention, no binaries/caches), coordinator-to-02-engine.md through Dispatch R4 + completion review gate + C02, QUALITY_REVIEW.md (secondary-monitor rule acknowledged: future visible runs on non-primary display via `--position`), DECISIONS.md D1–D9 + Q1 pending, 04-client-to-02-engine R1–R7, data/** (01), assets/manifest.json (03).
Processed: 04 R1 (ui_setup after mount: hud {"info"}, result {"result"}), R2 (App handles back only when fallback UI mounted), R3 (screen_shake setting + camera shake), R4 (export_presets.cfg + editor SDK/JDK paths), R6 boss/speed snapshot keys (tutorial pending). D7 caps adopted from data (30/40/64) with engine ceilings.

## How to run
```
$G = ".\tools\engine\Godot_v4.7.2-stable_win64_console.exe"
& $G --headless --path . --import
& $G --headless --path . -s res://src/core/diag/selftest.gd        # exit 0 = pass, report in %APPDATA%\Godot\app_userdata\Lane Defence\selftest_report.json
& $G --path . --position -1600,300                                  # play (secondary monitor); keys A/D move, 1-5 cards, Q/W/R skills, E worker, P pause, F3 perf
& $G --path . -- --autoplay --autoplay-rounds=2 --shots=5,30 --shot-dir=<abs dir> --quit-after=60   # bot preview + screenshots
```

## Evidence: see coordination/status/02-engine.md. Remaining Android items: docs/architecture/ANDROID_BUILD.md.

## Strongest rejection reasons (self-review)
- Rounds 4–10 not won by competent bot with current data → either bot too weak or data too hard; no human playtest yet.
- APK not built; atlas import defect means exported build would currently lose all art.
- Cap stress worst step 14.6 ms on desktop; phone could exceed frame budget at caps.
- Visible preview so far only on main monitor and desktop GPU.

## Next tasks (02)
1. Publish foundation commit (this milestone).
2. Install verified export templates → build debug APK → install on emulator/device if available.
3. Optimise sim worst-case (remove per-hit array duplicates, cache army counts) and measure again.
4. Tutorial step signal (04 R6), hit_frame-timed damage, 2× speed.
5. Secondary-monitor visible preview using 04's launcher when available.
