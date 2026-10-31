# REPETITION_CHECK.md — repetition fatigue of frequent battle SFX (05-audio, v3.8)
Status: criteria written FIRST (2026-11-01, before any measurement or change). Measurements are below them. Nobody has listened yet, and nothing was checked on a real phone.

## Criteria (internal heuristics, not an external standard; fixed before measuring)
Applies to every SFX cue played at least 10 times per minute in at least one recording. Measured from the engine cue log; v3.8 adds file variant, pitch and volume to that log.
- **R1 burst**: at most 4 plays of the cue in any 1 s window (same threshold as mix_report.py `REPEAT_RATE_HZ`).
- **R2 per-file density**: at most 20 plays of the SAME file in any 10 s window (same as mix_report.py `REPEAT_10S`).
- **R3 identical repeat**: a consecutive pair of plays of the cue within 2 s that uses the same file AND pitch within ±1 % AND volume within ±0.5 dB counts as an "identical repeat". It must be ≤ 10 % of consecutive pairs within 2 s.
- **R4 same file back-to-back**: consecutive plays within 2 s that use the same file, ≤ 50 % of such pairs. This catches single-file cues that only rely on pitch jitter.
- A cue that fails any of R1–R4 in any recording gets one or more of: 2–3 file variants, small pitch randomisation (≤ ±8 %), small volume randomisation (≤ ±1.5 dB), and a simultaneous-voice cap.
- Budgets that must still hold: total SFX files ≤ 48 (08's cap; 43 used before v3.8), `asset_budget_check.py --worktree` PASS, `validate.py --determinism` PASS.
- Re-judging after the change: D1/D2/G1/G2 with the same-background A/B (coordinator decision above), real 3-seed recordings for anomaly detection, and R1–R4 on the new recordings.
Recordings: r02, r06, r08 (3 rounds), probe seeds 11, 23, 37, 60 s each, heavy_run lock, private APPDATA.

## Before (tag `rb`, assets of 64a95c6, 9 recordings 2026-11-01 ~01:0x)
Ranges over the 9 recordings (r02/r06/r08 × seeds 11/23/37). Only cues with ≥ 10 plays/min in at least one recording are listed; gold_tick was 6–9/min here.

| Cue | plays/min | files | R1 max in 1 s | R2 max same file in 10 s | R3 identical % | R4 same file % | Verdict |
|---|---|---|---|---|---|---|---|
| hit_bread | 18–43 | 3 | 2–3 | 4–9 | 0 | 0 | pass |
| shoot_spit | 2–43 | 1 | 1–3 | 2–**24** (r08 ×3) | 0–10 | **100** | **FAIL R2, R4** (r08) |
| hit_mold | 10–36 | 3 | 2–3 | 3–7 | 0 | 0 | pass |
| deploy | 10–13 | 1 | 1 | 3 | 0 (no pairs within 2 s) | 0 | pass |
| death_enemy | 8–12 | 1 | 1–2 | 4–6 | 0–**20** | **100** | **FAIL R4** (7 recordings), **R3** (r08 s11/s23) |
| shoot_arrow | 10–11 | 1 | 1 | 8 | 0–**14.3** | **100** | **FAIL R4** (r02 ×3), **R3** (r02 s11/s23) |

The pitch jitter (±8 %) alone does not stop R4 by definition, and shoot_spit in r08 played the one file 24 times in 10 s.

## Change (v3.8)
- Extra variants through a new manifest field `rx` (stable seeds 70000+10·cue_index+n, files `<cue>_v2.wav`, `<cue>_v3.wav`; every older file and seed stays byte-identical): shoot_spit +2 (3 files), death_enemy +1, shoot_arrow +1, gold_tick +1.
  - gold_tick was added after the first after-run (`ra`, 8 of 9 recordings, stopped by the tool time limit) showed it at 6–11 plays/min with R4 up to 100 %.
- `vol_jitter` 1.0 dB on the same 4 cues: `AudioManager.play()` adds a uniform random −1…+1 dB per play. Existing pitch jitter (±5–8 %) and the per-cue `max`/`gap` limits are unchanged. No new voice cap was needed: R1 stayed ≤ 3 per second everywhere.
- The runtime already picks a variant at random but never the same one twice in a row; with 2 files that means strict alternation.
- Budget: SFX files 43 → 48 = 08's cap (0 left). `asset_budget_check.py --worktree` PASS (sfx 48 / 0.98 MiB, music 2 / 0.56 MiB), `validate.py --determinism` PASS (51 files byte-identical on regeneration).

### Rule added during the work (not one of the pre-written criteria)
The same-background A/B (below) showed that the first death_enemy_v2 raised death_enemy's masked share on phone by 5.4 points on r02 seed 11. On a phone it was 1.3 dB quieter than death_enemy.wav, measured as K-weighted energy of its loud 50 ms frames after the 300 Hz high-pass. shoot_spit_v2/v3 were 0.7/1.5 dB quieter.
- New check in `validate.py`: every `<cue>_vN.wav` must be within ±0.5 dB of the cue's first file by that measure. Final values: death_enemy_v2 +0.25, shoot_arrow_v2 +0.24, shoot_spit_v2 +0.17, shoot_spit_v3 +0.01, gold_tick_v2 −0.29 dB.
- Matching the level alone did not fix death_enemy_v2. Re-timed versions at −0.3 dB were still 6.6 points more masked on average over the 9 backgrounds. The final death_enemy_v2 keeps the original's 4-bubble timing and changes the timbre instead: darker squelch, higher bubble line, mild tanh compression. Over the same 9 backgrounds it is masked 11.5 % vs 12.5 % for death_enemy.wav, with p10 −0.8 vs −1.1 dB.

## After (tag `rd`, final assets, 9 recordings 2026-11-01 02:22–02:35)
Same rounds, seeds and settings. Foreign files are from HEAD 926e00a; 05 paths are from the worktree. The run was detached under the heavy_run lock, with private APPDATA.

| Cue | plays/min | files | R1 max in 1 s | R2 max same file in 10 s | R3 identical % | R4 same file % | Verdict |
|---|---|---|---|---|---|---|---|
| hit_bread | 18–44 | 3 | 2–3 | 4–9 | 0 | 0 | pass |
| shoot_spit | 2–60 | 3 | 1–3 | 1–11 | 0 | 0 | pass |
| hit_mold | 9–40 | 3 | 2–3 | 3–7 | 0 | 0 | pass |
| deploy | 10–13 | 1 | 1 | 3 | 0 | 0 | pass |
| death_enemy | 9–12 | 2 | 1–2 | 2–3 | 0 | 0 | pass |
| shoot_arrow | 10 | 2 | 1 | 4 | 0 | 0 | pass |
| gold_tick (6–9/min, below the 10/min scope) | 6–9 | 2 | 1–2 | 2–3 | 0 | 0 | pass |

R1–R4: **no failures** in any of the 9 recordings (`python tools/audio/repetition_check.py --tag=rd`).
- r08 seed 37 had 60 shoot_spit plays/min after vs 40 before. These are two real-time runs of the same seed and the battles are similar but not identical (r08 total cues 137–161). Even this densest case keeps R1 ≤ 3 and R2 ≤ 11.

Same run, integration checks: audio selftest PASS (new v3.8 assertions: 3 shoot_spit variants, never the same variant twice, vol jitter within ±1 dB). Real battle: hit_mold 13 / hit_bread 19 / fallback 0, deploy 14 = engine 14, skills 7 = 7, wave_cleared 1 = 1, upgrade cues 2 = expected 2, hero death 1 / respawn 1. No same-frame duplicates and no leaked audio-class objects. Lifecycle 27/27, settings write 3/3, settings read 5/5. Isolation: private APPDATA, real save unchanged.

## Re-judging D1/D2/G1/G2 (details: PHONE_SPEAKER_CHECK.md "v3.8 re-judge")
| Check | Same-background A/B (verdict, coordinator decision) | Real 3-seed × 3-round recordings (anomaly detection) |
|---|---|---|
| D1 danger cues masked ≤ 8 % | PASS (death_ally 0–7.5 %, hit_base 1.8–5.5 %) | PASS (0–3.8 %, 0–7.4 %) |
| D2 p10 ≥ 0 dB | PASS (≥ 2.0 / 2.1 dB) | PASS (≥ 2.8 / 3.2 dB) |
| G1 loudness, peak, clipping | PASS (LUFS ±0.03 dB, peaks ≤ −1.85 dBFS) | LUFS PASS (−21.9…−21.3, before −22.1…−21.5), 0 clipped; **peak FAIL as written in 1 of 9** (r08 s23: −0.50 dBFS, the limiter ceiling, at a 5-cue onset cluster; not reproduced when the cluster is re-rendered from its log) |
| G2 other cues ≤ +2 points | PASS (max +1.9, one placement) | no anomaly (per-cue means −1.9…+0.3; single pairs up to +5.8, inside the 7.2-point replicate spread) |
| G3 danger-cue phone loudness ≤ +1.5 dB | unchanged files and values: 0 dB | — |
| R1–R4 repetition | — | PASS, 0 failures in 9 recordings (before: 13 failing cue-recordings) |

## Limits
- Nobody has listened. The criteria are internal heuristics, and they count files, pitch and level. They do not judge whether two variants actually sound different to a person. Blind clips are in LISTENING_CHECKLIST.md §7.
- Nothing was checked on a real phone. The phone condition is a desktop proxy: 300 Hz high-pass and −6 dB.
- Recordings are headless Godot runs with real-time commands. The same seed does not give a sample-identical battle (r08 s37: 40 vs 60 shoot_spit plays/min).
- The same-background render places files without the runtime pitch jitter and off-screen attenuation. Variant choice is cycled, not random.
- SFX file count is now at 08's cap of 48. Any new SFX file needs 08's agreement or a file removed elsewhere.

<details><summary>Blind A/B key for LISTENING_CHECKLIST §7 (open only after listening)</summary>

X = after (v3.8, recording `rd_r08_s11`, 24.0–44.0 s), Y = before (64a95c6 assets, recording `rb_r08_s11`, 25.5–45.5 s). Each window is the densest 20 s of the 4 changed cues in its recording (45 vs 42 plays).
</details>
