extends SceneTree
const Sim := preload("res://src/gameplay/battle_sim.gd")
const Bot := preload("res://src/gameplay/bot_player.gd")
const Plan := preload("res://tests/acceptance/probe_campaign100_balance.gd")
var results: Array = []
func _initialize() -> void: _run.call_deferred()

func battle(c, n: int, upgrades: Dictionary, original: Dictionary, factor: float) -> bool:
	var r: Dictionary = c.get_round("r%02d" % n)
	r.enemy_scaling = {"hp":float(original.hp)*factor,"atk":float(original.atk)*sqrt(factor)}
	var sim=Sim.new()
	sim.setup(c,str(r.id),11,upgrades)
	var bot=Bot.new(1,11)
	while not sim.ended and sim.t<600:
		bot.act(sim,1.0/30.0)
		sim.step(1.0/30.0)
		sim.events.clear()
		sim.cues.clear()
	return sim.ended and sim.enemy_base.hp<=0

func threshold(c, n: int, upgrades: Dictionary, original: Dictionary) -> float:
	var low := 0.25
	var high := 2.0
	while battle(c,n,upgrades,original,high) and high<64:
		low=high
		high*=2
	for i in 5:
		var mid := (low+high)/2
		if battle(c,n,upgrades,original,mid): low=mid
		else: high=mid
		print("SEARCH round=",n," bracket=",low,"..",high)
	return low

func _run() -> void:
	var c=root.get_node("Content")
	var previous := 0
	for product in c.meta.iap_catalog.products:
		var n := int(product.target_round)
		var original: Dictionary=c.get_round("r%02d"%n).enemy_scaling.duplicate()
		var old_factor := float(c.get_round("r%02d"%n).get("growth_pressure_factor",1.0))
		original.hp = float(original.hp) / old_factor
		original.atk = float(original.atk) / sqrt(old_factor)
		var before := Plan.build_upgrades(c,n,previous)
		var after := Plan.build_upgrades(c,n,previous+int(product.gold))
		var free_threshold:=threshold(c,n,before.upgrades,original)
		var paid_threshold:=threshold(c,n,after.upgrades,original)
		var factor:=sqrt(free_threshold*paid_threshold)
		var entry={"round":n,"factor":snappedf(factor,0.0001),"before_threshold":free_threshold,"after_threshold":paid_threshold,"before_gold":previous,"after_gold":previous+int(product.gold),"before_levels":before.upgrades,"after_levels":after.upgrades}
		results.append(entry)
		print("CALIBRATION ",JSON.stringify(entry))
		c.get_round("r%02d"%n).enemy_scaling=original
		previous+=int(product.gold)
	var f=FileAccess.open("res://build/campaign100/calibration.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"note":"Training: casual bot seed11, 30Hz, first+3star budget, before vs after current pack. Independent validation required.","rows":results},"  "))
	f.close()
	quit()
