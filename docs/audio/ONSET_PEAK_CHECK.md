# ONSET_PEAK_CHECK.md — simultaneous-start peaks and a re-render that matches the recording (05-audio, v3.9)
Status: written 2026-11-01 03:3x KST. The pass criteria in §3 were written BEFORE any runtime change. Nobody has listened, and nothing was checked on a real phone.

## 1. Question (coordinator, after 28d6827/ab86f27/45e384a/cc5078f)
- In v3.8, recording `rd_r08_s23` peaked at −0.50 dBFS on the Master (the limiter ceiling). Re-rendering the same moment from its cue log gave −3.7 dBFS.
- If that 3 dB gap is not explained, neither the real-recording G1 verdict nor the re-render tool can be trusted.
- Coordinator decision: the Master limiter stays as a safety net, but passing because of it does not count. A simultaneous-start limit may be added only after the cause is confirmed.

## 2. What the re-render did differently from the game mix (static analysis + forensic check on the v3.8 recordings)
| Item asked | Finding |
|---|---|
| Music / ambience | The comparison is SFX stem vs SFX-only render, so music is not part of it. At the peak the music stem was −18.5 dBFS and the UI stem silent. There is no ambience bus. Not the cause. |
| Bus volume, ducking | SFX bus 0 dB in every recording. The danger-cue duck is an instant step on lower-priority voices that are playing; the render models the same rule. Not the cause: with real start times the render matches (below). |
| Pitch and ±1 dB jitter in the log | Already logged since v3.8: the player's `pitch_scale` and final `volume_db`, which include the jitter, off-screen attenuation and duck-at-start. The parts were not logged separately. v3.9 logs them separately (vol_jitter, offscreen, duck_at_start) and adds the voice index and every duck event. |
| Start-time resolution | **This is the cause.** The log time is the wall clock when the main thread emits the cue. Godot starts a voice at the NEXT mix block. The headless Dummy driver mixes 4096 frames per block (92.9 ms at 44.1 kHz) and sleeps a fixed time after each block, so audio time falls behind the wall clock: +0.03 s at 5 s, a jump of about 0.3 s near 9–15 s, then +0.66 s by 53 s in `rd_r08_s23`. The re-render placed cues at wall time × a linear scale. |
| Measurement point | Stems (SFX/UI/Music) are recorded pre-fader at the end of their bus; the Master is recorded after the hard limiter (ceiling −0.5 dB). The G1 peak is the Master value. At the peak the SFX stem alone was −0.60 dBFS. |

Forensic check: each logged cue's real start sample was found by matched filtering the SFX stem with the cue's own file, using the logged variant and pitch.
- `rd_r08_s23`, the 6 cues the log spreads over 117 ms (43.331–43.448 s wall): shoot_spit, deploy, hit_bread, explosion and death_enemy all started on the same sample (audio 42.7263 s, within 2.5 ms). death_ally started exactly one block (92.9 ms) later.
- Re-render with those real starts: −0.83 dBFS vs stem −0.60 (0.23 dB apart). Re-render with log times: −3.59 dBFS.
- Same scripted moment in `rd_r08_s11`: the starts fell into two blocks (deploy alone, then 4 cues together). Real-start render −2.48 vs stem −2.44 dBFS (0.04 dB); log-time render −3.85.
- Steps between real starts are exact multiples of 4096 frames.

Conclusion: the peak comes from **simultaneous starts**, i.e. transients of several sounds aligned on one sample.
- Three of the five sounds (hit_bread, explosion, death_enemy) were emitted in the same game frame by one explosion. They align on any audio driver.
- The other two came 34–51 ms earlier. They aligned only because this test driver collects 93 ms of starts into one block. Phone drivers use smaller blocks: Godot's default output latency is 15 ms, not measured on a device. So the harness overstates this part.

### 2b. Confirmation with the v3.9 log (job 1, 9 new recordings `pb`, rule off, 07:23–07:34)
The probe now logs, for every cue:
- its start on the audio clock: the playback position of a silent 11025 Hz clock voice started together with the capture;
- its voice index and the parts of its volume: vol_jitter, off-screen attenuation, duck at start;
- every danger-duck change of an earlier voice.

Every cue has an audio time. The mixer block is 4096 frames in all 9.

