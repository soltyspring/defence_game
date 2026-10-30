# 05-audio → 02-engine requests
Contract: docs/audio/AUDIO_CONTRACT.md v1.0. All audio code/assets are already in 05-owned paths; nothing below asks 02 to write audio logic.

## A1 (P1) Autoload — project.godot `[autoload]`
Add after `Save` and before `App` (the manager reads `/root/Save` settings and `/root/Events` in `_ready`):
```
Audio="*res://src/audio/audio_manager.gd"
```
Resulting order: Events, Perf, Content, Atlas, Save, **Audio**, App. No bus layout file or other project setting is required: the manager creates `Music`/`SFX`/`UI` buses and the Master limiter at runtime if they are absent.
Acceptance: `--headless --path . -s res://tools/audio/audio_selftest.gd` prints `"audio_autoload": true` and `AUDIO SELFTEST PASS`; game boots with no audio errors in the log.

## A2 (P1) Signal bus addition — src/core/events.gd + INTERFACES.md §1 (additive)
```gdscript
signal sfx(cue: StringName, params: Dictionary)
```
## A3 (P1) Combat cue emission from battle.gd `_drain_events` (needs new sim events)
Emit semantic cues; the audio bridge resolves names (AUDIO_CONTRACT §3.1), so 02 needs no audio tables.
| Where in battle_sim.gd | Emit (via battle.gd) |
|---|---|
| `deploy()` success (existing `"deploy"` event) | `Events.sfx.emit(&"deploy", {"unit": id})` |
| `buy_worker()` success (existing `"worker"` event) | `Events.sfx.emit(&"worker_buy", {})` |
| `cast()` success (existing `"skill"` event) | `Events.sfx.emit(&"skill", {"skill": id})` |
| existing `"hero_respawn"` event (currently not forwarded) | `Events.sfx.emit(&"hero_respawn", {})` |
| `_kill()` hero (existing `"hero_dead"`) | `Events.sfx.emit(&"hero_death", {})` |
| melee hit in `_resolve_attack` / projectile impact in `_step_projectiles` | `&"hit"` `{"kind": "melee"|"ranged"|"siege", "x": tgt.x}` |
| projectile spawn in `_resolve_attack` | `&"shoot"` `{"projectile": p.kind, "x": u.x}` |
| `_kill()` non-hero | `&"death"` `{"side": "player"|"enemy", "x": u.x, "boss": u.is_boss}` |
| `_damage_base()` | `&"base_hit"` `{"side": "player"|"enemy"}` |
| `_fx("explosion", ...)` / self_destruct | `&"explosion"` `{"x": x}` |
Performance note: the manager already rate-limits (`gap`) and caps instances, so per-hit emission is safe. If you want to avoid allocating an event array per hit, collapse to one `hit`/`shoot` per kind per frame; that is enough for audio.
Once these arrive, the bridge automatically stops its interim HUD-delta/optimistic cues for that category (no double playback).
Acceptance: in a 60 s autoplay battle, `Audio.snapshot().played` > 0 for `hit`/`death` cues and `stats.peak_voices` ≤ 12.

## A4 (P2) .gitignore
Add `/tools/audio/_render/` (intermediate music WAV, ~5 MB; already has `.gdignore` and is never staged by 05).

## A5 (P2) Import files
When you run `--import` on the shared checkout, Godot will create `assets/audio/**/*.import` and `src/audio/*.gd.uid`, `tools/audio/*.gd.uid` files. They are 05-owned paths: please leave them unstaged; 05 commits them. Default import settings are correct (WAV → QOA, Ogg loop is set at runtime).

## A6 (P3) Perf report
Optional: include `Audio.snapshot()` (if `/root/Audio` exists) in the `--quit-after` print and `Perf.snapshot()` so 08 can read voice/drop counts.
