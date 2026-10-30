extends RefCounted
## Non-blocking tutorial banners driven by battle events (docs/design/RELEASE_DESIGN_REVIEW.md §2.3, ROUNDS.md R1).
## Steps run in round.tutorial order; each shows when its trigger fires and hides when the player performs the action
## (or after a timeout). Completed keys are reported so Save can skip them next time. Owner: 02-engine.

const TIMEOUT := 8.0

var steps: Array[String] = []
var idx := 0
var shown := ""
var shown_t := 0.0
var done: Array[String] = []
# action flags set by battle.gd
var moved := false
var deployed := 0
var deployed_kinds := {}
var workers_bought := 0
var skills_cast := 0
var boss_seen := false

func setup(round_steps: Array, already_done: Array) -> void:
	steps.clear()
	for s in round_steps:
		if s != null and not already_done.has(str(s)):
			steps.append(str(s))

## Returns the key to show ("" to hide) when it changed since the last call, otherwise null.
func update(sim, dt: float) -> Variant:
	if idx >= steps.size():
		if shown != "":
			shown = ""
			return ""
		return null
	var key := steps[idx]
	if shown == "":
		if _trigger(key, sim):
			shown = key
			shown_t = 0.0
			return key
		return null
	shown_t += dt
	if _completed(key, sim) or shown_t >= _timeout(key):
		done.append(key)
		idx += 1
		shown = ""
		return ""
	return null

func _trigger(key: String, sim) -> bool:
	match key:
		"tut_move_hero": return true
		"tut_deploy_unit": return moved or sim.t >= 4.0
		"tut_buy_worker": return deployed > 0 and sim.gold >= 40.0
		"tut_destroy_base":
			for u in sim.players:
				if not u.dying and u.x >= sim.L * 0.5: return true
			return false
		"tut_skill_slam":
			for sid in sim.skill_ids:
				if sim.mana >= float(sim.content.skills[sid].mana): return true
			return false
		"tut_boss_warning": return boss_seen
	return sim.t >= 1.0

func _completed(key: String, sim) -> bool:
	match key:
		"tut_move_hero": return moved
		"tut_deploy_unit": return deployed > 0
		"tut_buy_worker": return workers_bought > 0
		"tut_destroy_base": return sim.enemy_base.hp < sim.enemy_base.hp_max
		"tut_skill_slam": return skills_cast > 0
		"tut_ranged_unit": return deployed_kinds.has("ranged")
		"tut_tank_unit": return deployed_kinds.has("tank")
	return false

func _timeout(key: String) -> float:
	match key:
		"tut_move_hero", "tut_deploy_unit", "tut_buy_worker", "tut_skill_slam": return 20.0   # wait for the action
		"tut_boss_warning": return 5.0
	return TIMEOUT