Two more differences between the re-render and the game were found and modelled. Neither involves a fitted level.
1. **A fixed clock offset.** On every clearly matched cue, the real start is exactly **444 frames (10.1 ms) before** the logged clock position: 64/65 in pb_r02_s11, 75/76 in pb_r06_s11. `rerender.py` measures this per recording by matched filtering and applies it as a constant time shift. It was −444 in all 9.
2. **Godot plays the imported QOA data, not the source WAV.** Our SFX WAVs are imported with `compress/mode=2` (QOA, lossy). New `tools/audio/qoa.py` decodes the imported `.sample` files; each is matched to its source by the md5 in Godot's `.md5` file.
   - QOA changes noisy transients the most. Decoded sample peaks fall by up to 3.2 dB: hit_melee_1 −1.00 → −3.74, shoot_arrow_v2 −4.24, hit_bread 1/2/3 −2.4/−2.7/−3.4 dBFS. RMS changes by 0 to −1.2 dB.
   - A few files rise instead: death_ally −0.21; ui_back 0.00 dBFS, with 1 sample clamped at full scale.
   - With source WAVs, isolated hit_bread/shoot_arrow/skill_slam rendered +1.1 to +2.8 dB above the stem peak. That was the 1.75 dB miss at pb_r02_s11 33.73 s.

**P5 tool validity, before-recordings: PASS.** The re-render (logged audio starts −444 frames, QOA data, logged volume, logged ducks, voice reuse cuts) vs the real SFX stem at the 5 largest peaks of each recording: worst difference **0.67 dB** over all 9 (per recording 0.14–0.67). 10 ms envelope correlation 0.997–0.998. 0 files fell back to WAV.

Where the v3.8 gap came from (rd_r08_s23: stem −0.60, old re-render −3.6/−3.7 dBFS):
- Start times: the cue log's wall time with a linear scale spread a one-block cluster over 117 ms. Real-start render −0.83; log-time render −3.59.
- The remaining 0.2 dB is QOA vs WAV and interpolation.
- The Master (−0.50) is the SFX stem plus music at −18.5 dBFS, through the limiter (ceiling −0.5 dB).

Neither G1 tool was wrong about the Master value. Only the re-render could not reproduce it. Real-recording G1 is now backed by a re-render that matches within 1 dB.

Before-recordings (`pb`, same seeds, rule off): Master peaks −4.34…−2.32 dBFS, 0 clipped samples. **This time no recording had a bad alignment.** Which starts share a block is decided by real-time scheduling, so a 5-cue same-sample cluster is not reproducible on demand. Simulating the rule on these 9 logs fires 0–5 times per recording. It does not change their largest peak, because none of those peaks sits in a cluster.

Decision: the cause is confirmed (same-sample starts; same-frame starts align on every driver), so the rule in §4 is implemented. It is committed **switched off** (no `onset_cluster` in the manifest) until the after-run (job 2) meets P1–P7. Its effect on the one known bad case, from the matched real starts of rd_r08_s23, is −0.83 → −2.58 dBFS SFX: shoot_spit and hit_bread are lowered 6 dB by the 4th and 5th start. In the 9 new before-recordings it changes no peak, which job 2 checks in real recordings.

Not a cause, recorded for 08/QA: QOA overshoot. ui_back decodes to 0.00 dBFS with 1 clamped sample, ui_error to −0.02, ui_tap to −0.28, death_ally to −0.21. At their `vol_db` the bus level stays ≤ −8 dBFS, so the output is not clipped. `validate.py` checks only the source WAV (≤ −0.9 dBFS). A decoded-QOA peak check is a possible follow-up and is not part of this change.

