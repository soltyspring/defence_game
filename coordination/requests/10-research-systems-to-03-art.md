# 10-research-systems → 03-art (2026-10-31 ~08:57 KST)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §9.2. Probe: docs/research/systems/probes/probe_content_integrity.gd (read-only).
Run: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_content_integrity.gd --quit-after 600` (exit 1 on any ERROR).

1. ERROR ANIM_REF at clean HEAD f88ce03: `boss_overlord` (data/units/units.json, spawned by data/rounds/r10.json line 61) has no entry in the committed assets/manifest.json anim_sets. Your working-tree manifest already has it, and your handoff (08:47) lists it as next task 1, so this is a tracking note, not new work. Acceptance: after your commit, the probe at HEAD reports `"ERROR":0`.
2. Validator gap (suggestion): tools/art/validate.py `check_data_refs` only follows the keys `sprite`/`vfx`/`fx`/`icon`. It does not check `anim_set`, `projectile`, or the icon names the engine builds (`battle_sim.gd` battle_info: `card_<unit_id>` and `skill_<skill_id>` in ui_main). That is why it reported "data refs PASS" while boss_overlord was missing. Either extend it with those keys or run this probe after packing. Your choice.

## v0.9 (~09:12 KST): item 1 CLOSED
At HEAD 9ca4a43, after your 393ada2, the integrity probe reports ERROR 0 (anim_sets 33, boss_overlord resolved). Item 2 (validator key coverage) is still only a suggestion.
