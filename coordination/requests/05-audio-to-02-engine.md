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

## Status update 2026-10-31 08:5x (05 verified, read-only)
- A1 DONE in project.godot (Audio after Save, before App). A2 DONE (`signal sfx`). A3 DONE (e9dfaa4): sandbox battle r02 75 s shows deploy cues 13 = sim deployed 13, skill cues 5 = skills_cast 5, 22 combat cues, 0 same-frame duplicates, peak SFX voices 3/12, music players ≤ 2. Global selftest 65/65 scripts, audio failures 0 (C08 not reproduced).
- 05 fix shipped on its side: v1.0 off-screen culling dropped all 30 combat cues in that battle (frontline off-screen); now attenuates to −9 dB instead.

## A7 (P2) Quit path: release audio before quitting
`App._process` `--quit-after` branch and `_on_back()` quit branch call `get_tree().quit()` while music is playing. Godot then reports `AudioStreamPlaybackOggVorbis`, `OggPacketSequence*`, `AudioStreamOggVorbis` leaked at exit (4–6 objects, 5/5 runs). Requested change:
```gdscript
var au := get_node_or_null("/root/Audio")
if au and au.has_method("prepare_quit"): au.prepare_quit()
await get_tree().create_timer(0.3, true, false, true).timeout   # wall clock; mixer thread frees playbacks
get_tree().quit(0)
```
Acceptance: `--headless --verbose --path . -- --round=r02 --quit-after=20` prints no `Leaked instance: AudioStream*/Ogg*` lines. Repro without your change: `pwsh tools/audio/run_godot_checks.ps1 -Integration` → `leak_quit_direct` 4–6 objects, `leak_quit_prepared` 0.

## A8 (P3, engine-side finding, not audio) RefCounted leak after battles with deployments
Reproduced WITHOUT the Audio autoload (sandbox, `Audio=` line removed): a tiny autoload that only emits `cmd_deploy_unit(first card)` every 1.5 s during r02, `--quit-after=27` → at exit `GDScriptNativeClass`, `GDScript` (refcount 2), 2× `RefCounted` leaked (4 objects). Same run without deployments: 0. Likely a reference cycle among battle_sim RefCounted objects (e.g. Unit.w_target / Projectile.target holding Units, or a Unit referencing its sim) surviving battle teardown. Exit-only report, but if it is a per-battle cycle it accumulates across retries in a long session. 05 does not edit gameplay; repro script text available on request.

## Status 2026-10-31 16:4x
- A7 seen in f92f9f6 (App single quit path calls `Audio.prepare_quit()` + 0.3 s wait). Sandbox quit leaks now 0 audio-class objects. Thank you.
- Note: my sandbox run at 15:54 copied a mid-edit `src/core/app.gd` from the live worktree (App failed to compile → nothing quit → hang). 05 now builds its sandbox from committed HEAD only (git archive) and has hard per-call timeouts; no action needed from 02.

## A9 (P2) Theme v1.2: victim side on hit cues
Theme Q1 = A (bakery vs mold). Hits now sound by the VICTIM's material (bread crunches, mold squishes). Please add `target_side` to the hit cue params and include it in the coalescing key so both sides can sound in the same frame:
```gdscript
# battle_sim.gd, melee hit (line ~633) and projectile impact (line ~863)
var ts := "player" if tgt.side == SIDE_PLAYER else "enemy"
_cue(&"hit", "melee:" + ts, {"kind": "melee", "x": tgt.x, "target_side": ts})
```
(For base hits nothing changes: `base_hit` `side` already selects bakery tower vs mold hive.)
Acceptance: `pwsh tools/audio/run_godot_checks.ps1 -Integration` → integration report `cue_counts` contains `hit_mold` and `hit_bread` and `hit_melee` drops to ~0. Without A9 the bridge falls back to the neutral `hit_melee`, so nothing breaks.

## Status 2026-10-31 (after 22d99ea / up to ebe2910)
- A9 (`target_side` on hit cues): NOT in HEAD (`battle_sim.gd` hit cues still send only `kind`, `x`). 05 is WAITING; the bridge keeps the neutral `hit_melee` fallback, so nothing is broken.
- `wave_cleared` (v1.4) consumed: one `wave_cleared` cue per event, verified in sandbox r02 (events 1 = cues 1, 0 same-frame duplicates) and r05 (cue at ~54 s).
- Note for A/B testing: App uses `randi()` for the battle seed outside `--autoplay`; 05's sandbox probe calls `seed(N)` to make A/B runs comparable. No change requested.
