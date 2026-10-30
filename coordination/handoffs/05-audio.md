# 05-audio handoff — ACCOUNT-CHANGE CHECKPOINT
Updated: 2026-10-31 (M3 interrupted by user stop request for account change)
Session ID: sess_480b589a-e86a-47ff-bada-af6f34aa4635 (from KIRO_SESSION_ID). Live PID hint from coordinator: 26668.
Model: claude-opus-5.5, trust-all. Model/account never changed by me. STOPPED: waiting for the user to log in to a new account. No new work started after the stop request.

## Ownership (unchanged)
assets/audio/**, src/audio/**, tools/audio/**, docs/audio/**, coordination/status|handoffs/05-audio.md, coordination/requests/05-audio-to-*.md. Engine/core/UI/project.godot not edited.

## User decisions
None made for audio. DECISIONS.md D1–D12 DEFAULT, Q1 theme PENDING (01 owns). Nothing here is user-approved.

## Current task (M3, unfinished)
Real-project integration check of the audio manager and event bridge in an isolated sandbox, plus finding the cause of the exit leak and fixing it.

## Results so far (actually run before the stop)
1. **Sandbox isolation bug found and fixed in the script.** M1/M2 runs used the same project name, so the sandbox's Save wrote the SHARED `%APPDATA%/Godot/app_userdata/Lane Defence/save.json`. The end values were sfx 1.0 / music 0.8 (defaults), but any prior user values would have been reset. The new `run_godot_checks.ps1` gives the copy a custom user dir `defence_audio_sandbox`.
2. **C08 coordinator report "script failed to compile: res://src/audio/audio_manager.gd".** Not reproduced. 02's global selftest run in the sandbox with the A1 autoload line injected: exit 0, scripts_ok 59/59, audio_failures 0. The shared report at 07:01 also shows 0 failures. The original was most likely an in-progress write.
3. **Leak traced to its source.** The exit leak came from audio players freed or quit while still playing (`AudioStreamPlayback*`, `OggPacketSequence*`, streams).
   - `leak_probe --mode=cycle` before the fix: 65 leaked objects + 6 resources.
   - After the fix (`_exit_tree` stops every player and clears its stream): 0 leaks, object delta −10 over 25 create/use/free cycles, bus and effect counts constant.
   - Remaining leak case: quitting while music plays (AudioServer frees playbacks only during its per-frame update). `quit_direct`: 4 objects + 2 resources leaked. `quit_prepared` (new `Audio.prepare_quit()`, then quit one frame later): 0. A quit-path request to 02 still needs to be written.
4. **Bounded real headless battle** in the sandbox (r02, 75 s, A1 autoload injected, AudioProbe driving the real `Events` commands):
   - Cues matched engine truth: deploy cues 11 = sim deployed 11; skill_slam 3 = skills_cast 3; ui_error 6 = 5 failed taps + 1 round_locked.
   - Same-frame duplicate cues: 0. Peak SFX voices 2, UI 2. Music players ≤ 2 during crossfade and 1 after settling. Audio child count constant at 19 across 6 battle builds and 10 rapid menu↔battle switches.
   - Pause: SFX refused, UI allowed, resume worked. Focus out muted Master; focus in unmuted, battle stayed paused, explicit resume worked. Load errors 0.
   - Known gaps: the retry teardown did NOT happen (cmd_retry on a locked r02 → round_locked toast). The probe now unlocks r01–r03 in the sandbox save, but that has not been rerun. No hit_base, hero or worker cues were exercised. `events_has_sfx`=false (02's A2 is not done).

## Files
- SAFE / validated, committed in this checkpoint: `src/audio/audio_manager.gd` (teardown fix + `prepare_quit()`; validated by the cycle / quit_prepared / quit_direct probes and the earlier integration run), `tools/audio/leak_probe.gd` (+ `.uid`).
- **WIP, NOT committed** (last edits unverified because the run was interrupted): `tools/audio/run_godot_checks.ps1` (the leak-gate and battle-leak edits may be half-applied; `quit_prepared` appears once), `tools/audio/integration_probe.gd` (+ `.uid`) (method callbacks, sandbox unlock, kills/hero truth, report + `prepare_quit` at quit-after − 0.5 s). Leave them for the coordinator WIP checkpoint branch.
- Untracked, not mine to decide yet: `docs/audio/previews/*.png.import` (editor-generated, harmless; commit with the next audio commit). `tools/audio/_render/` is never committed.

## Exact next steps after login
1. Inspect the diff of `tools/audio/run_godot_checks.ps1`, then run `pwsh -NoProfile -File tools/audio/run_godot_checks.ps1 -Integration -BattleSeconds 75`. Expect PASS with 0 exit leaks for empty/audio/cycle/quit_prepared/battle, and `quit_direct` > 0 (informational).
2. Check the report `tools/audio/_render/integration/audio_integration_report.json`: retry teardown happened (battles_started ≥ 7, children constant), engine_truth kills vs death_enemy cues (one cue per 10 Hz snapshot, so the expected ratio is ≤ 1), hero_deaths vs hero_death cues.
3. Commit the probe + runner + preview `.import` files via Publish-Task (Test/Fix).
4. Write a request to 02: A7, in the App `--quit-after` / back-to-quit path, call `Audio.prepare_quit()` if `/root/Audio` exists, then quit on the next frame. Repeat A1–A3 (still not done: no `Audio` autoload, no `Events.sfx`).
5. Update status and this handoff with SHAs, and record the strongest remaining reasons a reviewer could reject the audio.

## Strongest remaining reasons a reviewer could reject the audio (honest)
- The real project still has no `Audio` autoload (02 A1), so the shipped game currently plays no sound. Integration is proven only in the sandbox with the injected line.
- No human has listened to any sound. Android device playback, audio focus and latency are untested.
- Combat hit sounds and the hero-respawn cue only come from 10 Hz HUD-snapshot inference until 02 adds `Events.sfx`.

## Git
- Earlier: 67de63b, 067c594, ba38f2d, 5e21a23, all PUSHED origin/main.
- Checkpoint: c79add364587e3b82cbb63bb4fa0f00af13b94a8 "[Fix] 오디오 매니저 종료 시 재생 객체 누수 수정과 누수 재현 프로브 추가" → PUSHED origin/main (audio_manager.gd, leak_probe.gd + .uid, handoff, status). WIP left uncommitted: run_godot_checks.ps1, integration_probe.gd + .uid, docs/audio/previews/*.png.import.
