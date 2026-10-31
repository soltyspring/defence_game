# 05-audio handoff — USER CHECKPOINT (stop requested)
Updated: 2026-10-31 (stopped at a safe point on user instruction; no new work started)
Session ID: sess_480b589a-e86a-47ff-bada-af6f34aa4635. Model claude-opus-5.5, trust-all. Same session, no window restart.
Processes: none of mine running. The Godot processes PID 49528/43864 are 06's `tests/services/test_services_integration.gd` and were left untouched.

## Ownership
assets/audio/**, src/audio/**, tools/audio/**, docs/audio/**, own status/handoff, requests 05-audio-to-*.

## Task in progress (from the reviewer: 10449ee/2fae4a3 reviewed)
(1) Hero death/respawn cue verification in the probe. (2) Reduce the "nobody has listened" gap: record 60 s of a real-mix battle, measure loudness, clipping, masking, low-frequency content and repetition fatigue, and prepare a 30 s preview for the user.

## Done and validated (committed in this checkpoint)
- `tools/audio/integration_probe.gd`: aggressive hero policy (advance while hp > 40 %). If no natural hero death happens, a sandbox-only injection sets hero hp to 1 and walks the hero in, so the kill goes through the real damage → `_kill` → `hero_dead` → `Events.sfx` path; reported as `hero_death_injected`. Record mode (`--probe-mode=record`) runs one clean battle: AudioEffectRecord on Master (post-limiter) plus SFX/UI/Music stems, cue onset log, Music bus gain log.
- `tools/audio/run_godot_checks.ps1`: hero gates (deaths ≥ 1, hero_death cues = engine deaths, respawn cue ≥ 1) and `-Record [-RecordSeconds 60]`.
  - Validation: `pwsh tools/audio/run_godot_checks.ps1 -Integration -BattleSeconds 80` → GODOT AUDIO CHECKS PASS. hero: engine deaths 1 (injected) = hero_death cues 1, hero_respawn cues 1. Combat cues 73 / kills 8, deploy 14 = 14, skill 7 = 7, 0 same-frame duplicates, peak SFX voices 4, audio-class exit leaks 0, engine selftest 66/66.
  - Honesty note: the hero death was injected (hp = 1); natural deaths in 75–80 s were 0.
- `-Record` run (r02, 60 s, project autoload + 02 emitters): recording OK, 134 cues logged.
- `tools/audio/mix_report.py` → `docs/audio/MIX_REPORT.md`, `docs/audio/previews/mix_timeline.png`, `docs/audio/previews/listen/battle_mix_60s.wav` (exact engine Master output, 10.5 MB), `docs/audio/previews/listen/battle_preview_30s.mp3` (22–52 s, 10 cue kinds / 95 cues, 192 kbps, 0.3 s fades only; for the user to listen to), plus `listen/.gdignore`.
- Measured findings (CURRENT committed assets, v1):
  - Integrated −21.4 LUFS; peak −3.39 dBFS; true peak −3.23 dBTP; 0 clipped samples; limiter never engaged.
  - SFX buried under music (≤ 0 dB) in 127/326 = 39 % of active windows, plus 21 % at risk; with a 300 Hz high-pass (phone proxy) 28 % buried. Median SFX − music is +1.2 dB full band.
  - LOW-HEAVY (> 50 % of energy below 300 Hz): hit_melee 1–3, wave_incoming 78 %, music_battle 70 %, shoot_rock, boss_incoming, stinger_defeat. The whole mix loses 3.6 dB under a 300 Hz high-pass.
  - Fatigue: hit_melee 70/min, max 5 in 1 s, 12 gaps < 150 ms, 9 plays per file per 10 s, only 3 variants.
  - Caveat: aligning the cue log to the audio matched only 59/134 cues within 30 ms, so the "which cues were buried" list is approximate. Level, clipping and masking-percentage figures come from the audio itself and do not depend on that alignment.

## NOT validated — left in the worktree (do not commit as-is)
- `tools/audio/synth.py` (v2 fixes for the findings, NOT regenerated or measured yet):
  - hit_melee: 5 variants, body moved above 300 Hz plus a 220 Hz high-pass, vol −9 → −7, max 3 → 2, gap 0.045 → 0.26.
  - wave_incoming: drum and horn raised in pitch.
  - shoot_rock: high-passed.
  - battle music: bass 0.42 → 0.26, kick 0.6 → 0.42.
  - GENERATOR_VERSION 2.
- `docs/audio/mix_summary_before.json` (v1 baseline numbers for the before/after comparison) and `tools/audio/_render/baseline_v1/` (local copy, never committed).
- `docs/audio/VALIDATION_REPORT.json` (rewritten by a run without `--determinism`; do not commit this weaker report).

## Exact next steps
1. `python tools/audio/synth.py` then `python tools/audio/validate.py --determinism` (must PASS; check that hit_melee_4/5 exist and that the manifest has 5 hit_melee files).
2. `python tools/audio/preview.py` (LOUDNESS.md), then `pwsh tools/audio/run_godot_checks.ps1 -Integration -BattleSeconds 80 -Record`, then `python tools/audio/mix_report.py`.
3. Compare against `docs/audio/mix_summary_before.json`. Targets (internal): buried < 15 %, no LOW-HEAVY combat cue, hit_melee max ≤ 4/s and no gaps < 150 ms, still 0 clipping. Move the new numbers into MIX_REPORT.md under a "before → after" section and keep the v1 numbers.
4. Improve the cue alignment in mix_report.py: log the audio-clock time (`AudioServer.get_time_since_last_mix()` + mixed frames) in the probe instead of wall clock.
5. Publish, then ask 01 (one question at a time) to have the user listen to `docs/audio/previews/listen/battle_preview_30s.mp3`.

## Git
- Earlier: 67de63b, 067c594, ba38f2d, 5e21a23, c79add3, 10449ee, 2fae4a3, all PUSHED.
- Checkpoint commit: see push output / status file. If the push fails, mark PUSH_PENDING.

## Open requests
02: A7 (`prepare_quit` on the quit path), A8 (engine RefCounted exit leak, not audio). 04: C1 sliders, C2 UI cues. Q1 theme pending (01).

## Strongest remaining reasons a reviewer could reject the audio
Nobody has listened yet (the preview now exists for that). Measured masking is 39 % with low-heavy combat sounds in the shipped v1 assets (fix drafted, not verified). No Android device evidence.
