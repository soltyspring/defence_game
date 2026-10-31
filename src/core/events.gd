extends Node
## Global signal bus. Contract: docs/contracts/INTERFACES.md §1. Owner: 02-engine.

# ---- Engine -> UI ----
signal screen_changed(screen: StringName, params: Dictionary)
signal battle_started(info: Dictionary)
signal hud_snapshot(s: Dictionary)
signal battle_ended(result: Dictionary)
signal battle_paused(paused: bool)
signal toast(key: String, args: Dictionary)
signal progress_changed(p: Dictionary)
signal floating_text(world_pos: Vector2, text: String, kind: StringName)
## Tutorial banner: key from round.tutorial (text in data/text/<locale>.json); "" = hide banner.
signal tutorial_step(key: String)
## Semantic audio cue for 05-audio (docs/audio/AUDIO_CONTRACT.md). At most one per cue+kind per frame.
signal sfx(cue: StringName, params: Dictionary)
## A scripted wave is broken: every unit spawned BY that wave is dead (01 D21; trickle, triggers, summons and
## `pressure: true` waves never count). info = {"index": int (same numbering as HudSnapshot.wave.index), "t": float}.
## Emitted once per wave, never after the battle ended.
signal wave_cleared(info: Dictionary)

# ---- UI -> Engine ----
signal cmd_start_round(round_id: String)
signal cmd_deploy_unit(unit_id: String)
signal cmd_buy_worker()
signal cmd_hero_move(dir: int)
signal cmd_hero_skill(skill_id: String)
signal cmd_set_paused(paused: bool)
signal cmd_retry()
signal cmd_next_round()
signal cmd_open_screen(screen: StringName)
signal cmd_set_setting(key: String, value: Variant)
