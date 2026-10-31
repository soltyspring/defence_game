# Godot `.uid` files: commit policy and repository audit (owner: 06-services)
Version: 1 (2026-10-31 ~17:20 KST). Engine in use: **Godot 4.7.2-stable** (`tools/engine/Godot_v4.7.2-stable_win64_console.exe`; `project.godot` `config/features` "4.7"; the APK manifest reports `org.godotengine.library.version=4.7.2.stable`).

## 1. Policy (official source, checked 2026-10-31)
| Rule (paraphrased) | Source |
|---|---|
| Since Godot 4.4 the engine writes a `<file>.uid` next to every script and shader so references survive file moves | https://godotengine.org/article/uid-changes-coming-to-godot-4-4/ |
| `.uid` files must be committed to version control; `*.uid` must not be in `.gitignore` | same |
| When a script is moved or deleted outside Godot, move or delete its `.uid` with it | same |
| Without the `.uid`, the project still works locally, but on another clone UID references break; Godot falls back to the stored path with a warning, which can pick the wrong file if paths were swapped | same |
The article is dated January 2025 and carries a note that details may have changed. 06 did not find a later official page that changes the rule. The stable "Version control systems" page (https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html) did not mention `.uid` when fetched. Content was rephrased for compliance with licensing restrictions.

This repo already follows the rule: `.gitignore` (02) does not ignore `*.uid`, and 98 `.uid` files are tracked.

## 2. Audit (2026-10-31, `git ls-files "*.uid"`, `git status --porcelain --untracked-files=all --ignored`)
- Tracked: 98 at the start (102 after e340144).
- Untracked outside ignored folders: 19 at the start, plus 1 new 06 test. During the audit 10 committed its 4 (e340144). The 4 owned by 06 are committed with this change, which leaves 12 for 02, 04 and 07.
- Ignored: 765, all under `build/`. These are build outputs, and `/build/` is correctly ignored.
- References today: `git grep` finds no tracked file that uses any of the 19 untracked UIDs, so nothing is broken right now. The risk starts when a scene or script refers to one of these scripts by `uid://`, or when the editor rewrites a `.tscn` to use the UID.

| Untracked file | Script tracked? | Owner (OWNERSHIP.md) | Action |
|---|---|---|---|
| docs/research/systems/probes/probe_content_migration.gd.uid | yes | 10-research-systems | **committed by owner** (e340144, during this audit) |
| docs/research/systems/probes/probe_save_load_cases.gd.uid | yes | 10-research-systems | **committed by owner** (e340144, during this audit) |
| docs/research/systems/probes/probe_upgrade_effect.gd.uid | yes | 10-research-systems | **committed by owner** (e340144, during this audit) |
| docs/research/systems/probes/probe_upgrade_transaction.gd.uid | yes | 10-research-systems | **committed by owner** (e340144, during this audit) |
| src/core/diag/flip_check.gd.uid | yes | 02-engine | owner commits |
| src/core/diag/wave_clear_probe.gd.uid | yes | 02-engine | owner commits |
| src/ui/title_block.gd.uid | yes | 04-client | owner commits |
| src/ui/upgrade_panel.gd.uid | yes | 04-client | owner commits |
| tests/ui/redraw_probe.gd.uid | yes | 04-client (tests/** except services/acceptance) | owner commits |
| tests/acceptance/capture_crowd.gd.uid | yes | 07-qa | owner commits |
| tests/acceptance/capture_m8.gd.uid | yes | 07-qa | owner commits |
| tests/acceptance/capture_narrow.gd.uid | yes | 07-qa | owner commits |
| tests/acceptance/capture_visual.gd.uid | yes | 07-qa | owner commits |
| tests/acceptance/cvd_sim.gd.uid | yes | 07-qa | owner commits |
| tests/acceptance/probe_r01_risk.gd.uid | yes | 07-qa | owner commits |
| tests/acceptance/probe_balance.gd.uid | **no** (script untracked too) | 07-qa | commit together with the script, or delete both if it is scratch |
| tests/services/test_services_android.gd.uid | yes | 06-services | **committed by 06** |
| tests/services/test_services_m10.gd.uid | yes | 06-services | **committed by 06** |
| tests/services/test_services_m8.gd.uid | yes | 06-services | **committed by 06** |
| tests/services/test_services_upgrade.gd.uid | new with this change | 06-services | **committed by 06** (written with `ResourceUID.create_id()` in the editor's text form) |
Per owner, still open at publish time: 02 = 2, 04 = 3, 07 = 7. Done: 10 = 4 (e340144), 06 = 4 (this change). 06 did not stage or commit any other owner's file.

## 3. Keeping it fixed
- `tests/services/test_services_android.gd` group `godot_uid_tracked` fails if any tracked 06 script lacks a tracked `.uid`. It prints the repo-wide count of untracked `.uid` files outside 06 paths as information only.
- Why it was missed: `Publish-Task.ps1 -Paths` stages only the listed files, so a new script's `.uid` (written by Godot on first run) is left behind unless it is listed. Suggested habit for every role: list `<script>.gd.uid` next to `<script>.gd` in `-Paths`.