## 3. Pass criteria for the fix (written before the change)
Same 9 recordings as v3.8 (r02/r06/r08 × seeds 11/23/37, 60 s, heavy_run lock, private APPDATA), before = v3.9 log without the rule, after = with the rule.
- **P1 peak**: Master sample peak ≤ −1.0 dBFS and 0 clipped samples in **all 9** after-recordings. Also in the same-background re-render (pre-limiter SFX + UI + music sum) of all 9 before-battles with the rule applied.
- **P2 danger audibility**: D1 masked ≤ 8 % for death_ally and hit_base in every recording, both in the same-background A/B and in the real after-recordings; D2 p10 ≥ 0 dB.
- **P3 repetition**: R1–R4 failures = 0 in the 9 after-recordings.
- **P4 exemptions**: cues with priority ≥ 3 lowered, delayed or dropped by the rule = **0**. That set includes death_ally, death_enemy, explosion, hit_base, hit_base_mold, deploy, worker_buy, wave_incoming, wave_cleared, boss_incoming, hero and skill cues. Counted by a runtime stat and checked in the selftest and in all 9 recordings.
- **P5 tool validity**: re-render vs real SFX stem within **1 dB** at the stem's 5 largest peaks (separate 0.5 s regions) in all 9 before- and 9 after-recordings.
- **P6 no side effects**: G1 integrated loudness within the before-range ±0.5 dB; G2 no other cue's masked % worse by more than 2 points in the same-background A/B.
- **P7 files**: SFX file count stays 48, new WAV bytes = 0.

If the cause turns out NOT to be simultaneous starts, no limit is added; only the found cause is fixed.

## 3b. Run log
- 03:31 job 1 (`05-peak-before-9rec`) was queued. It never got the lock: no START line in heavy_run.log. The 03:55 blue screen (0x3B, coordinator NOTE 06:49) removed it, and it produced no files.
- 07:05 job 1 was requeued once, after a post-crash integrity scan of all modified 05 files: no zero-length files, no NUL bytes, all end with a newline, Python compiles, PowerShell parses.
- Headless only. No visible window and no GPU capture is needed for audio.

## 4. Planned rule (only if job 1 confirms the cause): onset-cluster limit on the SFX bus
- Manifest policy `onset_cluster`: `window` 0.10 s (covers the 92.9 ms test block), `max_full` 3, `db` −6, `exempt_prio` 3.
- When a new SFX voice starts and it is the 4th or later start on the SFX bus within the last 0.10 s (game clock):
  - if the new cue is low priority (≤ 2: hits, shots, gold_tick), it starts 6 dB lower;
  - if it is exempt (≥ 3), it starts unchanged, and ONE still-sounding low-priority voice that started in the window and was not lowered yet is lowered by 6 dB (the oldest first).
- Nothing is delayed or dropped. Exempt cues are never changed. Stats: `cluster_events`, `cluster_lowered`, `cluster_exempt_touched` (must stay 0).
- Expected effect on the v3.8 peak moment (real-start render of `rd_r08_s23`): −0.83 → −2.58 dBFS. Rule firing rate in the v3.8 recordings: 4+ SFX starts within 100 ms happened 21 times in 9 minutes.

## 5. Result (job 2 `05-peak-after-9rec`, lock 08:26:39, HEAVY_JOB_DONE exit 0; after = rule ON from snapshot, tag `pa`)
Same rounds, seeds and settings as job 1 (`pb`, rule off). Headless only, private APPDATA, real save unchanged.
- Integration: hit_mold 12 / hit_bread 21 / fallback 0; deploy 14 = 14; skills 7 = 7; wave_cleared 1 = 1; upgrade cues 2 = 2; hero death/respawn 1/1; 0 same-frame duplicates; 0 audio-class leaks.
- Selftest PASS, including the new onset-cluster tests. Lifecycle 27/27, settings write 3/3, read 5/5.

