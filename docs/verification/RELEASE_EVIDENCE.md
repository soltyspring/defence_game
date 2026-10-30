# Release evidence matrix (owner: 07-qa)
Latest full run: **20261031-072353** (git HEAD 7c43ebd + 98 uncommitted paths from other workers, Godot 4.7.2 headless, Windows desktop).
Counts: PASS 114 · FAIL 4 · NOT_IMPLEMENTED 2 · NOT_TESTED 2 · BLOCKED 1. Summary: [runs/20261031-072353.md](runs/20261031-072353.md).

**Scope warning:** desktop headless acceptance only. This is NOT Android release certification.
`adb devices` at run time listed `emulator-5580` (an emulator, not a phone); no APK install or
on-device test has been done by 07-qa.

| Area | Status | Evidence / gap |
|---|---|---|
| Data references (rounds, units, heroes, skills, text keys ko/en) | PASS | DATA-01..11 |
| P0 rounds r01–r03 rules: start, income, workers, deploy, skills, pause, end freeze, determinism | PASS | R1..R3-* (39 checks) |
| P0 winnable / losable | PASS | R*-WIN (bot ≥2/3 seeds), R*-LOSS (idle player loses by base destruction); bot win rates in QA-O001 |
| Full UI flow menu → r01 → r02 → r03 via real touches | PASS | FLOW-01..22 |
| Win / loss / retry / next / round select | PASS | FLOW-13..21 |
| Result screen presentation | FAIL | QA-B002 (FLOW-13B) |
| Touch: card, worker, hold-move + 2nd finger | PASS | FLOW-05..07 |
| Touch targets ≥ 40 logical px, in safe area, no overlap (menu, HUD r01–r03, result, round select) | PASS | TOUCH-*, SAFE-R1-*, SAFE-R3-* (16:9, 19.5:9 notch, 20:9 notch+gesture, 21:9, 4:3) |
| App background / resume / pause | PASS | FLOW-08..11 (simulated notifications, desktop) |
| Android back: battle | PASS | FLOW-12 |
| Android back: result, round select | FAIL | QA-B001 (FLOW-23, FLOW-23B) |
| Android back: main menu shows quit dialog | PASS | FLOW-25 |
| Save corruption / recovery / semantics | PASS (6/8) | SAVE-01..04, 07, 08; recovery notice on menu FLOW-24 |
| Save type normalisation | FAIL | QA-B003 (SAVE-05), SAVE-06 BLOCKED |
| Image integration (atlases, P0 sprites/fx/biome/icons/bases, residency, release) | PASS | ART-01..11; resident battle pages ≤ 32 MiB estimate |
| Audio assets | PASS | AUD-01 (31 file refs exist) |
| Audio in game | NOT_IMPLEMENTED | AUD-02: no `Audio` autoload; game is silent. AUD-03 NOT_TESTED |
| Monetization disabled (D9) | PASS | MON-01..03 (data flags off, no SDK singletons, services default `disabled`) |
| Services wired | NOT_IMPLEMENTED | MON-04 (no `Services` autoload; consistent with D9) |
| Android export preset / permissions | PASS (static) | PLAT-01/02 |
| On-device Android (install, touch, lifecycle, safe area, perf, thermals) | NOT_TESTED | PLAT-03 |
| Rendered text (Hangul tofu/clipping), colour-blind readability, visual frames | NOT_TESTED | needs 04 secondary-monitor visible-test launcher (requested) |
| 06 services suites in regression | NOT_TESTED | queued (06-services-to-07-qa Q1) |
