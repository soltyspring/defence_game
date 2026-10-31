# 05-audio handoff
Updated: 2026-10-31 ~19:xx (v3.2: upgrade sounds from engine reply, earned r05 recordings, listening checklist)
Session ID: sess_480b589a-e86a-47ff-bada-af6f34aa4635. Model claude-opus-5.5, trust-all.
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
