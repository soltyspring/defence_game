# DEATH_SYNC_CHECK.md: death and hit sounds vs the 0.5 s death animation (05-audio, v4.0)
Status: written 2026-11-01 09:0x KST. The criteria below were written BEFORE any change. Python only, no Godot run. Nobody has listened, and nothing was checked on a real phone.

## Trigger
03 e8c6d96 shortened every death animation to 0.5 s. Before: 0.62–1.0 s (docs/art/evidence/char_quality/anim07_shipped_fix.json, `fix.*.death_anim_s` = 0.5 for all 10 units, including hero_captain and boss_warlord).

## Criteria (internal heuristics, fixed before measuring changes)
Audible end = end of the last 10 ms frame within 30 dB of the file's loudest 10 ms frame, measured on the source WAV and stretched by the slowest pitch jitter (length / (1 − pitch)).
- **T1 unit death sound**: death_ally, death_enemy, and explosion (a self-destructing unit explodes and dies on the same frame; battle_sim.gd `_fx("explosion")` then `_kill`). The audible end must be ≤ **0.50 s**.
- **T2 hit sound**: hit_bread, hit_mold, hit_melee, hit_arrow. The audible end must be ≤ 0.15 s. They mark an impact, not a death.
- **T3 event cues are exempt**: hero_death announces a game state (hero down, music −6 dB, respawn countdown). It is not the sound of the animation frames. It is listed and left unchanged, and the length is a listening question for 01/03.
- A changed file must keep:
  - the same file count (48, 08's cap) and the same seed;
  - `validate.py --determinism` PASS (variant level ±0.5 dB, peak, clicks);
  - offline R1–R4: the play times do not change, so R1–R4 cannot change. Re-checked on the existing logs anyway.
  - The attack (first 100 ms) must not get quieter: its loudness on the phone condition may change by at most −0.5 dB.

## Measurement (source WAVs; `tools/audio/_render/tail_measure.py` method)
| Cue | Files | Length s | Audible end s | Slowest pitch end s | Over 0.5 s | Criterion |
|---|---|---|---|---|---|---|
| death_ally | 1 | 0.34 | 0.29 | 0.31 | 0 | T1 PASS |
| death_enemy | 2 | 0.42 | 0.34 / 0.34 | 0.37 | 0 | T1 PASS |
| explosion (before) | 1 | 0.70 | 0.53 | **0.56** | **+0.06** | **T1 FAIL** |
| hit_bread | 3 | 0.06 | 0.05–0.06 | 0.06 | 0 | T2 PASS |
| hit_mold | 3 | 0.10 | 0.09 | 0.10 | 0 | T2 PASS |
| hit_melee / hit_arrow (fallbacks) | 5 / 1 | 0.10 / 0.08 | 0.07 | 0.08 | 0 | T2 PASS |
| hero_death | 1 | 1.00 | 1.00 | 1.00 | +0.50 | T3: exempt event cue, unchanged |
The phone condition (300 Hz high-pass) gives the same audible ends.

## Change
- explosion only (same seed 1025, same file name):
  - file length 0.7 → 0.5 s, body decay 0.15 → 0.12, boom decay 0.14 → 0.10;
  - bubbles at 0.12 + 0.05 i s (was 0.15 + 0.07 i), hiss release 0.4 → 0.2.
- Result:
  - audible end 0.53 → **0.40 s**, 0.42 s at the slowest pitch (T1 PASS);
  - attack (first 100 ms, phone condition) +0.01 dB;
  - 30,914 → 22,094 B (−8,820 B).
- Checks:
  - `validate.py --determinism` PASS; `asset_budget_check.py --worktree` PASS; SFX files 48.
  - Offline R1–R4 on the 9 v3.9 after-logs: 0 failures. Play times are unchanged.
- Not re-checked (needs Godot; next session): the phone masking of other cues with the shorter explosion in a real recording. A shorter tail can only remove background energy.
- hero_death (1.0 s, T3) stays as is. Whether a 1 s "hero down" line after a 0.5 s fall sounds right is a listening question for 01/03.
Not verified: human listening, real phone, real recording of the changed file.
