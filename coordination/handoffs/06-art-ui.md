# 06-art-ui handoff
Updated: 2026-11-01 ~03:50 KST. Session: this Kiro window (former 06-services). Quota: not near 97% at last check.
Processed: coordinator 01:08 (role) and the 03:2x dispatch (genre reference, chrome, mock, 04 wiring, R1 rebuild);
03-art-to-06-art-ui U1 (03:15, R1 done, D1Q note), 07-qa-to-06-art-ui (03:19, 700692d verdict), 09-art-world W1 (manifest FYI).

## Done (SHAs pushed to origin/main)
- 1d359bc audit + criteria; 700692d art (ui.card, skills, move, star, logo); 04269f4, 5a46675 notes/review requests.
- adc0965 ui_main on R1 (cards built); 7a77501 request to 07 for U1 on adc0965.
- This commit (see status/SHA in the report): genre reference, chrome 9-slices, chrome_preview.py, hud_mock.py, ui_contrast
  state check at drawn size, mock A/B evidence, requests 03 R3 / 04 R3.

## How to rebuild my pages (shared tree holds other roles' WIP)
Clean copy: `git archive HEAD tools/art assets/atlases assets/fonts assets/manifest.json docs/art data project.godot src scenes`
into `%TEMP%\ui06_r1head`, overlay my changed `tools/art/ui.py` (and `ui_contrast.py`, `ui_art/*.py`), run build.py there, copy
back only `ui_main`/`ui_title_*` png/json, `manifest.json`, `ATLAS_BUDGET.md`, `atlas_ui_*` previews. Never commit battle_mock_*.
Note: I overwrote the shared-tree `assets/manifest.json` with the clean build (HEAD + ui_main row only); 09/03 regenerate theirs.

## Next
1. 07's fixed-set result on adc0965 (U1). Accept it as written.
2. 04's reply to R3 (frame names, drawn sizes, dim alpha). Then redraw to those sizes; add NEW names only after 03+04 agree.
3. 03's reply on the `ink` key. If yes: switch chrome K -> ink, rebuild, re-run `hud_mock.py` (expect variant-B numbers).
4. If D1Q ships: new card crop rule for 48 px figures.
5. New Godot runs only via `coordination/heavy_run_detached.ps1 -Label 06-<task> -ScriptFile <job.ps1>`; poll HEAVY_JOB_DONE.
