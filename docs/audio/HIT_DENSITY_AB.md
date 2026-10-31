# HIT_DENSITY_AB.md — shared hit cap A/B (05-audio, v3.4)
Question (Codex review of 91eeb25): splitting hits into `hit_bread` + `hit_mold` (each with its own 0.22 s gap) raised hit sounds to ~86/min. Did we buy faction readability at the cost of noise density?
Change tested: a shared rate limit for the `hit` group (`hit_bread`, `hit_mold`, and the fallbacks `hit_melee`, `hit_arrow`): no two hit sounds closer than `min_gap` seconds (manifest `groups.hit.min_gap`, `src/audio/audio_manager.gd`).

## Method
- Engine recordings, headless, bounded: `pwsh tools/audio/run_godot_checks.ps1 -Integration -SkipIntegrationBattle -Record -RecordSeconds 60 -RecordTag <tag> -ProbeArgs "--probe-seed=11 --hit-group-gap=<g>"`. Round r02, 60 s, the same scripted player, Master recorded after the limiter.
- Same seed: App seeds battles with `randi()`, and the probe calls `seed(11)` first, so every run starts the same battle. The runs are **not** sample-identical: the player's commands are issued on real-time frames, so small timing differences grow.
- Comparability evidence: engine hit events during the recording (before any audio limit) were 113–117, and kills 13–14, in all four runs (±4 %). That is close enough to compare rates; it is not a perfect replay.
- Metrics: `python tools/audio/mix_report.py --rec=<dir> --no-publish`. Engine truth comes from the probe counting every `Events.sfx(&"hit")` by `target_side`.

## Results (one run each)
| Variant | Shared hit gap | Hit sounds / min | bread : mold played | Bread share played (engine events) | Max hits in 1 s | Buried (SFX ≤ music) | At risk | Integrated | Peak | Clipped | Kills |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A (v3.3, no shared cap) | 0 | **83** | 43 : 40 | 0.52 (0.63) | 3 | 5.6 % | 6.1 % | −21.7 LUFS | −3.8 dBFS | 0 | 14 |
| B24 | 0.24 s | 60 | 28 : 32 | 0.47 (0.59) | 3 | 6.0 % | 5.5 % | −22.2 | −4.0 | 0 | 13 |
| B28 | 0.28 s | 58 | 31 : 27 | 0.53 (0.61) | 3 | 7.0 % | 5.4 % | −22.0 | −3.3 | 0 | 14 |
| **B36 (new default)** | 0.36 s | **49** | 26 : 23 | 0.53 (0.63) | 2 | 9.5 % | 5.1 % | −22.2 | −3.3 | 0 | 14 |

Reading:
- Hits arrive in bursts, so the gap mainly thins the bursts. 0.24 → 0.28 s changed little; 0.36 s reached the requested 48–56 hits/min band and lowered the peak burst from 3 to 2 per second.
- Faction readability is kept: both sides stay audible in every variant (played bread share 0.47–0.53). Bread is under-represented relative to engine events (0.59–0.63) in ALL variants, including A, because the two cues have different per-cue gaps and burst timing. The shared cap did not cause this.
- Cost: the buried share rose from 5.6 % to 9.5 %. With fewer hit sounds, the quieter cues (deaths, coins) carry more of the active windows. This is still below the internal 15 % line but it is a real trade-off.
- After setting B36 as the default, a random-seed r02 run gave buried 6.8 %, 0 clipped, no fatigue flags (MIX_REPORT.md, history `v3.4-hitcap`).

## Decision
- **Default: B36 (shared hit gap 0.36 s), chosen on the numbers**: it meets the density target, has a lower burst peak, keeps both factions, and adds no clipping.
- **NOT confirmed as better-sounding.** No human has listened. A blind A/B is in LISTENING_CHECKLIST.md §4.
- If listeners prefer the denser A, or report hits feeling "missing", set `CUE_GROUPS["hit"]["min_gap"]` in tools/audio/synth.py back to 0 or 0.24 and regenerate. It is a manifest-only change; no WAV changes.

## Blind A/B files
`docs/audio/previews/listen/ab_hits_X_30s.mp3` and `ab_hits_Y_30s.mp3`: the same 21–51 s window of the two same-seed recordings, 0.3 s fades only.

---
Key (read only AFTER listening): <details><summary>show</summary>X = B36 (shared cap 0.36 s), Y = A (no shared cap).</details>
