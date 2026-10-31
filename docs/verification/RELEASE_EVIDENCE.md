# Release evidence matrix (owner: 07-qa)
Latest full run: **HEAD e2404af** (`-Head`, import guard 0 missing, private APPDATA proven, run 20261101-070302 via heavy_run_detached; Godot 4.7.2 headless, Windows desktop). Triage: [FAILURE_TRIAGE.md](FAILURE_TRIAGE.md). Visual: [VISUAL_CHECKS.md](VISUAL_CHECKS.md). Balance: [BALANCE_CROSSCHECK.md](BALANCE_CROSSCHECK.md). Open: [OPEN_DEFECTS.md](OPEN_DEFECTS.md). Isolation: [USERDATA_POLICY.md](USERDATA_POLICY.md). Graphics: [ART_BASELINE.md](ART_BASELINE.md). Layout: [LAYOUT.md](LAYOUT.md).
Counts: PASS 156 · FAIL 0 · NOT_TESTED 2 · BLOCKED 0; services exit 0; exit 0. Summary: [runs/head-e2404af.md](runs/head-e2404af.md). Previous: 278d52b 156/0. Automated PASS is not release readiness: the graphics, animation and layout rules fail in several places (ART_BASELINE, LAYOUT), QA-B013/B017/B018/J1/W004 are open, and no human play test has been run.

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
| Localised text for engine toasts | PASS | DATA-13/14 PASS at 278d52b (QA-B019 verified: 01 4882771, 04 1850c3f); FLOW-04B (QA-B008 verified) |
| Player-base defence keys (INTERFACES v1.5, 02 eceb9f4) | PASS (off by default) | BD-DATA/CAP/PUSH/SPLASH at 3e355a8; D34: 01 keeps it off |
| Theme guard: label fit, names, colour separation | PASS | TH-* all PASS at 3b2d830 (QA-B011 verified after 7705aec) |
| Visual baselines | STALE (older images) | 123 committed docs images predate 7705aec; current HEAD captures: evidence/visual2-5c08bb4 (layout), evidence/visual3-3b2d830 (new art) |
| Narrowest notch layout (rendered) | PASS | VISUAL_CHECKS C3: ko/en 1x/2x, 0 truncated/out-of-safe buttons, full base HP numbers |
| Crowd readability / message overlap (real time) | PASS with P3 finding | VISUAL_CHECKS C4/M14: 0 message overlaps; QA-B012 VERIFIED 278d52b (0 damage-number overlaps over 185 s, 0 dropped); QA-B013 world HP bars under CVD still PARTIAL |
| Image integration (atlases, P0 sprites/fx/biome/icons/bases, residency, release) | PASS | ART-01..11; resident battle pages ≤ 32 MiB estimate |
| Audio assets | PASS | AUD-01 (31 file refs exist) |
| Audio in game | PARTIAL | AUD-02 PASS at e9dfaa4 (`Audio` autoload registered). AUD-03 (cues fire on events, honour settings/pause) NOT_TESTED; nothing was listened to |
| Monetization disabled (D9) | PASS | MON-01..03 (data flags off, no SDK singletons, services default `disabled`) |
| Services wired / disabled UI | PASS | Services autoload, mode=disabled, live flags false; 0 ad/purchase texts on menu, round select, settings, HUD, result (VISUAL_CHECKS C2) |
| Android export preset / permissions | PASS (static) | PLAT-01/02 |
| On-device Android (install, touch, lifecycle, safe area, perf, thermals) | NOT_TESTED | PLAT-03 |
| Rendered round-select text ko/en 1x/2x | PASS | VISUAL_CHECKS C1 (secondary monitor, HEAD 0590e7a); HUD/other screens reviewed visually only, no tofu seen; CVD full-frame review still open |
| 06 services suites in regression | PASS | test_services + test_services_m2 exit 0 in runner (run 20261031-080846); mock adapters only |
| Upgrade screen (coins only, Q2 보류) | PASS | VISUAL C6/C12: active with in-game coins, 0 monetization words |
| Working title Q3 | PASS | VISUAL C11/C14: logo and forced text title fit at 34+34 notch, ko/en, 1x/2x |
| First 3 minutes (J1/J2) | J1 OPEN, J2 CLOSED | J1: objects 5-7 % of view, 0 enemies on screen early (FIRST_3MIN_REVIEW); J2: D24(a) rule PASS (BALANCE_CROSSCHECK) |
| Upgrade purchase fault tolerance | PASS | PUR-C6..C13 (4 fault points x normal/after recovery, read-only, recovery, balance edges, double tap, interleaving, pause) at 09508b1; desktop only |
| Launcher label Q4 (APK) | PASS (pre-commit APK) | C16: ko '빵집 기사단', en 'Bakery Knights'; re-read on a HEAD-built APK is WAITING (QA-W004) |
| Resource wording | FAIL (P3) | C15: QA-B018 'Supply Boost' |
| Battle background (sky share, identity) | PASS | M12 V1-V3: sky 17 % r01, 21 % r08; village + nest readable incl. deutan |
| Damage numbers | FAIL (P3) | M12 V4: QA-B012 reopened |
| Casual difficulty target D28 | PASS (bots, DEFAULT target) | BALANCE_CROSSCHECK last section: all 11 rows PASS with the fixed probe (3e355a8; r04/r05 from d5f145a). Floors only; not human evidence; Q5 unanswered |
| Graphics readability (screen level, 393 dp phone) | FAIL (baseline) | ART_BASELINE.md at ad47eda: fixed re-runnable set (27/27 identical on re-run). FAIL now: hero ΔL* (QA-B020), card icons (QA-B021), soldier size (QA-B022, provisional), unit/lane and boss contrast (QA-B023). PASS: effects on units 2.5 %, HUD on units 0 %. Not measurable by tools: "looks like bread/mould", appeal |
| Animation reading (screen level) | FAIL (baseline) | ART_BASELINE §5: 10 unit ids. FAIL: e_brute does not walk (QA-B024), deaths fade before they play (QA-B025). PASS: attack vs walk, attack reach, hit flash. The atlas hit/cast animations are never drawn (QA-O006) |
| Art commits judged | 1 | 700692d (06) VALID: UI changed as stated, cards unchanged, HUD +0.07 pp max (art_compare/700692d.md) |
| UI layout (LAYOUT.md L1–L8, 393 dp phone) | FAIL (baseline) | ad47eda: L4 target gaps 4 px / 6 px < 8 dp (QA-B027); L6 threat markers never shown by code (QA-B026). PASS: L2, L3 (44 px exactly), L5, L7 (12 px), L8. Not measurable: looks / genre fit |
