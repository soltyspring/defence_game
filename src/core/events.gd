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
## 01 D32 (3): a content update removed upgrade levels and/or refunded coins. info = Save.migration_notice() =
## {"levels": int, "coins": int, "from": String, "to": String}; text key `notice.content_migrated` ({levels}, {coins}).
## App emits it once per session, right after the menu screen is mounted, while a notice is pending. The notice stays
## in the save until the UI sends cmd_ack_content_migrated (so it is not lost if no screen shows it yet).
signal content_migrated(info: Dictionary)

# ---- UI -> Engine ----
signal cmd_start_round(round_id: String)
signal cmd_deploy_unit(unit_id: String)
signal cmd_buy_worker()
signal cmd_hero_move(dir: int)
## Presentation-only scouting; never teleports the hero or changes the simulation.
signal cmd_camera_seek(world_x: float)
signal cmd_camera_follow()
signal cmd_hero_skill(skill_id: String)
signal cmd_set_paused(paused: bool)
signal cmd_retry()
signal cmd_next_round()
signal cmd_open_screen(screen: StringName)
signal cmd_set_setting(key: String, value: Variant)
## Meta upgrade purchase (04 upgrade screen). Engine calls Save.buy_upgrade and answers with upgrade_result.
signal cmd_buy_upgrade(upgrade_id: String, to_level: int)
## {"id", "to_level", "code" (Save.UPG_* codes), "coins", "level"} — coins/level are the values after the call.
signal upgrade_result(result: Dictionary)
## The UI has shown the content_migrated notice: the engine clears it from the save.
signal cmd_ack_content_migrated()
