# 04-client handoff — CHECKPOINT (user-requested stop for account change)
Updated: 2026-10-31 (checkpoint). Session: C:/Users/aghose/.kiro/sessions/48374e8b85ea0326/sess_a24d01e7-e535-413c-9ff6-d5258090820b (Kiro CLI, claude-opus-5.5, trust-all). Window kept open. No new work started after the stop request.

## User decisions preserved
No theme decision exists yet (Q1 PENDING in docs/design/DECISIONS.md; D1–D10 are DEFAULTS, not user approvals). User directives in force: secondary-monitor-only visible tests, per-task commit+push through Publish-Task.ps1, no window restarts, no account switching by workers, apply the gongmojeon reject→fix→retest method.

## Current task (interrupted)
Bundled Korean font milestone: Galmuri11 / Galmuri11-Bold / Galmuri9 from 03 (commit 5e157e3, assets/manifest.json `fonts`), grid sizes 12/24/36 (numerals 10/20), no OS fallback, stable-width numerals, layout fit at narrow/wide sizes.

## Done in this task (code complete, headless-verified)
- src/ui/ui_style.gd: rewrite. Manifest-driven fonts (ui/bold/num) with pixel flags forced at load (no AA, no hinting, no subpixel, no mipmaps/MSDF, allow_system_fallback=false). Galmuri9 falls back to Galmuri11, never to the OS. FONT_* constants are now 12/12/24/36, NUM_S/NUM_L 10/20. `fit_text` only ellipsizes (it no longer shrinks). Whole-pixel drop shadow replaces the 3 px outline. `digit_cell`, `number_width` and `draw_number` give fixed-cell digits.
- src/ui/touch_button.gd: grid-locked layout (icon / 12 px name / 10 px fixed-cell cost). Skill buttons below 54 px tall show icon+cost only, so skill names are not visible anymore (UX gap, see below). A numeric text is drawn as a big countdown. QA fields `last_text_drawn` / `last_text_truncated`.
- src/ui/hud.gd: banner Bold 24 with a 2 px shadow; toast/banner labels get a dark strip sized to the text (`_fit_label`); respawn shows a numeric countdown.
- src/ui/hud_top.gd: gold is right-aligned in a fixed slot sized to the cap's digits; "/cap", income, army and VS use Galmuri9 10; the wave line uses 12 px with ellipsis.
- src/ui/main_menu.gd, round_select.gd, result.gd: titles Bold 36/24, numbers via draw_number, coin icon from the atlas.
- tests/ui/test_ui.gd: new typography gate. It checks bundled fonts and flags, glyph coverage of the whole ko/en text tables in Regular AND Bold, fixed digit cells, and Korean fit on 3 layouts (640 notch both, 640, 800 notch); English ellipsis is a WARN.

## Validation actually run (after the edits, before the stop)
- Parse check of all changed src/ui scripts: OK. One inference-warning-as-error in ui_style.gd was fixed.
- `tests/ui/test_ui.gd` headless: passed=2323 failed=0. Fonts are bundled from res://assets/fonts/Galmuri11.ttf, Galmuri11-Bold.ttf and Galmuri9.ttf. The ko text table has 230 unique characters with 0 missing in Regular and Bold. No Korean label is truncated.
- English ellipsis: 15 labels (card names at 37–44 px slots, e.g. "Footman" 53 px → "Foo…"; round tiles "Heavy Footsteps" and "Break the Walls"; menu "Select Round"). This is a localisation-expansion defect for 01 (shorter en strings) or for 04 layout. It is not fixed.
- `tests/integration/test_ui_integration.gd` headless with the real App/BattleSim: passed=27 failed=0. Real scenes were mounted, not the fallback UI.
- Report file: build/qa/typography_report.json (git-ignored).

## NOT done / unverified (do not claim)
- No new visual render of the font change. The secondary-monitor captures of menu/round select/HUD/result at 2× and 3× (1280x720, 1600x720, 1280x800) plus one non-integer case (1600x900 = 2.5×) were not taken after the font change. Pixel regularity of the new text is unverified in the 04 UI.
- docs/qa/TYPOGRAPHY_QA.md and QA_CHECKLIST.md still describe the OLD fallback-font state (127/131 chars missing). They are stale and must be updated.
- Requests not yet written: to 02, set `display/window/stretch/scale_mode="integer"` (03 TYPOGRAPHY rule 3; currently not set); to 03, set font .import flags (the current .import has antialiasing=1, hinting=3, subpixel=4, allow_system_fallback=true; 04 overrides them at runtime only).
- No new APK/AVD work. 02 built build/android/defence-debug.apk at 07:07 (08 measured 55.3 MiB, both arm64 and x86_64). 04 has no install/start evidence of its own.
- gongmojeon SKILL.md was read. Reject→fix→retest was applied to (a) silent compile failures (fixed with the compile gate; the same scenario was retested) and (b) the font (rejected: OS-fallback Hangul and off-grid 9/18/28 sizes; fixed in code; retest is headless only and the visual retest is pending).

## Commit / push state
Commits before this task: e62fe86, e4aa059, d7651af, 0b987c9, 8915190, 225abc6 (all PUSHED).
**This checkpoint: NOT COMMITTED (PUSH_PENDING).** Publish-Task.ps1 refused with "Index is not empty". The shared index held another role's staged files (01-director's coordination/handoffs/01-director.md and docs/design/balance/* at checkpoint time). Per the rules I did not touch the shared index. The uncommitted, WIP-but-tested 04 files in the working tree are: src/ui/hud.gd, hud_top.gd, main_menu.gd, result.gd, round_select.gd, touch_button.gd, ui_style.gd, tests/ui/test_ui.gd, coordination/handoffs/04-client.md, coordination/status/04-client.md. The coordinator quota guard may save them to checkpoint/quota-*/04-client. After login, retry the same Publish-Task.ps1 call once the index is empty: Type Feat, subject '번들 한글 도트 글꼴 적용과 고정폭 숫자·글꼴 그리드 크기·타이포 검증 게이트 (시각 재검증 미완)', with those paths.

## Exact next steps (after login)
1. Re-read coordinator-to-04-client.md and DECISIONS.md.
2. Visual retest on the secondary monitor: `tools/build/visible_launch.ps1` (real game) and `tools/build/capture_ui.ps1`. Check pixel-regular text at 2×/3×, the toast strip, the gold slot, and round/result layouts. Note that capture_ui.ps1 opens windows without secondary-monitor placement; route it through visible_launch or add `--screen` first.
3. Update docs/qa/TYPOGRAPHY_QA.md and QA_CHECKLIST.md with the new numbers; add the licence/credits entry (OFL Galmuri © Lee Minseo) to the UI credits.
4. Write requests: 02 integer scale_mode; 03 .import font flags; 01 shorter en card/round names or approval of icon-only en cards.
5. UI gaps to report or implement next: tutorial banner (BattleInfo.tutorial), boss HP bar (HudSnapshot.boss), result star reasons, skill names (no longer shown on 48 px skill buttons), upgrade screen (P1).

## Known failures/risks
English ellipsis (15 labels); visual pixel regularity unverified; no device evidence; non-integer scale not yet prevented (02 setting).
