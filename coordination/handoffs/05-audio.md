RULE (line 1, fixed after 3 violations: af491c2, 53883db, f5f42df batch): a commit SHA is written ONLY in a separate tool call made AFTER the Publish-Task call that printed `PUSHED <sha>` has returned; copy it from that output, confirm it with `git ls-remote origin refs/heads/main` (and `git merge-base --is-ancestor <sha> origin/main` after a fetch), and never record the SHA-record commit's own SHA in the file.
# 05-audio handoff
Updated: 2026-11-01 09:1x KST (v4.0: rule kept OFF by coordinator decision; explosion shortened for the 0.5 s death animation)
Session ID: sess_480b589a-e86a-47ff-bada-af6f34aa4635. Model claude-opus-5.5, trust-all. Quota 94 %. Heavy runs only via `coordination/heavy_run_detached.ps1` (headless; lock waits 1000–2500 s). Private APPDATA.

## v4.0 (2026-11-01 ~09:0x, NO heavy runs: quota 91 %, lock wait ~1 h). Coordinator decisions recorded here first.
- Decision (coordinator, after 30401e3/1db1f59/83520c9): the onset-cluster rule stays OFF. The limiter is only a safety net. A softer variant is tried only if a real recording again shows a peak that needs it.
- Decisions: Q1 A; Q2 on hold (no ad/purchase/shop UI); Q3/Q4 fixed; **Q5 = B** (fail 2–3 times, then upgrade and win; D28 was only a default).
- Task now:
  1. Record the decision in ONSET_PEAK_CHECK.md and AUDIO_CONTRACT.md; explain the P5-after 1/45 miss from the re-render log.
  2. 03 e8c6d96 made every death animation play within 0.5 s: measure the death/hit SFX lengths and tails against it; change only after writing criteria first; Python checks only (R1–R4 offline, variant level).
