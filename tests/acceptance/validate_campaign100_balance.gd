extends SceneTree
const Sim := preload("res://src/gameplay/battle_sim.gd")
const Bot := preload("res://src/gameplay/bot_player.gd")
const Plan := preload("res://tests/acceptance/probe_campaign100_balance.gd")
var rows: Array = []
func _initialize() -> void: _run.call_deferred()

func run_one(c, n: int, paid: int, cohort: String, skill: int, seed_value: int) -> void:
	var plan := Plan.build_upgrades(c,n,paid)
	var sim=Sim.new()
	sim.setup(c,"r%02d"%n,seed_value,plan.upgrades)
	var bot=Bot.new(skill,seed_value)
	while not sim.ended and sim.t<600:
		bot.act(sim,1.0/60.0)
		sim.step(1.0/60.0)
		sim.events.clear()
		sim.cues.clear()
	var row={"round":n,"cohort":cohort,"paid_gold":paid,"skill":skill,"seed":seed_value,"won":sim.ended and sim.enemy_base.hp<=0,"seconds":snappedf(sim.t,0.1),"upgrades":plan.upgrades}
	rows.append(row)
	print("VALIDATE ",JSON.stringify(row))

func _run() -> void:
	var c=root.get_node("Content")
	var prior := 0
	for p in c.meta.iap_catalog.products:
		var n:=int(p.target_round)
		for skill in [1,2]:
			for seed_value in [29,47,83]:
				run_one(c,n,prior,"before_current_pack",skill,seed_value)
				run_one(c,n,prior+int(p.gold),"after_current_pack",skill,seed_value)
		prior+=int(p.gold)
	# Every stage is simulated at the expected paid-route budget, including the relief rounds.
	for n in range(1,101):
		var paid:=0
		for p in c.meta.iap_catalog.products:
			if int(p.target_round)<=n:paid+=int(p.gold)
		run_one(c,n,paid,"campaign_route",2,83)
	var f=FileAccess.open("res://build/campaign100/final-balance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"assumptions":"Independent seeds29/47/83, casual1/competent2; 60Hz, 600s. Cheapest active upgrades; first-clear+3-star rewards, no kill/repeat gold. Stage budgets assume earlier clears, not a longitudinal human playthrough. No human conversion claim.","rows":rows},"  "))
	f.close()
	quit()
