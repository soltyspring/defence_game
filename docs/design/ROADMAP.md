# Scope and roadmap (01-director) — PROVISIONAL
Milestones are internal checkpoints. "Playable slice" ≠ release.

## M0 Planning (now)
Implementation brief, schema, data for R1–R10, theme question. Exit: 02 loads data/*.json without errors (evidence from 02).
## M1 Internal playable slice (P0)
R1–R3 playable on desktop preview and an Android debug build: hero, workers, melee/ranged/tank, Slam, grunt/swarm/spitter, win/loss/retry, results stars, progress saved. Placeholder or themed art. Exit evidence: 02 headless round sim results, 04 device/emulator run, screenshots.
## M2 Chapter 1 content complete (P1)
R4–R10, fast/siege units, Rally/Barrage, brute/bomber/bosses, upgrade screen, tutorial steps, final theme art. Balance pass from headless bot + human playtest notes.
## M3 Production hardening
Device tiers + profiling evidence (02/04), atlas residency per biome (03), save migration & corruption recovery tests, lifecycle (pause on background, resume), settings, Korean/English text, accessibility (screen shake toggle, colour-safe palettes).
## M4 Monetization & compliance (after Q2–Q5)
Ad/IAP adapters behind interfaces (04), consent, privacy policy & Data safety form draft, purchase restore, failure cases tested in sandbox only with real evidence.
## M5 Release candidate
Release readiness checklist all tested or explicitly waived by user; store listing assets; publication is a separate user action.
## Post-launch candidates
Chapter 2 biome + hero 2, endless mode, daily first-win, achievements.

## Out of scope until decided
Multiplayer/PvP, server accounts, cloud save, gacha, iOS build execution (pipeline documented by 04 only).
