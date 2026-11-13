extends SceneTree
## Sequential route: carry actual rewards and purchases forward, never assume a 3-star win.
const Sim := preload("res://src/gameplay/battle_sim.gd")
const Bot := preload("res://src/gameplay/bot_player.gd")
const Plan := preload("res://tests/acceptance/probe_campaign100_balance.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var c=root.get_node("Content")
	var wallet:=0
	var upgrades: Dictionary={}
	var rows: Array=[]
	var cleared:=0
	var spent_krw:=0
	for n in range(1,101):
		for p in c.meta.iap_catalog.products:
			if int(p.target_round)==n:
				wallet+=int(p.gold)
				spent_krw+=int(p.price_krw)
		var plan:=Plan.spend(c,n,wallet,upgrades)
		wallet=int(plan.remaining)
		upgrades=plan.upgrades
		var sim=Sim.new()
		sim.setup(c,"r%02d"%n,83,upgrades)
		var bot=Bot.new(2,83)
		while not sim.ended and sim.t<600:
			bot.act(sim,1.0/60.0)
			sim.step(1.0/60.0)
			sim.events.clear()
			sim.cues.clear()
		var result: Dictionary=sim.result()
		var won: bool=sim.ended and sim.won
		var reward: Dictionary=sim.round_def.reward
		var payout:=int(result.coins)
		if won:
			payout+=int(reward.first_clear_coins)
			if int(result.stars)==3:payout+=int(reward.get("three_star_bonus_coins",0))
		wallet+=payout
		var row={"round":n,"won":won,"stars":result.stars,"seconds":snappedf(sim.t,0.1),"payout":payout,"wallet_after":wallet,"upgrades":upgrades.duplicate(),"paid_krw":spent_krw}
		rows.append(row)
		print("JOURNEY ",JSON.stringify(row))
		if not won:break
		cleared=n
	var f=FileAccess.open("res://build/campaign100/journey.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"assumptions":"Continuous competent bot, seed83, 60Hz, 600s cap; actual kill/first-clear/three-star payouts. Fixed one-time packs at gates. No retries, grind or refunds. Five original types.","cleared":cleared,"paid_krw":spent_krw,"rows":rows},"  "))
	f.close()
	print("[journey] cleared=",cleared," paid_krw=",spent_krw)
	quit(0 if cleared==100 else 1)
