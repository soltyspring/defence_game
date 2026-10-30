# 03-art handoff — CHECKPOINT for account change
Updated: 2026-10-31 (account-change stop requested by user). Work is STOPPED. Waiting for the user to log in to a new account. Window kept open.

## Session
- Kiro CLI session ID: not visible to me from inside the session, so I cannot record it. Codex should read it from coordination/.runtime/quota/sessions.json or the launcher.
- Model: claude-opus-5.5, trust-all. The last observed quota was 89.7% (coordination/.runtime/quota/usage.json) before the stop.

## User decisions preserved
- Q1 theme is still PENDING (DECISIONS.md). All art is the reversible default "Lantern Kingdom vs Bramble Horde" and is NOT user-approved.
- All other entries in DECISIONS.md are DEFAULTs owned by 01. 03 changed none of them.

## Current task at stop (UNFINISHED, nothing written yet)
Dispatch: create r04–r07 roster art (fast, e_brute, siege, e_bomber, boss_warlord), reproduce 04's white lines with 02, recheck readability, validate, commit.
Progress on it:
1. White-line investigation (analysis only, no file changes):
   - The two lines in build/qa/visible/screen_20261031_071349_008s.png lie in the far layer (logical y≈215–255) and the mid layer (y≈250–295), one line per layer.
   - The art column scan finds no such lines in the textures.
   - Working hypothesis, UNPROVEN: 1 px gaps between repeated tile copies in 02's `src/gameplay/battle_view.gd::_draw_biome_layers` (`draw_texture_rect_region(... Rect2(roundf(x), y, tile_w, ...))` with fractional `cam_x` from the lerp in battle.gd:166) expose the pale sky behind.
   - Not yet reproduced. A real-game capture via `tools/build/visible_launch.ps1 -UserArgs '--round=r01','--shots=2,5,8','--shot-dir=build/qa/art03','--quit-after=10' -EvidenceDir build\qa\art03` was started but INTERRUPTED. No capture exists (build/qa/art03 is empty or missing). No message was sent to 02 about this hypothesis.
   - Do not claim it fixed without a real secondary-monitor recapture after integration.
2. Roster art: not started. 08's page-plan request (08-performance-to-03-art A1) has not been answered yet.

## Committed + pushed (all origin/main, via Publish-Task.ps1)
9b4ee0b, e93acdd, 6cf3d01, 4088ae0, 5e157e3, abd327d (details in previous handoff revisions and the git log). This handoff is committed in the checkpoint commit made at the stop (see git log `[Docs] 03 아트 계정 전환 체크포인트`).
Working tree at stop: no other uncommitted 03-owned files (git status clean for assets/, tools/art/, docs/art/ apart from this handoff).

## Validation state (last real runs, before the stop)
validate.py PASS (atlases, bleed simulation, palette, anim contract, Godot-generated .import for atlases and fonts, pixel-font params, font coverage, determinism). Exported-PCK check: 6/6 pages + 3 fonts load with no raw PNG. Font renders regular at 12/24 px for 1–4×. Nothing was re-run after the stop.

## Known failures / open items
- A8 white lines: open (owner 02 probable), unreproduced by 03.
- A2 (04 font sizes 9/18/28), A3 (02 integer scale_mode), A6/A7 runtime use of markers/prop_mine (02), A9 ribbons (04): requested, open.
- No Android device evidence of any art or font.
- Missing art: fast, siege, e_brute, e_bomber, boss_warlord, boss_overlord, 2nd biome.

## Exact next steps after login
1. Re-read coordinator-to-03-art.md, DECISIONS.md and incoming *-to-03-art.md files (02, 04, 08).
2. Re-run the interrupted capture command above. Compute whether the line x positions match the far/mid tile seams for the captured cam_x (seam_x = floor((left-off)/640)*640+off, off = cam_x*(1-parallax)). Send exact evidence to 02 in 03-art-to-02-engine A4.
3. Reply to 08 A1 with the planned pages: put fast/siege in char_player (currently 512², may grow to 1024×512); e_brute/e_bomber in char_enemy; boss_warlord on its own page `char_boss_warlord` (≤512², load_policy per roster).
4. Draw fast (mounted, 18 px footprint, ~28 px tall), e_brute (~36 px, 48×48), siege (28 px footprint), e_bomber, boss_warlord (~52 px, 64×64) with the existing rig/tools. Then build.py → validate.py --determinism → run_godot_pack_check.ps1 → update the battle mock, inspect the sheets, and publish.
