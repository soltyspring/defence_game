extends SceneTree
const Sim := preload("res://src/gameplay/battle_sim.gd")
const Bot := preload("res://src/gameplay/bot_player.gd")
const DECK := ["melee_basic","ranged_basic","tank","fast","siege"]
var rows: Array = []
func _initialize() -> void: _run.call_deferred()

## Model assumption: first-clear + 3-star rewards earned once, no repeat grind, no kill gold.
## Spend on the active five and hero/supply/worker/base, cheapest eligible upgrade first.
static func build_upgrades(c, round_n: int, paid_gold: int) -> Dictionary:
	var budget := paid_gold
	for n in range(1,round_n):
		var rw: Dictionary = c.get_round("r%02d" % n).reward
		budget += int(rw.first_clear_coins) + int(rw.get("three_star_bonus_coins",0))
	return spend(c, round_n, budget, {})

static func spend(c, round_n: int, budget: int, current: Dictionary) -> Dictionary:
	var upgrades := current.duplicate()
	var active := ["up_hero","up_supply_regen","up_worker","up_base_hp"]
	for id in DECK: active.append("up_"+id)
	while true:
		var choice := {}
		var cheapest := 2147483647
		for u in c.meta.upgrades:
			if str(u.id) not in active: continue
			var target := str(u.target)
			if target.begins_with("unit:") and int(c.units[target.trim_prefix("unit:")].get("unlock_round",1)) > round_n: continue
			var lv := int(upgrades.get(str(u.id),1))
			if lv >= int(u.max_level): continue
			if int(u.get("level_unlock_rounds",{}).get(str(lv+1),1)) > round_n: continue
			if int(u.costs[lv-1]) < cheapest:
				cheapest = int(u.costs[lv-1]); choice=u
		if choice.is_empty() or cheapest > budget: break
		budget -= cheapest
		upgrades[str(choice.id)] = int(upgrades.get(str(choice.id),1))+1
	return {"upgrades":upgrades,"remaining":budget}

func _run() -> void:
	var c = root.get_node("Content")
	var sample := [1,10,20,22,23,24,40,41,42,43,60,61,62,78,79,80,95,96,97,100]
	for n in sample:
		var cumulative := 0
		for p in c.meta.iap_catalog.products:
			if int(p.target_round) <= n: cumulative += int(p.gold)
		for paid in ([0,cumulative] if cumulative>0 else [0]):
			var plan := build_upgrades(c,n,paid)
			for skill in [1,2]:
				for seed_value in [11,29,47]:
					var sim = Sim.new()
					sim.setup(c,"r%02d"%n,seed_value,plan.upgrades)
					var bot=Bot.new(skill,seed_value)
					while not sim.ended and sim.t < 600:
						bot.act(sim,1.0/30.0)
						sim.step(1.0/30.0)
					var row={"round":n,"paid_gold":paid,"skill":skill,"seed":seed_value,"won":sim.ended and sim.enemy_base.hp<=0,"seconds":snappedf(sim.t,0.1),"base_hp":snappedf(sim.player_base.hp,0.1),"upgrades":plan.upgrades}
					rows.append(row)
					print("BALANCE ",JSON.stringify(row))
	var file=FileAccess.open("res://build/campaign100/balance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"assumption":"First-clear and three-star rewards, no grinding, cheapest active upgrade, 30Hz, 600s cap. Bot results are not human conversion evidence.","rows":rows},"  "))
	file.close()
	quit()