- Done (Python only): decision written in ONSET_PEAK_CHECK.md §6 and AUDIO_CONTRACT.md. P5 after-miss explained: one gold_tick was logged one 512-frame chunk late (time only; verdict stays FAIL). DEATH_SYNC_CHECK.md: criteria T1–T3 first. Only explosion failed T1 (0.56 s); it was shortened 0.7 → 0.5 s, audible end 0.42 s, attack +0.01 dB, −8,820 B. validate/determinism/budget PASS, offline R1–R4 0 fails, 48 files. hero_death 1.0 s is exempt (event cue) and is a listening question for 01/03.`n- Next session (needs Godot via heavy_run_detached, one job): import + selftest, re-record r02/r06/r08 × 11/23/37 with the new explosion, then re-judge D1/D2/G1/G2/R1–R4/P5 with rerender.py. Log fix: read the audio clock BEFORE play() and log both.
- Git (copied from the PUSHED line; git ls-remote origin refs/heads/main = 3821f780398dbc0818603f81ad506709456e4058): 3821f780398dbc0818603f81ad506709456e4058 [Fix].
- Not verified: human listening, real phone.

## v3.9 onset peak (coordinator task coordination/prompts/05-peak-cause.txt). Details: docs/audio/ONSET_PEAK_CHECK.md
- Blue screen 03:55: the 03:31 job had never started (no START), so nothing was lost. Post-crash integrity scan of all modified 05 files: OK.
- Cause of "real −0.50 vs re-render −3.7 dBFS":
  1. Wall-time cue placement. Godot starts voices at the next 4096-frame mix block, so 5 cues started on one sample.
  2. A fixed −444-frame clock offset.
  3. Godot plays QOA data, not the WAV: noisy transients have up to 3.2 dB lower sample peaks.
  With audio-clock starts, the offset and decoded QOA (new tools/audio/qoa.py), the re-render matches all 9 new before-recordings (pb) within **0.67 dB** at the top-5 peaks (P5 PASS).
- Job 1 (pb, rule off, 07:23–07:34): exit 0, selftest/parse PASS, Master peaks −4.34…−2.32 dBFS. No bad cluster this time (alignment is timing luck).
- Rule (manifest `onset_cluster`, audio_manager `_onset_cluster_rule`): from the 4th SFX start within 0.1 s, prio < 3 cues start 6 dB lower; exempt cues lower one earlier low-prio voice instead. Nothing is dropped or delayed, and prio ≥ 3 is never changed.
- Job 2 `05-peak-after-9rec` (08:26:39, HEAVY_JOB_DONE exit 0): P1/P2/P3/P4/P6-G1/P7 PASS. **P5 after FAIL as written** (1 of 45 peaks 2.58 dB; one cue logged one 512-frame chunk late). **G2 FAIL** (hit_bread/hit_mold +5.4 points in one A/B battle, because the rule lowers prio-1 hits). No peak in 18 new recordings needed the rule (all ≤ −2.02 dBFS). **Rule stays OFF**; options (a) keep off, (b) softer variant: coordinator decision. Table: ONSET_PEAK_CHECK.md §5.
- Manifest has no `onset_cluster` (synth.py `ONSET_CLUSTER_ON = False`). Enabling it changes no audio bytes.
- Pass criteria P1–P7: ONSET_PEAK_CHECK.md §3, written before the change.
Git (copied from the PUSHED lines after those calls returned; git ls-remote origin refs/heads/main = 1db1f59b3993080c4228e518c3f738984b5f147a): 30401e3842fd6d8283b78a346d63b075937d4c57 [Feat]; 1db1f59b3993080c4228e518c3f738984b5f147a [Docs].
Not verified: human listening, real phone.

## v3.8 repetition fatigue (coordinator task). Details: docs/audio/REPETITION_CHECK.md, PHONE_SPEAKER_CHECK.md "v3.8 re-judge"
1. Coordinator decision recorded in PHONE_SPEAKER_CHECK.md criteria: G2 is judged by the same-background A/B; real recordings are for anomaly detection only.
2. Criteria R1–R4 written BEFORE measuring (REPETITION_CHECK.md). Recordings: r02/r06/r08 × seeds 11/23/37, 60 s each.
   - Before (`rb`): 13 failing cue-recordings (shoot_spit R2/R4 in r08, death_enemy R3/R4, shoot_arrow R3/R4).
3. Change:
   - `rx` extra variants with stable seeds 70000+; older files are byte-identical. shoot_spit 3 files; death_enemy, shoot_arrow and gold_tick 2 files each.
   - `vol_jitter` ±1 dB in `AudioManager.play()`.
   - New `validate.py` rule: a variant's phone-band level must be within ±0.5 dB of the cue's first file.
   - death_enemy_v2 was rebuilt twice: the first version was +5.4 masked points in the same-background A/B.
   - SFX 43 → 48 = 08's cap (request file updated).
4. After (`rd`, 9 recordings, final assets): R1–R4 0 failures. Integration, selftest and lifecycle 27/27 PASS.
5. Re-judge:
   - Same-background A/B over 9 battles: D1/D2/G1/G2 PASS (G2 max +1.9).
   - Real recordings: D1/D2 PASS and G2 no anomaly. **G1 peak FAIL as written in 1 of 9**: r08 s23 hit −0.50 dBFS at a 5-cue onset cluster, 0 clipped. It was not reproduced by re-rendering the cluster, and the criterion was not edited. Open question for coordinator/01.
Tools added: `tools/audio/repetition_check.py`, `tools/audio/heavy_detached.ps1`, `same_bg_ab.py --tag/--rounds` (per-file worst, vol jitter), `phone_check.py --history`, `run_godot_checks.ps1 -RecordRounds` (+ copies sandbox `.import` for new WAVs).
Git (copied from the PUSHED lines after those calls returned; verified on origin/main): 28d682745662491cbde25d32f8c42191821d2175 [Feat]; ab86f275dfdbde10320aa5f89997563d70c86576 [Test]; 45e384a46332f1d05d43969a41e656e2b2f8f40e [Docs].
Not verified: human listening (blind clips repeat_X/Y_r08_20s.mp3, LISTENING_CHECKLIST §7), real phone.
Next:
- G1 cluster-peak question to the coordinator/01.
- Listening.
- Still waiting on 02 A10, the 01 menu/music decision, and 04 C1/C5.

## v3.7 G2 recheck (review of 4d6f9bd/6737f36/e00aa88; criteria NOT changed). Details: PHONE_SPEAKER_CHECK.md "v3.7 G2 recheck"
1. **Code**: the duck lowers only SFX voices with prio < duck_sfx_below (death_ally < 3, hit_base < 5). wave_cleared (prio 8) and hit_base_mold (prio 5) can never be ducked. Their files and manifest entries are identical between 131dcf2 and HEAD.
2. **Same-background A/B** (new `tools/audio/same_bg_ab.py`; results `docs/audio/same_bg_ab.json`, `same_bg_ab_hit_base_every3s.json`). The 3 BEFORE battles are re-rendered from their own cue logs: A = old assets, no duck; B = new assets + duck.
   - wave_cleared +1.8/0/0 points, hit_base_mold 0/0/0. The largest change of any other cue is +1.8 (one placement, next to the brighter new death_ally). Mix LUFS and peaks are identical.
   - D1/D2/G1/G2 all PASS in the A/B, so per instruction no exclusion and no duck-depth change.
   - hit_base never occurs in r02; a stress A/B with hit_base every 3 s shows the duck only lowers masking of other cues. The hypothesis is rejected.
3. **Fresh 3-seed real recordings** (after2, same config):
   - D1/D2/G1 PASS.
   - **G2 FAIL as written** (hit_bread, death_enemy, wave_cleared, hit_base_mold up to +5.7 points).
   - Two recordings of the identical config differ by up to 7.2 points, so real-recording G2 at 3 seeds is noise-dominated. It stays recorded as FAIL; the criterion was not edited.
No code or asset change in this step (assets byte-identical to 4d6f9bd).
Git (copied from the PUSHED lines after those calls returned; verified on origin/main): b24412de6300ccc77908ca0b9e4f0ca5b71c547b [Test]; e633790bc75969be218f8c6aed0e8b31c1442189 [Docs].
Not verified: human listening, real phone.
Next:
- G2 open item: either more seeds per config (to bring the variance under 2 points), or accept the same-background A/B as the causal test. That is a decision for the coordinator/01; 05 has not changed the criterion.
- Waiting on 02 A10, 01 menu/music decision, 04 C1/C5.
## Blue-screen recovery check (23:2x)
- `git status`: only `tools/audio/run_godot_checks.ps1` was modified (the `-RecordSeeds` edit made just before the crash). Integrity: 19,311 bytes, no NUL, ends with a newline, parses without errors.
- Integrity scan of all 148 tracked 05 files (zero size, NUL bytes, missing EOL, WAV tails of zeros): two flags, both harmless and identical to the committed HEAD:
  - `docs/audio/previews/listen/.gdignore` is 0 bytes by design.
  - `coordination/status/05-audio.md` lacked a final newline when committed; now rewritten with one.
- The interrupted baseline recording left nothing usable and was redone.

## v3.7 (coordinator review of 131dcf2/e09633f: danger cues masked on phone speakers)
Criteria were written BEFORE the change. The 3-seed baseline, diagnosis, change, before/after table and verdicts are all in docs/audio/PHONE_SPEAKER_CHECK.md:
- Baseline (seeds 11/23/37): death_ally masked 10.9/12.5/10.7 %, hit_base 10.9/12.5/10.7 %, p10 down to −1.6 dB.
- Same seed 11 with identical assets: 14.3 % at 23:00 vs 10.9 % now. So the earlier "background differs" explanation was not proven by one seed; the run-to-run noise is about ±3 points.
- Diagnosis: 100 % of low-SNR placements are masked by OTHER battle SFX, never by the music.
  - death_ally had only 3 % of its energy at 1–2 kHz.
  - hit_base loses at 300 Hz–2 kHz.
- Change:
  - death_ally: onset crust snap and 1–4 kHz content (+1.1 dB phone loudness).
  - New runtime danger-cue SFX duck: −6 dB on lower-priority SFX while death_ally / hit_base sound; music untouched.
  - Rejected: a hit_base tock (the offline estimate got worse); hit_base.wav is unchanged.
- After (same seeds):
  - death_ally masked 0.0/3.6/0.0 %, p10 7.1/5.0/3.7 dB
  - hit_base masked 0.0/3.6/1.8 %, p10 6.4/5.5/4.6 dB
  - → D1/D2/G3 PASS
  - Mix −22.0 LUFS on all seeds, peaks ≤ −2.41 dBFS, 0 clipped, no fatigue → G1 PASS
- **G2 NOT met as written**: wave_cleared 3.6 → 7.1 %, hit_base_mold 10.7 → 14.0 %. The masked placements co-occur with wave_incoming/deploy/hit_mold, rarely with death_ally, so this is attributed to battle variance. That is an inference, not proven; it stays open.
- Size: +882 B (death_ally.wav only).
Validation:
- `validate.py --determinism` PASS.
- `python tools/perf/asset_budget_check.py --worktree` → verdict PASS (sfx 43/0.94 MiB, music 2/0.56 MiB).
- `run_godot_checks.ps1` selftest PASS, including the new duck assertions.
- `-Integration -BattleSeconds 80 -Record -RecordSeeds 11,23,37 -Lifecycle` PASS:
  - hits mold 14 / bread 19 / fallback 0; deploy 14 = 14, skill 7 = 7, wave_cleared 1 = 1, upgrade 2 = 2, hero 1 = 1/1
  - 0 dups; audio-class exit leaks 0; lifecycle 27/27; settings 3/3 + 5/5
  - isolation proof: real save unchanged
- No own Godot left running.
Not verified: human listening (nobody has listened), Android device.
Git v3.7 (copied from the PUSHED lines after those calls returned; each verified on origin/main): 4d6f9bdbde82876fff7977404ba06cce8a366fbc [Fix]; 6737f3663927b2d3cf1b32dac882c563fd14359f [Test]; e00aa883435c6a0ff2d68244bbb4995609bc5dd9 [Docs].
Next:
1. G2 follow-up: either more seeds for wave_cleared, or accept it as variance on a listener's judgement.
2. Still waiting: 02 A10 (swarm buzz), 01 menu/music-variation decision, 04 C1/C5.
## Resume check 23:xx
- `origin/checkpoint/quota-20261031-202729/05-audio` (377a780) differs from the worktree only in `tools/audio/_render/**` (local, git-ignored run outputs). Those files are still present locally. All v3.6 work had been pushed before the stop (1da1f8c, c47654e, e4df6f6, d5f145a; d5f145a verified on origin). **Nothing lost.**
- Requests re-read: 01 R1, 02 (A1–A3, A6, A7, A9 done; A8 not started; **A10 unit id / spawn cue: not answered, not in HEAD**), 06 (licence confirmation already answered), 08 AU3 (resolved), coordinator (quota notes historical).
- Decisions: Q1 = A bakery vs mold, Q2 on hold (no purchase/ad sounds), Q3 title "빵집 기사단: 곰팡이 디펜스", Q4 home-screen name "빵집 기사단". Q5 unanswered; D28 is a default, not approval. Nothing in audio depends on Q5.
- Remaining open items, unchanged:
  - fruit-fly buzz: waits for 02 A10
  - folk menu: preview only, NOT connected; waits for 01/user
  - music variation: question candidate with 01
  - B36 hit cap: not listening-confirmed
  - 04 C1 (sliders) / C5 (UI-local upgrade results)

## Re-verification 23:xx (same conditions as v3.6, one serial run)
`pwsh tools/audio/run_godot_checks.ps1 -Integration -BattleSeconds 80 -Record -RecordSeconds 60 -ProbeArgs "--probe-seed=11" -Lifecycle` (sandbox = committed HEAD ae6f9af + 05 worktree; private APPDATA, same method as 10's isolated_godot.ps1) → **GODOT AUDIO CHECKS PASS**:
- hits mold 14 / bread 19 / fallback 0; deploy 14 = 14, skill 7 = 7, wave_cleared 1 = 1, upgrade 2 = 2, hero 1 = 1/1
- 0 same-frame dups, peak SFX voices 4/12, audio-class exit leaks 0
- lifecycle 27/27, settings 3/3 + 5/5 (zero output peak 0)
- Isolation proof: the private user dir has the run's logs; the real save.json was unchanged during the run.
- Also: `validate.py --determinism` PASS (no asset change). Mix: buried 7.9 %, at risk 4.2 %, −22.1 LUFS, peak −4.27 dBFS, 0 clipped, no fatigue/low-heavy flags.
- Phone check on this new recording: worst masked 14.3 % (death_ally, hit_base); before: 12.3–13.0 %. The variation comes from the battle (different background), not from an asset change. Faction hits still classified 100 % correctly.
- `battle_preview_30s.mp3` was regenerated from this recording, and the checklist timestamps were updated to match.
No new code or asset changes in this step.
Git (copied from the PUSHED line after that call returned; verified on origin/main): 131dcf297db150e06d6f0fdc7b05f30cb54a4c0f [Test].
## v3.6 (Codex review of 11c29cc–f5f42df)
01 R1, remaining 3 timbres; only those with a real game event were implemented:
1. **Rally (implemented)**: the event exists (`Events.sfx(&"skill")` → kind `rally` → `skill_rally`; data r04–r10 list skill_rally).
   - New `r36_skill_rally`: oven-door whoosh, five synthetic "hey!" voices (saw source + vowel formants; no samples or speech data), bell accent. 0.9 s, peak −1.0 dBFS, 87 % of energy ≥ 300 Hz.
   - Size +2,206 B (only skill_rally.wav changed).
   - Phone check (same method): masked 0.0 %, at risk 10.7 % (before 0.0 / 3.8 %); phone loudness −26.0 LUFS.
   - Repetition: cooldown 20 s → at most 3 plays/min.
   - The integration battle (r02) has no rally, so engine-path playback of the new file was not observed in the harness. The skill → cue mapping is covered by the selftest, and the selftest also plays every cue.
2. **Fruit-fly buzz (NOT implemented)**: no audio event identifies `e_swarm` (death/hit cues carry no unit id; there is no spawn cue). Requested from 02 as A10 (add `unit` to death, plus a coalesced `spawn` cue).
3. **Folk menu motif (preview only)**: `tools/audio/menu_candidate.py` → `docs/audio/previews/listen/menu_folk_candidate_30s.mp3` (G major, 120 BPM, accordion + pluck + frame drum, peak −3.0 dBFS).
   - NOT in assets, NOT in the manifest, NOT connected. Replace or add = 01/user decision; it overlaps the music-variation question.
4. **Isolation**: `run_godot_checks.ps1` now gives every Godot child a PRIVATE APPDATA (10's isolated_godot.ps1 method) on top of custom_user_dir.
   - Proof line: `user_dir_logs_present=True`, `real_save_changed_during_run=False`.
Validation:
- `validate.py --determinism` PASS.
- `run_godot_checks.ps1 -Integration -BattleSeconds 80 -Record -ProbeArgs --probe-seed=11 -Lifecycle` → PASS:
  - hits mold 12 / bread 21 / fallback 0; deploy 14 = 14, skill 7 = 7, wave_cleared 1 = 1, upgrade 2 = 2, hero 1 = 1/1
  - 0 dups; audio-class exit leaks 0; lifecycle 27/27; settings 3/3 + 5/5
- Mix: buried 7.5 %, 0 clipped. Phone check: worst masked 12.3 % (death_ally).
- No own Godot left running.
Not verified: human listening, Android device.
Git v3.6 (copied from the PUSHED lines of the three earlier calls; each verified with git merge-base --is-ancestor against origin/main): 1da1f8cc909fc52c1313190600b8638f260faf64 [Feat]; c47654ec040fa14d2440415016ca6b96e515dc3d [Test]; e4df6f6914d898f76333e35d1aafcea6ecf791cd [Docs].
## v3.5 (Codex review of 65502e8–53883db: release-facing sound problems)
1. **App lifecycle** (src/audio/audio_manager.gd): APPLICATION_PAUSED/FOCUS_OUT now SUSPEND audio. Master is muted, every player is stream-paused, no new cue or music starts (a requested music change is kept and started on resume). RESUMED/FOCUS_IN continue in place; battle SFX stay paused until the player resumes the battle.
   - New `tools/audio/lifecycle_probe.gd` + `run_godot_checks.ps1 -Lifecycle` → 27/27 checks PASS:
     - Music held 13.842 → 13.854 s over 2 s in background, then continued (+0.93 s after 1 s).
     - A boss warning cut by the background resumed from 0.017 s.
     - Pause screen: 0 SFX leaked, UI taps still sound.
     - After unpausing, combat sounds return. The FOCUS_OUT/IN cycle passes too.
   - Baseline: the same probe against the pre-v3.5 manager FAILED 6 checks (music ran on 1.86 s silently during 2 s background; UI cues could start in background; no suspended state).
   - The notifications are simulated with propagate_notification; real Android audio focus/driver behaviour is NOT verified.
2. **Settings** (02 Save + 04 UI, read-only here): a real second process reads the save left by the first. music 0.3 → restored 0.3, Music bus −20.92 dB; sfx 0 → SFX and UI muted. music 0 + sfx 0 → Master output digital silence (peak 0 over 172,032 samples while 6 cues were triggered).
   - No defect found, so no new request. 04 C1 (sliders) is still open: the UI offers only on/off.
3. **Phone-speaker check** (`tools/audio/phone_check.py` → docs/audio/PHONE_SPEAKER_CHECK.md): 300 Hz high-pass + −6 dB, cues placed every 1 s over a real recorded battle background, SNR on each cue's loud frames.
   - Before (same background): death_ally masked 22.8 %, hit_base 17.5 %, hit_mold and death_enemy 10.5 %.
   - Fixes:
     - death_ally −12 → −8.5 dB
     - death_enemy −12 → −11 dB
     - hit_mold −7 → −6 dB
     - hit_base −9 → −4.5 dB, plus a brighter, longer wood crack and a smaller knock (only hit_base.wav changed; total audio size unchanged, +0 B)
   - After (SAME background): worst masked 10.5 % (death_ally).
   - On a NEW seed-11 recording made with the new levels: worst 13.0 % (death_ally); death_enemy and hit_base 11.1 %.
   - Faction hits classified 100 % correctly full band and with the phone filter (separation 11.25).
   - Whole-mix check: buried 4.7 %, peak −1.74 dBFS, 0 clipped, limiter never engaged.
4. 06 asked for confirmation for its licence screen: replied in `05-audio-to-06-services.md` (all audio original, no third-party content).
Validation:
- `validate.py --determinism` PASS.
- `run_godot_checks.ps1 -Integration -BattleSeconds 80 -Record -ProbeArgs "--probe-seed=11" -Lifecycle` → PASS:
  - hit_mold 11 / bread 23 / fallback 0; deploy 14 = 14, skill 7 = 7, wave_cleared 1 = 1, upgrade 2 = 2, hero 1 = 1/1
  - 0 dups; audio-class exit leaks 0; lifecycle 27/27, settings 3/3 + 5/5
- No own Godot left running.
Not verified: human listening, Android device (lifecycle on a real phone, speaker loudness).
Note: the B36 blind A/B files (v3.4) were recorded before these level changes; they still compare the cap fairly because both used the same levels.
Git v3.5 (copied from PUSHED lines, verified with git log origin/main): 11c29cc1f2890c07d16c272bfffbb032716840f3 [Fix]; 16b7a8dc56c94e280e524e1ff63098bf2f9df237 [Test]; 2a63a65d74f6d131fb886dac6db8641c166c13b2 [Docs]; 8ff87a9a0f663e8cbe67856468ee0b132b2389db [Test]. The first Docs attempt was refused by the helper's diff check (blank line at EOF in PHONE_SPEAKER_CHECK.md); I unstaged only my own 15 paths, fixed the generator and retried.
## v3.4 (Codex review of 91eeb25–f41fd12: "86 hits/min may be noise density")
1. **Shared hit cap**: cue groups in audio_manager.gd (manifest `groups`, cue `group`, stat `dropped_group`); group `hit` = hit_bread/hit_mold/hit_melee/hit_arrow.
   - Same-seed A/B (probe `seed(11)`, r02, 60 s; engine hit events 113–117 and kills 13–14 in every run):

     | Variant | Hits/min | Buried |
     |---|---|---|
     | A (no shared cap) | 83 | 5.6 % |
     | B24 | 60 | 6.0 % |
     | B28 | 58 | 7.0 % |
     | **B36 (default)** | **49** | 9.5 % |

   - All variants: 0 clipped. Bread share played 0.47–0.53 in all variants (engine 0.59–0.63), so both factions stay audible.
   - The default 0.36 s is chosen on the numbers and is NOT listening-confirmed. Blind A/B files `ab_hits_X/Y_30s.mp3`, questions in LISTENING_CHECKLIST.md §4, key folded at the bottom of HIT_DENSITY_AB.md.
   - Default random-seed r02 run: buried 6.8 %, 0 clipped.
2. **01 R1 timbres (2 of 5)**: `ui_confirm` = whisk + tray bell; `skill_barrage` = crumb-shell volley (impacts from 0.8 s = data delay). Size +5,292 B (two WAVs; other WAVs unchanged).
3. Validation:
   - `validate.py --determinism` PASS.
   - `run_godot_checks.ps1 -Integration -BattleSeconds 80 -Record` PASS (hits mold 11 / bread 23 / fallback 0; deploy 14 = 14, skill 7 = 7, wave_cleared 1 = 1, upgrade 2 = 2, hero 1 = 1/1; 0 dups; audio-class exit leaks 0).
   - Selftest PASS including a new shared-gap assertion. No own Godot left running.
4. Music variation: still only a question candidate (not implemented).
Not verified: human listening, Android device.
Git v3.4 (SHAs copied from push output): 65502e837a2ab0ef5b1106640b52cbee41e153e4 [Feat] PUSHED; 48fa978f836b511aff220a6427464fc1ab46d705 [Test] PUSHED; 0726ef9325eb9e1ecbd7095cd15f057be46fd3a9 [Docs] PUSHED; 38a66904b42ab81bb28f18f196387038a5e22730 [Docs] PUSHED (it recorded a WRONG, pre-written SHA 6ec962a; corrected by the next commit).
## v3.3 verification (after 18:30)
1. The WIP from the quiet window (bridge ranged/siege pitch offsets + runner target_side gate) was verified with `pwsh tools/audio/run_godot_checks.ps1 -Integration -BattleSeconds 80 -Record -RecordSeconds 60` (sandbox from HEAD b4b33a7) → **GODOT AUDIO CHECKS PASS**:
   - hits: hit_mold 23, hit_bread 32, fallback hit_melee 0, hit_arrow 0
   - deploy 14 = 14, skill 7 = 7, wave_cleared 1 = 1, upgrade 2 = 2, hero 1 = 1/1
   - 0 same-frame duplicates, peak SFX 4/12, audio-class exit leaks 0
   - New selftest assertion: the real voice `pitch_scale` is ranged ×1.15 / siege ×0.85 / melee ×1.0 within the ±8 % jitter. Selftest PASS (separate run).
   - The first attempt at 18:35 really ran, but its console output was swallowed (PowerShell table formatting). It was rerun for a readable verdict and the rerun is the evidence used.
2. **r02 re-recorded** (60 s, after 02 A9). `mix_report.py --label=v3.3-target_side`:

   | | v3-theme | v3.1 | v3.3 |
   |---|---|---|---|
   | Buried | 7.5 % | 7.8 % | 7.3 % |
   | At risk | 3.9 % | 3.5 % | 4.7 % |
   | Buried ≥ 300 Hz | 5.4 % | 5.5 % | 5.7 % |
   | Integrated loudness | −22.4 | −22.3 | −21.7 LUFS |
   | Clipped samples | 0 | 0 | 0 |

   - Hits now split by faction in the recording: hit_bread 46, hit_mold 40, hit_melee 0, hit_arrow 0.
   - Observation (not a fix): each faction cue has its own 0.22 s gap, so total hit sounds rose from about 44–49/min (one neutral cue) to 86/min. No cue exceeds the fatigue heuristic, but this needs a human listen.
   - One run per version, with different battles (App seeds with randi()).
3. Music variation → question candidate sent to 01 (`05-audio-to-01-director.md`; recommendation B = boss minor variant), queued behind the open Q5. NOT implemented.
4. The 01 R1 timbre gaps found while reading the request (backlog): fruit-fly buzz, rally cheer + oven whoosh, crumb-shell barrage, tray-bell/whisk UI confirm, folk menu motif.
Not verified: human listening, Android device.
Git v3.3 verification (SHAs copied from push output): 91eeb25b02b8a7c34bb4bb3fd7c4bd2faee062a1 [Feat] PUSHED; 734a903c9aa0c28751a3b18ee4679b862576a2bf [Comment] PUSHED; 91394818b42341789a5c6f01f21af35b0b222934 [Docs] PUSHED; caa9cc4e1736a6d4b909d0268a3f2ebb9fd6fba3 [Docs] PUSHED (status only).
## v3.3 (static, quiet window) — Codex review of 15851e2/5758d0b/dcfaaf9/af491c2
Rule acknowledged: SHAs are written only after Publish-Task prints them.
1. **02 A9 target_side**: present since 09508b1 (17:30). Format: `target_side` = victim side; coalescing key `melee:<side>`, `<ranged|siege>:<side>`.
   - My v3.2 line "A9 still not in HEAD" was WRONG: the 17:50 integration run (sandbox HEAD 180d770) already contained 09508b1.
   - That run's report shows hit_mold 21, hit_bread 30, hit_melee 0, hit_arrow 0. The static cross-check of the bridge mapping also matches.
   - Correction sent to 02.
2. **08 AU3**: `git ls-tree` on c6d0e9e gives 43 wav = 43 wav.import and 2 ogg = 2 ogg.import, all `compress/mode=2`, no orphans. Replied in `05-audio-to-08-performance.md` (08 had already marked it resolved at 17:32).
3. **docs/audio/MUSIC_VARIATION_IDEAS.md**: ideas only, not implemented:
   - (A) mold-erosion stem following the frontline
   - (B) breathing room between waves
   - (C) boss minor-key variant
   - (D) village / mold-nest ambience
   - (E) arrangement growing with the round
   - It includes budget estimates and the decisions needed from 01/the user.

Git v3.3 (docs): 11ffe174d31a14d8c1e6d47999a78c942c062a52 [Docs] PUSHED (SHA copied from the push output).

## WIP (written, NOT verified, NOT committed — needs a Godot run after 18:30)
- `src/audio/audio_event_bridge.gd`: ranged hits resolved to hit_mold/hit_bread get pitch 1.15 / −2 dB; siege hits get pitch 0.85 / +1 dB.
- `tools/audio/run_godot_checks.ps1`: new gate that fails if kills > 0 but no hit_mold/hit_bread plays; prints the hit counts.
- Next after 18:30: `pwsh tools/audio/run_godot_checks.ps1 -Integration -BattleSeconds 80` (bounded). If it passes, commit both files with `[Feat]`. Optionally re-record r02 (`-Record`) and run `mix_report.py --label=v3.3`: hit cues are now faction cues, so recheck masking.
## v3.2 (Codex review of cc5dbb8/a4058f3/cb2470a/ee30b9d)
Read: 04 97c8b9c (upgrade buttons live; the engine signals `cmd_buy_upgrade`/`upgrade_result`, codes include save_uncertain). Q2 still on hold: no purchase or ad sounds. 02 A9 `target_side`: still not in HEAD (waiting).
1. **Upgrade sounds**: the bridge plays from the engine reply `Events.upgrade_result` (category `upgrade`). ok → ok cue; already_applied SILENT (double tap → one sound); not_enough_coins → no_coins; save_failed/save_uncertain/read_only → save_failed; locked/unknown/invalid/no_reply → ui_error. A direct `Events.sfx(&"upgrade_result")` from 04 switches the derived path off.
   - Sandbox, real engine path: replies [ok, already_applied, not_enough_coins] → 2 cues, 0 duplicates.
   - Selftest: double tap → 1 cue; direct + engine reply in the same frame → 1 cue.
   - Request to 04 (C5 update): `max_level`/`unavailable` are set UI-locally and are silent until 04 emits the agreed key.
2. **Earned r05 recordings** (02 competent bot via `--autoplay`, no upgrades, no injection):
   - WIN at 396.5 s (`r05_bot`): boss cue 94.77 s, duck −8.0, stinger +1.7 dB over the battle, 0 clipped, whole-run buried 7.5 %, peak voices 6, 3 hero deaths.
   - LOSS at 289.6 s (`r05_bot_v32`): stinger +4.6 dB, buried 7.8 %.
   - The bot outcome is not deterministic between runs.
   - Comparison with the injected endings is in BOSS_ROUND_REPORT.md. Stem decomposition: SFX are already silent during every stinger. The small contrast in the earned win comes from a louder final fight, not from masking.
   - A battle-end SFX hush was implemented, measured as having no effect, and REMOVED. The loss run was recorded with that build, which does not matter because no SFX play in its stinger window.
   - New previews: `earned_victory_ending_v31_30s.mp3`, `earned_defeat_ending_30s.mp3`.
3. **docs/audio/LISTENING_CHECKLIST.md** (Korean): 3 previews × 5 yes/no questions, phone speaker + earphones, timestamps. Status: NOT DONE (nobody has listened).
Harness: `--probe-passive` (record-only; the App autoplay bot plays); upgrade engine-path gate.
Validation (final code): `validate.py --determinism` PASS. `run_godot_checks.ps1 -Integration -BattleSeconds 80` PASS:
- selftest PASS with 0 leaks
- deploy 14 = 14, skill 7 = 7, wave_cleared 1 = 1, upgrade 2 = 2, hero 1 = 1/1
- 0 duplicates, audio-class exit leaks 0
Not verified: human listening, Android device, screen capture (not needed; none taken).
Git v3.2: 15851e269d85a23578b7c548a744d344f7c8def0 [Feat] PUSHED; 5758d0bc2858b926bd00f145b254a03e597fc345 [Docs] PUSHED; dcfaaf9 [Docs] PUSHED (its SHA line was wrong; corrected in the next commit). Rule for me: write SHAs only after the push prints them.
## v3.1 (Codex review of f0646dd/e551fa9, tasks 1–4)
Decisions read: Q3 working title "빵집 기사단: 곰팡이 디펜스" (user, 16:19; the final store name waits for a KIPRIS check). Q2 monetization ON HOLD: no purchase or ad-reward sounds were made.
1. **wave_cleared**: new cue `wave_cleared` (two quick bells up a fifth + crust cheer, 0.7 s, prio 8, gap 1.0, duck −3). The bridge connects to `Events.wave_cleared` (02 22d99ea), category `milestone`.
   - Sandbox (committed HEAD) r02 integration: events 1 = cues 1, 0 same-frame duplicates. 04's banner (0590e7a) emits no sound, so it cannot double.
   - Selftest: two same-frame emits → 1 cue.
   - New runner gate: wave_cleared cues = events.
2. **Upgrade results**: `ui_upgrade_ok`, `ui_upgrade_no_coins`, `ui_upgrade_max`, `ui_upgrade_save_failed`; 4 different files (selftest-checked). Semantic `Events.sfx(&"upgrade_result", {"code"})` with the manifest `upgrade_result_cue` map.
   - Not connected: 04's buttons are disabled. The key name was requested from 04 (C5).
3. **Boss round through the engine** (r05; boss wave at 95 s), headless with hard timeouts. The ending was a sandbox injection at battle t = 115 s through the real `_damage_base → _end → battle_ended` path, reported as injected.
   - Win run: boss_incoming 95.31 s, music ducked −8.0 dB (manifest −8), wave_cleared 54.19 s, stinger_win 115.85 s (+6.8 dB over the battle mix). 30 s window −21.4 LUFS, peak −4.5 dBFS, 0 clipped.
   - Loss run: boss 94.88 s, duck −8.0, stinger_defeat 115.76 s (+8.7 dB). 30 s window −21.6 LUFS, peak −2.38 dBFS, 0 clipped.
   - Both runs: audio-class exit leaks 0, 0 duplicates, peak SFX 4–5/12.
   - New finding: with a different random seed the fight stayed off-screen and 56 % of SFX windows were buried under the music (off-screen −9 dB). A same-seed A/B (probe `seed(7)`) gave −9 dB: 16.5 % buried vs −5 dB: 7.4 %. **Default changed to −5 dB.**
   - r02 re-recorded with v3.1: buried 7.8 %, 0 clipped, 0 low-heavy, no fatigue flags.
   - Report: `docs/audio/BOSS_ROUND_REPORT.md`. Listening files: `previews/listen/boss_to_victory_30s.mp3`, `boss_to_defeat_30s.mp3`, `battle_preview_30s.mp3` (v3.1), `theme_showcase.mp3` (now also wave_cleared plus the 4 upgrade cues).
4. **A9 target_side**: NOT in HEAD (checked in battle_sim.gd). Recorded as WAITING in 05-audio-to-02-engine.md.

Harness changes:
- `-RecordRound`, `-RecordUntilEnd`, `-InjectEnd/-InjectAt`, `-RecordTag`, `-ProbeArgs` (seed, off-screen dB), `-SkipIntegrationBattle`.
- Verbose record runs with leak classification.
- Sandbox cleanup with retries, refusing to run on a dirty sandbox. One run had hit "files held"; it was rerun clean.

Validation: `validate.py --determinism` PASS (43 SFX + 2 loops). Last full `run_godot_checks.ps1 -Integration -BattleSeconds 80 -Record …` → PASS (selftest PASS with 0 leaks; deploy 14 = 14, skill 7 = 7, hero 1 = 1/1, wave_cleared 1 = 1, 0 dups, audio-class exit leaks 0).
Not verified: human listening, Android device, an earned (non-injected) boss win or loss.
Note: inserting the new cues before stinger_defeat in the cue table shifted its noise seed, so stinger_defeat.wav was regenerated (same recipe; validated).
Git v3.1: cc5dbb8bb391976f3f2e5298e01b3b191fb599b8 [Feat] PUSHED; a4058f3f9b7fc0189c98547adac68fcbdc8a7928 [Design] PUSHED; cb2470a [Docs] PUSHED.
## Resume check (09:23 checkpoint)
Compared the worktree with `origin/checkpoint/quota-20261031-092323/05-audio` (d24c7f2). synth.py and VALIDATION_REPORT.json were byte-identical, and the local recordings and baseline were present. Nothing was lost. "HISTORICAL QUOTA CHECKPOINT" sections were ignored as instructed.
Decisions processed: Q1 = A, bakery knights vs mold legion (user, 09:03); D1–D19. Requests: coordinator-to-05-audio including the theme note.

## Steering 15:5x (coordinator: hung run)
- My sandbox Godot (PIDs 31292/8152, record run) plus its pwsh runner (56132) were stopped. The PIDs the coordinator reported (1076/45240) had already exited. No other worker's Godot was touched.
- Root cause: the runner copied the LIVE worktree, including 02's mid-edit `src/core/app.gd`. App failed to compile (`Nonexistent function 'boot'`), so `--quit-after` never fired and the process idled forever.
- Fixes in `run_godot_checks.ps1`:
  - The sandbox is now built from committed HEAD (`git archive`), with only 05 paths overlaid from the worktree.
  - Every Godot call has a hard wall-clock timeout that kills only its own process tree (console wrapper + child, by parent PID).
  - The probe quits itself with code 3 if App has not quit 4 s after `--quit-after`.
  - The 02 engine selftest is now opt-in (`-EngineSelftest`): it now takes > 3 min (balance sims), and QUOTA_POLICY asks for no needless heavy reruns. Audio scripts are still parse-checked on every run.
- A second issue found: other workers' headless Godot runs on the shared project (`--path .`) briefly hold `assets/audio` files open while they scan and import. This caused one failed OGG write and a false "non-deterministic" result. `synth.py` now writes `*.part`/`*.tmp` files and does an atomic `os.replace` with retries.

## Milestones this session (all validated)
1. **v2 mix fix**, committed ccf3033 (PUSHED): hit_melee with 5 variants, body above 300 Hz, gap 0.26 s; lighter wave/rock/music bass.
2. **v3 theme** (this commit):
   - synth v3 bakery and mold palettes.
   - New cues `hit_bread` (3 variants), `hit_mold` (3), `hit_base_mold`.
   - Re-voiced: deploy, worker_buy, death_ally, death_enemy, shoot_spit, explosion, hit_base, wave_incoming, boss_incoming, stinger_win, stinger_defeat, both music loops (accordion/bell/pluck voices; battle bass an octave higher; music_battle vol −12).
   - The manifest now records licence, provenance (tool, recipes, seeds, encoder, reproduce command), theme, and per-cue `faction`/`desc`.
   - Bridge: the victim side decides the material (`target_side`, requested from 02 as A9); `base_hit` side picks the bakery tower or the mold hive (also in HUD-derived base hits).
   - Selftest checks the faction mapping. AUDIO_CONTRACT v1.2 adds a §5b theme table and the character of boss/win/defeat.

## Validation (actual)
- `python tools/audio/validate.py --determinism` → PASS: 38 SFX + 2 loops, 0 differing files on rerun, loops exact length, all ≥ 25 % energy ≥ 300 Hz, peaks ≤ −1 dBFS.
- `pwsh tools/audio/run_godot_checks.ps1 -Integration -BattleSeconds 80 -Record -RecordSeconds 60` (sandbox from HEAD a9223df) → GODOT AUDIO CHECKS PASS:
  - Selftest PASS with 0 exit leaks; leak cycle 0 / quit_direct 0 / quit_prepared 0 (02's A7 is in).
  - 7 battles; deploy 14 = 14, skill 7 = 7; 41 combat cues / 8 kills; hero death 1 (injected) = cue 1, respawn cue 1.
  - 0 same-frame duplicates; max SFX voices 4/12, music players ≤ 2; audio-class exit leaks 0. The remaining 4 GDScript/RefCounted objects are engine-side (A8).
  - Engine selftest skipped (opt-in).
- `python tools/audio/mix_report.py --label=v3-theme` on the 60 s engine recording (r02):

  | Version | Integrated | Buried (SFX ≤ music) | At risk | Buried ≥ 300 Hz | Low-heavy files | Fatigue flags | Disk |
  |---|---|---|---|---|---|---|---|
  | v1 | −21.4 LUFS | 39.0 % | 21.2 % | 27.6 % | 8 | hit_melee | 1,348,388 B |
  | v2 | −21.2 LUFS | 30.3 % | 20.7 % | 14.7 % | 2 | none | 1,365,556 B |
  | v3-theme | −22.4 LUFS | **7.5 %** | 3.9 % | 5.4 % | **0** | none | 1,460,181 B |

  Peak −2.9 dBFS, 0 clipped samples.
- Budgets: disk 1.46 MB ≤ 2.5 MB; SFX resident after QOA import 177,560 B ≤ 2 MiB; voices within pools; `play()` 3.2 µs desktop.
- Listening files:
  - `docs/audio/previews/listen/battle_preview_30s.mp3`: engine recording, 22–52 s.
  - `battle_mix_60s.wav`: the full 60 s engine recording.
  - `theme_showcase.mp3` + `.txt`: offline A/B of faction pairs, boss, win, defeat; peak −1.01 dBFS, 0 full-scale samples.

## Honest limits
- The battle recording mostly uses the neutral `hit_melee`, because 02 does not send `target_side` yet (A9). The bread/mold hit distinction is audible only in the showcase until then. No boss appeared in the 60 s r02 recording; boss, win and defeat are in the showcase only.
- Cue-log alignment is 59/111 within 40 ms, so the per-cue "buried" attribution is approximate; the percentages come from the audio itself.
- Nobody has listened yet. No Android device evidence. Desktop headless Dummy driver.

## Git
- Earlier: 67de63b, 067c594, ba38f2d, 5e21a23, c79add3, 10449ee, 2fae4a3, 6045b37, 1946d0f, ccf3033 (v2), all PUSHED.
- v3 theme: f0646dd14e81a3b753032b792d2525421c193ad1 "[Design] 빵집 기사단·곰팡이 군단 테마 효과음·음악 재작업과 진영별 소리 구분, 실전 믹스 재검증" → PUSHED origin/main (52 files).

## Open requests
- 02: A8 (engine RefCounted exit leak), A9 (`target_side` on hit cues).
- 04: C1 (sliders), C2 (UI cues).
- A human listening pass of `theme_showcase.mp3` and `battle_preview_30s.mp3`, via 01, one question at a time.

## Next task (05)
1. After 02 A9: rerun `-Integration -Record` and `mix_report.py --label=v3-a9`. Expect `hit_mold`/`hit_bread` in the cue counts, and re-measure masking (squish/crunch have a different level from hit_melee).
2. Optional: a boss-round recording (r05 or r10) to measure boss_incoming plus the music duck in a real mix.
3. Act on human listening feedback when it arrives.
