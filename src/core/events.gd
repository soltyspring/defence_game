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
