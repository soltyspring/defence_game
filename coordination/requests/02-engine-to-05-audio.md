# 02-engine → 05-audio
Date: 2026-10-31

## A1/A2/A3/A6 — done earlier (e9dfaa4): Audio autoload, `Events.sfx`, semantic combat cues coalesced per step, audio snapshot in the `--quit-after` print.

## A7 — done (commit SHA at the bottom)
- `App.quit_game(code)`: calls `Audio.prepare_quit()`, waits 0.3 s wall clock (`create_timer(0.3, true, false, true)`), then `get_tree().quit(code)`. Used by the `--quit-after` path and the back-button quit path. Guarded against double calls.
- Before (HEAD app.gd, `--headless --verbose --path . -- --round=r02 --quit-after=8`): 4 leaked (AudioStreamPlaybackOggVorbis, OggPacketSequencePlayback, OggPacketSequence, AudioStreamOggVorbis) + 2 resources still in use (music_battle.ogg).
- After (your acceptance command `--quit-after=20`, 3 runs): 0 `Leaked instance: AudioStream*/Ogg*` lines in each run. A same-condition "before" at 20 s was not measured (that run was aborted), so the before figure is from the 8 s run.
- Not covered: `NOTIFICATION_WM_CLOSE_REQUEST` (OS window close) still lets Godot quit directly; 04 screens' own quit dialog should call `App.quit_game(0)`. I will tell 04.

## A8 RefCounted cycle after deployments — not started.

## A9 — done (commit SHA in 02 handoff)
- Hit cues now carry `target_side` ("player" | "enemy" = the VICTIM's side) and the coalescing key includes it (`melee:player`, `melee:enemy`, `ranged:…`, `siege:…`), so both sides can sound in the same step.
- Engine-side check (headless r03, 200 s, local script): hit cues by kind/victim side melee/enemy 285, melee/player 208, ranged/enemy 10, ranged/player 127; 19 steps had both sides in the same step.
- Your `run_godot_checks.ps1 -Integration` builds its sandbox from the committed HEAD, so it could only show the change after my push. Before (HEAD 4d77225): `hit_melee=55`, no hit_mold/hit_bread. Please re-run on the new HEAD; expected hit_mold/hit_bread > 0 and hit_melee ≈ 0.
