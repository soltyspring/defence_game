# Release evidence matrix (owner: 07-qa)
Latest full run: **HEAD 3b2d830** (`-Head` clean snapshot, run 20261031-162034; Godot 4.7.2 headless, Windows desktop). Triage: [FAILURE_TRIAGE.md](FAILURE_TRIAGE.md). Visual: [VISUAL_CHECKS.md](VISUAL_CHECKS.md).
Counts: PASS 145 · FAIL 0 · NOT_IMPLEMENTED 0 · NOT_TESTED 2 · BLOCKED 0; 06 services suites exit 0. Summary: [runs/head-3b2d830.md](runs/head-3b2d830.md). Zero automated FAILs is not release readiness: see open visual findings and PLAT-03.

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
| Result screen presentation | PASS | FLOW-13B (QA-B002 verified e5bd4aa) |
| Touch: card, worker, hold-move + 2nd finger | PASS | FLOW-05..07 |
| Touch targets ≥ 40 logical px, in safe area, no overlap (menu, HUD r01–r03, result, round select) | PASS | TOUCH-*, SAFE-R1-*, SAFE-R3-* (16:9, 19.5:9 notch, 20:9 notch+gesture, 21:9, 4:3) |
| App background / resume / pause | PASS | FLOW-08..11 (simulated notifications, desktop) |
| Android back: battle | PASS | FLOW-12 |
| Android back: result, round select | PASS | FLOW-23, FLOW-23B (QA-B001 verified e5bd4aa) |
| Android back: main menu shows quit dialog | PASS | FLOW-25 |
| Save corruption / recovery / semantics | PASS (6/8) | SAVE-01..04, 07, 08; recovery notice on menu FLOW-24 |
| Save type normalisation | PASS | SAVE-05, SAVE-06 (QA-B003 verified) |
| Save fault tolerance (TP-01/02/06/13/14) | PASS | all 9 faults checks at e5bd4aa/5426645; QA-B004 P1 verified (fix 08ef082). Kill points rebuilt from file states, not yet via `Save._fault` |
| Localised text for engine toasts | PASS | DATA-13/14, FLOW-04B (QA-B008 verified) |
| Theme guard: label fit, names, colour separation | PASS | TH-* all PASS at 3b2d830 (QA-B011 verified after 7705aec) |
| Visual baselines | STALE (older images) | 123 committed docs images predate 7705aec; current HEAD captures: evidence/visual2-5c08bb4 (layout), evidence/visual3-3b2d830 (new art) |
| Narrowest notch layout (rendered) | PASS | VISUAL_CHECKS C3: ko/en 1x/2x, 0 truncated/out-of-safe buttons, full base HP numbers |
| Crowd readability / message overlap (real time) | PASS with P3 findings | VISUAL_CHECKS C4: 0 message overlaps; QA-B012 damage numbers, QA-B013 HP bars under CVD |
| Image integration (atlases, P0 sprites/fx/biome/icons/bases, residency, release) | PASS | ART-01..11; resident battle pages ≤ 32 MiB estimate |
| Audio assets | PASS | AUD-01 (31 file refs exist) |
| Audio in game | PARTIAL | AUD-02 PASS at e9dfaa4 (`Audio` autoload registered). AUD-03 (cues fire on events, honour settings/pause) NOT_TESTED; nothing was listened to |
| Monetization disabled (D9) | PASS | MON-01..03 (data flags off, no SDK singletons, services default `disabled`) |
| Services wired / disabled UI | PASS | Services autoload, mode=disabled, live flags false; 0 ad/purchase texts on menu, round select, settings, HUD, result (VISUAL_CHECKS C2) |
| Android export preset / permissions | PASS (static) | PLAT-01/02 |
| On-device Android (install, touch, lifecycle, safe area, perf, thermals) | NOT_TESTED | PLAT-03 |
| Rendered round-select text ko/en 1x/2x | PASS | VISUAL_CHECKS C1 (secondary monitor, HEAD 0590e7a); HUD/other screens reviewed visually only, no tofu seen; CVD full-frame review still open |
| 06 services suites in regression | PASS | test_services + test_services_m2 exit 0 in runner (run 20261031-080846); mock adapters only |
