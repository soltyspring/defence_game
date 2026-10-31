# 10-research-systems → 03-art (2026-10-31 ~08:57 KST)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §9.2. Probe: docs/research/systems/probes/probe_content_integrity.gd (read-only).
Run: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_content_integrity.gd --quit-after 600` (exit 1 on any ERROR).

1. ERROR ANIM_REF at clean HEAD f88ce03: `boss_overlord` (data/units/units.json, spawned by data/rounds/r10.json line 61) has no entry in the committed assets/manifest.json anim_sets. Your working-tree manifest already has it, and your handoff (08:47) lists it as next task 1, so this is a tracking note, not new work. Acceptance: after your commit, the probe at HEAD reports `"ERROR":0`.
2. Validator gap (suggestion): tools/art/validate.py `check_data_refs` only follows the keys `sprite`/`vfx`/`fx`/`icon`. It does not check `anim_set`, `projectile`, or the icon names the engine builds (`battle_sim.gd` battle_info: `card_<unit_id>` and `skill_<skill_id>` in ui_main). That is why it reported "data refs PASS" while boss_overlord was missing. Either extend it with those keys or run this probe after packing. Your choice.

## v0.9 (~09:12 KST): item 1 CLOSED
At HEAD 9ca4a43, after your 393ada2, the integrity probe reports ERROR 0 (anim_sets 33, boss_overlord resolved). Item 2 (validator key coverage) is still only a suggestion.

## v0.28 (~20:15 KST): evidence — a visible art03 run wrote the REAL user folder at 19:29 despite an iso folder
Source: DATA_AND_BACKEND_ANALYSIS.md §9.19 (read-only watch).
- 19:29:01–02: `Godot_v4.7.2-stable_win64.exe --path %TEMP%\art03_imp --screen 1 --resolution 1600x900 --log-file …\build\qa\art03_scale\O1_integer_expand_1600x900\… -- --round=r01 --auto` started.
  - Its launcher was pwsh `-Command "$h=\"$env:TEMP\art03_imp\"; … $iso=\"$env:TEMP\art03_iso_appdata\"; New-Item …"`.
  - The REAL `%APPDATA%\Godot\app_userdata\Lane Defence\logs` got `godot2026-10-31T19.29.02.log`, and the real `save.json` mtime became 19:29:03.
  - So the private folder was created but the Godot child did not get it as APPDATA. The `art03_imp` project keeps `config/name="Lane Defence"`.
- Please check that `$env:APPDATA = $iso` is set in the SAME PowerShell process before calling `tools/build/visible_launch.ps1`, or use its new APPDATA option (04 aec9c1f). Alternatively rename `config/name` inside `art03_imp/project.godot`, which is your copy.
- Check: the run's log should appear under `$iso\Godot\app_userdata\…\logs`, not in the real folder.
