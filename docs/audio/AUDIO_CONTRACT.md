# AUDIO_CONTRACT.md — audio event contract, mixer and budgets (owner: 05-audio)
Version 1.1 (2026-10-31; v1.1 = off-screen policy, alert category, prepare_quit). Godot 4.7.2 / GDScript. Additive changes only without a version bump.
Reads: docs/contracts/ENGINE.md v1.0, INTERFACES.md v1.0. Nothing here changes 02/04 files; integration is requested in `coordination/requests/05-audio-to-*.md`.

## 1. Files
| Path | What |
|---|---|
| `tools/audio/synth.py` | Deterministic generator: every sound is synthesised with numpy (oscillators, noise, envelopes, one-pole filters). No samples, no downloaded audio, no AI audio service. Re-run gives byte-identical WAV/OGG (`validate.py --determinism`). |
| `tools/audio/validate.py` | Objective checks on the actual files → `docs/audio/VALIDATION_REPORT.json`. |
| `tools/audio/run_godot_checks.ps1` | Godot import + parser checks + `audio_selftest.gd` in an isolated temp copy of the project (does not touch the shared `.godot` cache or compete with other workers' editors). |
| `tools/audio/audio_selftest.gd` | Headless logic test of the runtime (Dummy audio driver: logic only, not audible output). |
| `assets/audio/audio_manifest.json` | Cue table + runtime policy + measured stats (generated). |
| `assets/audio/sfx/*.wav` | 29 files / 27 cues. PCM s16le mono 22050 Hz source; Godot imports WAV as QOA by default. |
| `assets/audio/music/*.ogg` | `music_battle` (140 BPM, 16 bars, 27.43 s), `music_menu` (105 BPM, 8 bars, 18.29 s). Ogg Vorbis q3, 44.1 kHz stereo, seamless loops. |
| `src/audio/audio_manager.gd` | Runtime: buses, pooled players, voice limits/stealing, ducking, pause/focus, volumes. Intended autoload `Audio`. |
| `src/audio/audio_event_bridge.gd` | Maps `Events` signals to cues (child of the manager). |
| `tools/audio/_render/` | Intermediate music WAV (has `.gdignore`; never committed). |

## 2. Buses (created at runtime by the manager if absent; no project.godot change needed)
`Master` ← `Music`, `SFX`, `UI`.
- `Master`: `AudioEffectHardLimiter` ceiling −0.5 dB (added once, only if no limiter exists). Muted on focus loss / app pause.
- `Music`: music loops + win/defeat stingers. Low-pass (900 Hz) + −6 dB while the battle is paused. Ducked by priority cues.
- `SFX`: battle sounds. Paused (`stream_paused`) with the battle; new SFX are refused while paused.
- `UI`: taps, errors, confirmations. Keeps working while paused. Volume follows the `sfx` setting (there is no separate UI setting).

## 3. Event contract
### 3.1 Requested addition to `Events` (02): `signal sfx(cue: StringName, params: Dictionary)`
Anyone (02 gameplay, 04 UI) may emit. Audio is the only listener. `cue` is either a concrete id from §5, or one of these semantic ids (the bridge resolves them so 02 needs no audio tables):

| Semantic cue | params | Resolves to |
|---|---|---|
| `&"hit"` | `kind`: `melee`/`ranged`/`siege`, `x` | `hit_arrow` (ranged) else `hit_melee` |
| `&"shoot"` | `projectile`: `arrow`/`rock`/`spit`, `x` | manifest `projectile_cue` (default `shoot_arrow`) |
| `&"death"` | `side`: `player`/`enemy`, `x`, `boss` | `death_ally` / `death_enemy` |
| `&"base_hit"` | `side`: base that was damaged | `hit_base` (enemy base: higher pitch, −2 dB) |
| `&"skill"` | `skill`: skill id | by `Content.skills[id].kind` via manifest `skill_kind_cue` (`aoe_damage`→`skill_slam`, `rally`→`skill_rally`, `meteor`→`skill_barrage`, `heal_allies`→`skill_heal`, `summon`/unknown→`skill_cast`) |
| `&"explosion"` | `x` | `explosion` |

Optional params for every cue: `x` (world px), `vol_db` (additive), `pitch` (multiplier). Off-screen policy (v1.1): 0 dB inside the camera view, linear down to −9 dB at half a screen past the edge, −9 dB beyond; only cues with priority < 5 more than 2 view widths away are dropped. v1.0 dropped everything past ~0.7 screens; in a real r02 battle that silenced all 30 combat cues because the frontline is usually off-screen while the camera follows the hero (fixed and retested: 22 audible, 0 dropped).

Emission volume: the manager rate-limits each cue (`gap`) and caps instances (`max`), so 02 can emit per hit. To keep `sim.events` allocations low, 02 may collapse to at most one `hit`/`shoot` per kind per frame.

### 3.2 Cues derived from signals that already exist (works today, before any integration)
| Signal | Cue |
|---|---|
| `screen_changed` `menu`/`round_select` | `music_menu` (cross-fade 0.8 s) |
| `screen_changed` `battle`, `battle_started` | `music_battle` |
| `battle_ended(won)` | music fades out 0.25 s, `stinger_win` / `stinger_defeat` |
| `battle_paused(p)` | SFX pause, music low-pass and −6 dB |
| `toast` `wave_incoming` / `boss_incoming` / `counterattack` / `hero_dead` | `wave_incoming` / `boss_incoming` / `wave_incoming` pitch 0.85 / `hero_death` |
| `toast` error keys (`not_enough_gold`, `army_full`, `on_cooldown`, `not_enough_mana`, `worker_max`, `round_locked`, …) | `ui_error` |
| `cmd_deploy_unit`, `cmd_buy_worker`, `cmd_hero_skill` | `deploy`, `worker_buy`, skill cue. Played at end of frame and dropped if an error toast arrived for that command (the engine handles commands synchronously). |
| `cmd_start_round`, `cmd_retry`, `cmd_next_round` | `ui_confirm` |
| `cmd_open_screen` (`menu` → `ui_back`, else `ui_tap`), `cmd_set_paused`, `cmd_set_setting` | `ui_tap` |
| `hud_snapshot` deltas (10 Hz) | base HP drop → `hit_base`; army count drop → `death_enemy`/`death_ally`; bounty gold → `gold_tick`; hero alive false→true → `hero_respawn` |
| `cmd_set_setting` / `progress_changed` keys `sfx`, `music`, optional `master` | bus volumes |

No double playback after integration: each derived category (`ui`, `command`, `death`, `base`, `gold`, `hero`, `alert` = wave/boss) switches itself off the first time a direct `Events.sfx` cue of that category arrives. Queued optimistic command cues re-check their category at flush time, so a direct cue that lands in the same frame does not double up.

### 3.3 Public API of `Audio` (for 02/04/07/08; prefer `Events.sfx` from UI)
`play(cue, params={}) -> bool`, `play_music(id, fade=0.8)`, `stop_music(fade=0.8)`, `current_music()`, `duck(db, hold)`, `set_volume(kind, value)`, `get_volume(kind)`, `apply_settings(dict)`, `set_battle_paused(p)`, `stop_all_sfx()`, `snapshot() -> Dictionary` (played/dropped/stolen counters, active voices, peak voices, resident SFX bytes, load errors), signal `cue_played(cue, voice)`.

## 4. Voice limits and mixing policy
- Pools are allocated once at boot (no per-play node creation): **SFX 12**, **UI 3**, stinger 1, music 2 (cross-fade). Godot's WAV playback is cheap ("hundreds of simultaneous voices … are fine" per the docs); 12 is a provisional mobile clarity limit, not a CPU limit.
- Per cue (manifest): `max` simultaneous instances, `gap` minimum retrigger interval, `prio` 0–10, `pitch` random ±jitter, `vol_db` mix gain, `duck` music duck dB.
- Pool full: steal the lowest-priority, oldest voice if its priority ≤ the new cue's; otherwise drop the new cue (counted in `stats.dropped_voices`). Combat hits (prio 1) never displace skills, boss or hero cues (8–10).
- Variants (hit_melee ×3) never repeat the same file twice in a row; pitch jitter ±8 %.
- Ducking: music only; attack 60 dB/s, release 14 dB/s; deepest active request wins. Boss −8 dB, hero death −6, skills −3…−5, wave −4.
- Volume taper: slider v ∈ [0,1] → gain v² (0.5 = −12 dB); 0 mutes the bus.

## 5. Cue list (v1)
UI: `ui_tap`, `ui_back`, `ui_confirm`, `ui_error`. Economy: `deploy`, `worker_buy`, `gold_tick`. Combat: `hit_melee`(3 variants), `hit_arrow`, `shoot_arrow`, `shoot_rock`, `shoot_spit`, `hit_base`, `explosion`, `death_ally`, `death_enemy`. Hero: `hero_death`, `hero_respawn`, `skill_slam`, `skill_rally`, `skill_barrage` (whistle 0.8 s matches `skill_barrage.delay`), `skill_heal`, `skill_cast`. Flow: `wave_incoming`, `boss_incoming`, `stinger_win`, `stinger_defeat`. Music: `music_menu`, `music_battle`.
Style is theme-neutral (chip/arcade timbres). When Q1 (theme) is decided, timbres can be re-voiced in `synth.py` without changing cue ids.

## 6. Budgets (PROVISIONAL; measured values from VALIDATION_REPORT.json / audio_selftest)
| Item | Budget | Measured (2026-10-31) |
|---|---|---|
| Disk, all audio source files | ≤ 2.5 MB | 1,348,388 B (SFX WAV ~0.79 MB + 2 OGG ~0.56 MB) |
| SFX resident in RAM after import | ≤ 2 MiB | 160,960 B (Godot default QOA import; raw PCM would be 792,254 B) |
| Music resident | streamed Ogg, compressed packets only | 2 files, 101 / 91 kbps |
| SFX voices | 12 + UI 3 | selftest stress: peak 12, never exceeded |
| `play()` CPU | — | 3.5–4.2 µs/call on desktop (proxy only; device not measured) |
| Peaks | SFX ≤ −0.9 dBFS sample peak, 0 clipped samples; music decoded ≤ −0.3 dBFS | pass (see report) |
| Worst case all cues at max instances, peak-aligned | limiter on Master | +21.9 dB sum before voice caps → limiter required and present |
APK impact: imported QOA SFX ≈ 0.16 MB + OGG ≈ 0.56 MB.

## 7. Mobile lifecycle
- Quit: call `Audio.prepare_quit()` and quit at least ~0.3 s later (wall clock). AudioServer frees stopped playbacks on its mix thread; quitting while music plays otherwise reports AudioStreamPlayback*/Ogg objects "leaked at exit" (exit-only, OS reclaims memory). Measured: 5/5 runs clean with prepare+wait, 5/5 runs leak 4–6 objects without it. Requested from 02 (A7).
- `NOTIFICATION_APPLICATION_PAUSED` or `FOCUS_OUT` → Master muted; `RESUMED` / `FOCUS_IN` → restored. Desktop focus-out mute can be disabled with `mute_on_focus_loss = false`.
- The engine already auto-pauses the battle on app pause (ENGINE.md §7); audio follows `battle_paused`.
- UNTESTED on device: Android audio focus (calls, other media apps), Bluetooth latency, output latency, speaker loudness. Device evidence is required before release claims.

## 8. Phone-speaker design rule (measured by validate.py)
Phone loudspeakers reproduce little below roughly 300 Hz, so every SFX must have ≥ 25 % of its energy at or above 300 Hz. The first pack failed this for 10 impact/boss sounds (sub-bass thumps); they were re-voiced with saturated (harmonic) bodies and mid-band crunch layers, and now all pass. Music bass plays in the 80–260 Hz octave with a click transient on the kick for the same reason.

## 8b. Mix balance review (tools/audio/preview.py → docs/audio/LOUDNESS.md, previews/*.png)
Finding (measured): in pack v1 the frequent combat cues mixed at −28…−30 LUFS momentary while battle music mixed at −18.6, so hits would sit about 10 dB under the music. Fix: combat cue gains +3…+5 dB and battle music −2 dB (`vol_db` −10). Retest: combat cues now −23…−25 vs music −20.6, still 6–7 dB below one-off cues (skills, alerts) on purpose because they repeat several times per second. Human listening is still required to confirm.

## 9. Limits of the evidence
Objective checks (format, peaks, clipping, DC, edge clicks, spectrum share, loop length/seam, determinism, voice logic) are machine-verified. Whether the sounds are pleasant, readable and not fatiguing has NOT been judged by a human listener; the agent cannot listen. That needs a human listening pass on a phone speaker and headphones.

## 10. Sources (accessed 2026-10-31)
- Godot docs, Importing audio samples: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html — WAV for short repeated SFX and Ogg for music; QOA is the default WAV compression; Ogg costs more CPU; Ogg/MP3 loop flag and loop offset. Observed directly in our sandbox import: `compress/mode=2` (QOA) for WAV, `oggvorbisstr` with `loop=false` (the manager sets `loop` at runtime).
