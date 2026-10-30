extends RefCounted
## Non-blocking tutorial banners driven by battle events (docs/design/RELEASE_DESIGN_REVIEW.md §2.3, ROUNDS.md R1).
## Steps run in round.tutorial order; a step shows when its trigger fires and hides when the player performs
## the action or after a timeout. Completed keys are returned in BattleResult.tutorial_done and stored in Save
## so they are not shown again. The game never pauses for a banner. Owner: 02-engine.
##
## Key rules (explicit first, then generic patterns so new 01 keys work without code changes):
##   tut_move_hero      show t=0                          done: hero moved
##   tut_deploy_unit    show after first move or t>=4     done: any deploy
##   tut_buy_worker     show after 1st deploy & gold>=40  done: worker bought
##   tut_destroy_base   show when an ally passes 50% lane done: enemy base damaged
##   tut_skill_<x>      show when mana >= cost of skill_<x> (skill must be in the round) done: skill_<x> cast
##   tut_<x>_unit       show t>=1                          done: a unit with id/tag/attack_type <x> or card <x> deployed
##   tut_boss_warning   show when a boss spawns            done: timeout 5 s
##   tut_<other>        show t>=1                          done: timeout 8 s

const DEFAULT_TIMEOUT := 8.0
const ACTION_TIMEOUT := 20.0

var steps: Array[String] = []
var idx := 0
var shown := ""
var shown_t := 0.0
var done: Array[String] = []
# action flags set by battle.gd
var moved := false
var deployed := 0
var deployed_kinds := {}     # unit ids, tags and attack types deployed this battle
var workers_bought := 0
var skills_cast := 0
var cast_ids := {}
var boss_seen := false
# 01 unit-key aliases (tutorial key names use design words, unit ids are role ids)
const UNIT_ALIASES := {"fast": ["fast", "skirmisher"], "siege": ["siege"], "tank": ["tank"], "ranged": ["ranged", "ranged_basic"]}

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
		"tut_boss_warning": return boss_seen
	if key.begins_with("tut_skill_"):
		var sid := "skill_" + key.trim_prefix("tut_skill_")
		if not sim.skill_ids.has(sid):
			return sim.t >= 1.0   # skill not in this round: show briefly, then time out
		return sim.mana >= float(sim.content.skills[sid].mana) and sim.hero_respawn <= 0.0
	return sim.t >= 1.0

func _completed(key: String, sim) -> bool:
	match key:
		"tut_move_hero": return moved
		"tut_deploy_unit": return deployed > 0
		"tut_buy_worker": return workers_bought > 0
		"tut_destroy_base": return sim.enemy_base.hp < sim.enemy_base.hp_max
		"tut_boss_warning": return false
	if key.begins_with("tut_skill_"):
		return cast_ids.has("skill_" + key.trim_prefix("tut_skill_"))
	if key.ends_with("_unit"):
		var word := key.trim_prefix("tut_").trim_suffix("_unit")
		for alias in UNIT_ALIASES.get(word, [word]):
			if deployed_kinds.has(alias): return true
	return false

func _timeout(key: String) -> float:
	match key:
		"tut_move_hero", "tut_deploy_unit", "tut_buy_worker": return ACTION_TIMEOUT
		"tut_boss_warning": return 5.0
	if key.begins_with("tut_skill_") or key.ends_with("_unit"):
		return ACTION_TIMEOUT
	return DEFAULT_TIMEOUT