| Criterion | Before `pb` (rule off) | After `pa` (rule on) | Verdict |
|---|---|---|---|
| P1 Master peak ≤ −1.0 dBFS, 0 clipped, all 9 | −4.34…−2.32, 0 clipped | −3.67…−2.02, 0 clipped | PASS. Note: the before-set already passed, so this run does not show a benefit of the rule. |
| P1 same-background, rule simulated on the 9 before-battles | pre-limiter −4.54…−2.30 | identical (the rule fired 0–5× per battle, never at a peak) | PASS, no change |
| P2 D1 danger masked ≤ 8 % / D2 p10 ≥ 0 dB | A/B: death_ally 0–6.2 %, hit_base 0–4.2 %, p10 ≥ 2.5. Real: death_ally 0–8.3 %, hit_base 0–8.3 %, p10 ≥ 2.2 | A/B: identical. Real: death_ally 0–7.3 %, hit_base 0–7.5 %, p10 ≥ 0.7 | PASS (real before shows 8.3 % once, inside the replicate noise) |
| P3 R1–R4 failures | 0 | 0 | PASS |
| P4 prio ≥ 3 cues changed by the rule | — | 0 (cluster_events 0–4 per recording, 12 lowered low-priority starts, 6 retro) | PASS |
| P5 re-render vs stem, top-5 peaks ≤ 1 dB | worst 0.67 dB | worst **2.58 dB** (pa_r08_s23, 45.09 s; other 44 peaks ≤ 0.48) | **FAIL as written** (after) |
| P6 G1 loudness within before-range ±0.5 | −21.9…−21.2 LUFS | −22.0…−21.2 LUFS, no fatigue flag | PASS |
| P6 G2 other cues ≤ +2 points (same-background A/B) | — | **hit_bread +5.4, hit_mold +5.4** (r02_s23: 3 of 56 placements fall in a dense spot and are lowered 6 dB); all other cues +0.0 | **FAIL as written** |
| P7 files / bytes | 48 / — | 48, +0 B | PASS |

P5 miss, cause found (time only, no level fitted):
- The miss is one gold_tick. Its real start is 956 frames before the logged clock position, i.e. −444 − 512.
- Godot mixes in 512-frame chunks inside the 4096-frame block. The probe reads the clock right after `play()`, so the logged position is one chunk late when a chunk is mixed in between.
- With `--refine-chunks` (diagnostic only; it moves a cue by whole 512-frame chunks when that clearly lowers the local residual), that recording's worst peak becomes 0.36 dB. Only this one cue moved.
- The verdict stays FAIL, because the diagnostic is not part of the pre-written method.

**Decision:** the rule is NOT enabled.
- It fails G2: by design it lowers prio-1 hits in dense moments, and in the same-background A/B that costs hit_bread/hit_mold 5.4 masked points in one battle.
- In 18 new recordings, no peak needed it: all are ≤ −2.02 dBFS with or without it. The only bad case remains the v3.8 recording, where the rule would have given an estimated −2.58 instead of −0.83 dBFS.
- The code and the selftest stay in the build, inactive (no `onset_cluster` in the manifest; `ONSET_CLUSTER_ON = False` in synth.py).
- Options for the coordinator: (a) keep it off and treat −0.5 dBFS clusters as rare, with the limiter as the safety net (0 clipped samples); (b) a softer variant (only the retro lowering, or −3 dB), re-judged with the same P1–P7. 05 has not changed any criterion.

What the coordinator asked to be explained is now explained and reproducible:
- The real −0.50 vs re-render −3.7 dBFS gap came from start-time resolution. The re-render placed cues at wall time, while Godot starts them on 4096-frame blocks (5 cues on one sample), with a fixed −444-frame clock offset and QOA data instead of the WAV.
- The re-render now matches 17 of 18 new recordings within 0.67 dB at their top-5 peaks.

Not verified: human listening (nobody has listened) and a real phone (all phone figures are the desktop proxy). Phone audio drivers use smaller blocks than this headless driver; not measured on a device.

## 6. Coordinator decision (2026-11-01 ~09:0x) and the P5 after-miss
- **Decision:** the onset-cluster rule stays OFF. None of the 9 new recordings needed it (all ≤ −2.02 dBFS), and enabling it costs hit_bread/hit_mold +5.4 masked points. The limiter is only a safety net. A softer variant is tried only if a real recording shows a peak that needs it again.
- **P5 after-miss (1 of 45 peaks, pa_r08_s23 at 45.09 s, 2.58 dB): explained from the re-render log; time only.**
  - The gold_tick logged at audio 45.08154 s really started 956 frames earlier, i.e. −444 − 512. Matched filter: level within 0.03 dB of its logged volume.
  - Shifting that one cue by one 512-frame mix chunk (`rerender.py --refine-chunks`, diagnostic) makes the peak −0.04 dB; no other cue of the 140 moved.
  - Likely mechanism: the probe reads the clock voice's playback position right after `play()`. When the mixer finishes a 512-frame chunk in between, the logged position is one chunk late. This is consistent with the data, but it was seen once and not proven in Godot's source.
  - The verdict stays FAIL as written. A next-session fix to the log: read the clock position BEFORE `play()` in the manager, and log both.
