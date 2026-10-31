# 05-audio handoff
Updated: 2026-10-31 ~08:55 (M3 integration + leak regression: validated, committing)
Session ID: sess_480b589a-e86a-47ff-bada-af6f34aa4635 (resumed on the new account; same session, no window restart, no duplicate worker). Model claude-opus-5.5, trust-all.
Quota at resume: 434.55/10000 (4.3 %). The "QUOTA CHECKPOINT" sections in coordinator-to-05-audio.md are HISTORICAL (previous account), per the user's 08:3x instruction.

## Ownership
assets/audio/**, src/audio/**, tools/audio/**, docs/audio/**, own status/handoff, requests 05-audio-to-*. No engine/core/UI/project.godot edits.

## Read receipts / last processed
handoff (checkpoint c79add3), coordinator-to-05-audio.md (C08 item, quota checkpoint = historical), QUOTA_POLICY.md, DECISIONS.md D1–D12 + Q1 PENDING (theme). 02 commit e9dfaa4 (A2 signal sfx + A3 battle cues) and the project.godot Audio autoload (A1), both read only.

## M3 result (actually run: `pwsh tools/audio/run_godot_checks.ps1 -Integration -BattleSeconds 75` → GODOT AUDIO CHECKS PASS)
The sandbox is a temp copy with its own user dir (`defence_audio_sandbox`), so the shared save is never touched. It uses the real project.godot, which now includes the 02 Audio autoload, plus a sandbox-only AudioProbe autoload.
- Import OK; 5 audio scripts parse; AUDIO SELFTEST PASS with the real autoload (`audio_autoload: true`), 0 exit leaks.
- 02 global selftest: exit 0, 65/65 scripts, audio failures 0. C08 ("audio_manager.gd failed to compile") is NOT reproduced at HEAD.
- Real battle (r02, 75 s, real Events commands, HUD-style decisions):
  - 7 battle builds (retry teardown plus 10 rapid menu↔battle switches); audio child count constant at 19.
  - Command cues match the engine exactly: deploy 13 = sim deployed 13; skill cues 5 = skills_cast 5; worker 1 = 1.
  - 22 combat cues from 02's `Events.sfx`; 0 same-frame duplicates; peak SFX voices 3/12; music players ≤ 2 during crossfade and 1 after settling.
  - Pause blocks SFX and allows UI; focus out mutes Master, focus in unmutes, and the battle stays paused until resume; load errors 0.
  - Derived categories switched off automatically once direct cues arrived (command, death, alert). The ui, base, gold and hero categories are still derived.
- Leak regression (`leak_probe.gd`):
  - empty 0, audio 0, cycle 0 (25 create/free, object delta −9/−10, bus and effect counts constant), quit_prepared 0 (5/5 runs).
  - quit_direct = 4–6 objects as the expected control: quitting while music plays without `prepare_quit` (02 A7).
  - In the battle run, audio-class leaks = 0. The remaining 4–6 GDScript/RefCounted objects reproduce WITHOUT the Audio autoload, using only deploys; reported to 02 as A8.

## Defects found and fixed this milestone (same scenario retested)
1. **Audio objects leaked at teardown**: players freed or quit while playing kept AudioStreamPlayback* alive. `_exit_tree` now stops every player and clears its stream; added `prepare_quit()` (disables new cues and music). The wait before quit must be wall-clock (~0.3 s), because frame-count waits were flaky.
2. **Off-screen culling silenced the whole frontline (found in the real battle)**: v1.0 dropped 30/30 combat cues because the camera follows the hero. The new policy attenuates linearly to −9 dB and drops only priority < 5 cues more than 2 screens away. Retest: 22 audible, 0 dropped, 22 attenuated.
3. **Bridge double-play risk**: added an `alert` category (wave/boss), since 02 now emits these directly as well as toasts. Queued optimistic command cues re-check their category at flush time.
4. **Probe self-leaks**: the probe held a BattleSim reference; it is now released when the report is written.
5. **Runner**: a battle that never starts is now INVALID (during 02's mid-edit, compile errors had produced a fake pass). New gates: deploy cue count = engine deployed; combat with kills must produce at least one combat cue; voice and player bounds.

## Files in this milestone
src/audio/audio_manager.gd, src/audio/audio_event_bridge.gd, tools/audio/{run_godot_checks.ps1, integration_probe.gd(+.uid), leak_probe.gd, audio_selftest.gd}, docs/audio/AUDIO_CONTRACT.md (v1.1), docs/audio/previews/*.png.import, coordination/requests/05-audio-to-02-engine.md (status + A7 quit path + A8 engine leak), this handoff, status. `tools/audio/_render/` is never committed (local reports: `_render/integration/*.json|log`). Audio assets are unchanged (validate.py PASS).

## Git
- Earlier: 67de63b, 067c594, ba38f2d, 5e21a23, c79add3, all PUSHED.
- M3: 10449eed6971f50595c6f937675dab159ec0c676 "[Fix] 실전 통합 검증: 화면 밖 전투음 소거 버그와 종료 시 오디오 누수 수정, 통합 하네스 추가" → PUSHED origin/main (13 files).

## Strongest remaining reasons a reviewer could reject the audio
- Nobody has listened. Audible quality, fatigue and mix balance against real music are unjudged; the agent cannot listen.
- No Android device evidence: playback, audio focus (calls, other apps), output latency, speaker loudness. Desktop headless uses the Dummy driver.
- Quit-path leak until 02 applies A7 (exit-only).
- 04 C1 (volume sliders; settings are still on/off) and C2 (direct UI tap cues; buttons with no command remain silent) are not done.
- The theme (Q1) is pending, so the timbres are theme-neutral placeholders.

## Next task (05)
1. When 02 applies A7: rerun `-Integration` and expect `battle audio_class_leaks=0` without the probe's prepare_quit. Then make the probe stop calling it, so the real path is what gets tested.
2. Hero cues (hero_death/respawn) were not exercised (hero_deaths 0 in 75 s). Add a probe phase that walks the hero into enemies, and check hit_base.
3. After 04 C1/C2: check slider persistence through Save in the sandbox and that UI cues are not doubled.
4. A human listening pass, via 01 (one question at a time) when the queue allows.
