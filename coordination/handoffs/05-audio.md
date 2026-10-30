# 05-audio handoff
Updated: 2026-10-31 (M1 done)
Model: claude-opus-5.5, trust-all. Model/account never changed. Effort flag: not changed by me (no verified readback); work did not need a restart.

## Ownership acknowledged (Eight-worker expansion)
Exclusive: assets/audio/**, src/audio/**, tools/audio/**, docs/audio/**, coordination/status/05-audio.md, coordination/handoffs/05-audio.md, coordination/requests/05-audio-to-*.md.
NOT mine: project.godot/autoloads/.gitignore (02), src/core/** and src/gameplay/** (02), src/ui/** settings UI + tests harness/export presets (04), data/** (01). Integration is requested in request files only.

## Read receipts
BRIEF.md (production/revenue, atlas, per-task push, eight-worker, QUALITY_REVIEW pointer), OWNERSHIP.md, GIT_WORKFLOW.md (acknowledged: Publish-Task.ps1 only, explicit owned paths, [Type] Korean subject, no add -A/reset/rebase/stash/force), QUALITY_REVIEW.md (read in full), QUOTA_POLICY.md, WINDOW_STABILITY.md, ENGINE.md v1.0, INTERFACES.md v1.0, coordinator-to-05-audio.md (eight-worker + Dispatch R4), DECISIONS.md.
Last processed: decisions D1–D12, Q1 PENDING (theme); requests coordinator-to-05-audio incl. Dispatch R4 (sha256 46274F81…).
Dispatch R4 actions: hostile reject→fix→retest applied to my own pack with measured checks (first pack failed 20 checks: 10 sounds with < 25 % energy above 300 Hz = weak on phone speakers, DC, a bad loop metric; re-voiced and re-measured → PASS). Primary source cited (Godot import docs). Visible tests: none run by me (headless only, isolated sandbox; no windows opened).

## Delivered (M1)
- tools/audio/synth.py — deterministic numpy synthesis (no samples/downloads/AI services). 27 cues / 29 WAV + 2 seamless Ogg loops.
- tools/audio/validate.py → docs/audio/VALIDATION_REPORT.json; tools/audio/run_godot_checks.ps1 (isolated temp project copy); tools/audio/audio_selftest.gd.
- assets/audio/audio_manifest.json, assets/audio/sfx/*.wav, assets/audio/music/music_battle.ogg, music_menu.ogg.
- src/audio/audio_manager.gd (buses Music/SFX/UI + Master limiter at runtime, pools SFX 12 / UI 3 / stinger / 2 music, per-cue max+gap+priority stealing, variants, ducking, pause low-pass, focus mute, v² volume taper, snapshot stats), src/audio/audio_event_bridge.gd (maps existing Events signals now; Events.sfx when 02 adds it; auto-disables derived categories to avoid double play).
- docs/audio/AUDIO_CONTRACT.md v1.0 (event contract, mixer, budgets, lifecycle, evidence limits, sources).

## Validation evidence (actual)
- `python tools/audio/validate.py --determinism` → AUDIO VALIDATE PASS. 29 SFX: PCM16 mono 22050 Hz, peaks ≤ −0.9 dBFS (−1.0 target), 0 clipped samples, DC ok, edge samples < 0.01, ≥ 25 % energy ≥ 300 Hz. Music: decoded 1,209,600/1,209,600 and 806,400/806,400 samples (exact loop length), seam jump 0.0029 / 0.0063 vs track p99.9 step 0.256 / 0.026, decoded peaks −2.46 / −3.13 dBFS, 101 / 91 kbps. Re-run byte-identical (determinism: 0 differing files).
- Budgets: disk 1,348,388 B; SFX resident after Godot import 160,960 B (QOA, observed `compress/mode=2`); raw PCM would be 792,254 B.
- `pwsh tools/audio/run_godot_checks.ps1` → Godot 4.7.2 import OK (31 audio files), PARSE OK for audio_manager.gd, audio_event_bridge.gd, audio_selftest.gd; AUDIO SELFTEST PASS (pool cap 12 never exceeded in 600-attempt stress, low-prio never steals / high-prio steals, gap + max-instance limits, boss duck ≤ −7.5 dB then release to 0, pause blocks SFX but not UI + music low-pass on, settings via Events.cmd_set_setting: music 0 mutes, sfx 0.5 → −12.04 dB on SFX and UI buses, focus out/in mutes/unmutes Master, menu/battle music switching, failed deploy plays only ui_error, HUD deltas → 3 cues, semantic cue resolution, direct cue disables derived category). play() ≈ 3.5–4.2 µs/call desktop proxy.
- Exit noise: Godot reports leaked ObjectDB instances at exit in the -s run (likely autoload teardown; not yet attributed).
- NOT verified: audible quality/fatigue (agent cannot listen), Android device playback, audio focus, latency, speaker loudness.

## Git
- 67de63b6eb68aff617732b8e1c3408ea9e5df853 "[Feat] 오리지널 합성 효과음·배경음 팩과 오디오 매니저 추가" → PUSHED origin/main (38 files).
- 067c5948758e77f15cff903d42e51d12a1831852 "[Docs] 오디오 이벤트 계약·검증 보고서와 통합 요청 추가" → PUSHED origin/main (6 files).
- M2 "[Fix] 전투 효과음 믹스 균형 조정과 스펙트로그램·라우드니스 증거 추가": SHA in status file after push.

## M2 (mix balance + reviewer evidence)
- tools/audio/preview.py → docs/audio/previews/sfx_contact_sheet.png (29 spectrogram+waveform panels), previews/music_overview.png (loop shown twice, seam marked), docs/audio/LOUDNESS.md (BS.1770 K-weighted max momentary loudness per cue).
- Hostile finding (measured): combat cues mixed −28…−30 LUFS vs battle music −18.6, about 10 dB buried. Fix: hit/shoot/gold gains +3…+5 dB, battle music vol_db −8 → −10. Retest: combat −22…−25 vs music −20.6; validate.py --determinism PASS; run_godot_checks.ps1 PASS. Audio files unchanged (only manifest gains).
- The shared checkout's editor imported my assets: committed assets/audio/**/*.import (WAV QOA compress/mode=2, Ogg loop=false; loop is set at runtime) and src/audio/*.gd.uid, tools/audio/audio_selftest.gd.uid.

## Requests sent
- 05-audio-to-02-engine.md: A1 autoload `Audio` after Save; A2 `signal sfx(cue, params)`; A3 combat cue emission table; A4 .gitignore `/tools/audio/_render/`; A5 leave audio .import/.uid unstaged for 05; A6 Audio.snapshot in perf print.
- 05-audio-to-04-client.md: C1 volume sliders (emit on release); C2 ui_* cues via Events.sfx; C3 add audio tests to run_tests + exclude tools/* from export; C4 report audibility in visible/device tests.

## Dependencies
02 A1/A2/A3 for full integration (audio already works through existing signals once autoloaded). 04 C1/C2. Q1 theme (01) for re-voicing timbres. A human listening pass (through 01, one question at a time, not asked yet).

## Next task (05)
1. Watch 02/04 responses to A1–A6 / C1–C4; after autoload lands, run a real battle (headless autoplay) and record Audio.snapshot() voice/drop counts.
2. Theme re-voice once Q1 is answered; extra cues if 01 adds units/skills (per-unit deploy variants, boss-specific stingers).
3. Attribute/clean the exit leak warning in the -s run.
