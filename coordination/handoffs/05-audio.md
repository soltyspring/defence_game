# 05-audio handoff
Updated: 2026-10-31 ~16:45 (theme v3 milestone: validated, committing)
Session ID: sess_480b589a-e86a-47ff-bada-af6f34aa4635. Same session resumed after the user restart and the window split. Model claude-opus-5.5, trust-all.

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
