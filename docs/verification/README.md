# Verification (owner: 07-qa)

Independent acceptance and release QA. 07-qa does not fix runtime code; defects go to owners as
reproducible requests (`coordination/requests/07-qa-to-<owner>.md`) and are tracked in
[BUG_REGISTER.md](BUG_REGISTER.md). Release evidence is in [RELEASE_EVIDENCE.md](RELEASE_EVIDENCE.md).

## Run
```powershell
.\tools\qa\run_acceptance.ps1                       # all suites, ~90 s on the dev desktop
.\tools\qa\run_acceptance.ps1 -Only data,assets     # subset: data, assets, sim, save, flow, release
```
- Output (git-ignored): `build/qa07/<timestamp>/acceptance_report.{json,md}`, `godot.log`, `env.txt`
  (git HEAD, dirty path count, Godot version, `adb devices`). `build/qa07/latest.txt` points at the last run.
- Exit: 0 no FAIL, 1 FAIL present, 2 watchdog/crash, 3 engine busy or missing.
- Engine coordination: the runner never imports, opens the editor or exports. It waits while a Godot
  `--import`, `-e/--editor` or `--export-*` process for this project runs, or while
  `build/.godot-import.lock` is held (convention proposed to 02/04 in QA-R2).
- Isolation: the Save autoload is redirected to `user://qa07/flow_save.json` before any write;
  the developer save `user://save.json` is never touched.
- Balance evidence probe (no pass/fail): `-s res://tests/acceptance/probe_winrate.gd -- --seeds=20`.

## Suites (tests/acceptance/)
| Suite | What it proves | How |
|---|---|---|
| data | every round/unit/hero/skill/text reference in `data/**` resolves; P0 numeric sanity | reads JSON directly, then compares with the `Content` autoload |
| assets | atlas files/sizes/frames valid; what the runtime actually resolves for P0 units, projectiles, fx, biomes, icons, bases; residency released | `Atlas` autoload lookups, PNG decode |
| sim | first 3 rounds: start state, income formula, workers, deploy, skills, pause, win (3 seeds), loss, end freeze, determinism | headless `BattleSim`, expectations from `data/*.json` + INTERFACES §2 |
| save | both copies corrupt, zero-byte, interrupted rename, hostile types, result semantics, newer-version file | isolated `save.gd` instances under `user://qa07/` |
| flow | real `main.tscn` + App router + 04 UI + Viewport touch: menu → r01 → touch deploy/worker/hold-move + 2nd finger → background/resume → Android back → win → retry → loss → round select → r02 → next → r03; live safe-area matrix (16:9 … 21:9, notches, gesture bar, 4:3); save-recovery notice | `push_input` touches, `propagate_notification` for app lifecycle, faithful copy of `Window::_propagate_window_notification` for Android back |
| release | mobile project settings, audio files + wiring, monetization disabled (D9), no live SDK calls, services default `disabled`, export preset permissions | static + instantiation |

## Status vocabulary
- **PASS** verified by this run, with evidence in the report.
- **FAIL** exists but violates the contract/expectation; has a bug ID.
- **NOT_IMPLEMENTED** absent on disk / not wired yet; not a regression.
- **NOT_TESTED** cannot be exercised here (e.g. needs a phone or a hook).
- **BLOCKED** could not run because of another failure or a missing hook.

## Known limits of this harness
- Desktop headless only. Nothing here is Android device certification (PLAT-03 stays NOT_TESTED until
  a real phone run with adb evidence exists). Headless root is 640×640; the suite forces a 640×360
  logical view and injects safe areas through the 04 test hook `SafeArea.override_*`.
- Battles in the flow suite are finished by stepping `App.battle.sim` with the 02 scripted bot because
  no public fast-forward/seed API exists yet (requested QA-R1). The bot is not a human; win/loss
  rates are balance evidence, not fun evidence.
- No rendered-pixel checks yet (font tofu/clipping, colour-blind readability). Those need the 04
  secondary-monitor visible-test launcher.
