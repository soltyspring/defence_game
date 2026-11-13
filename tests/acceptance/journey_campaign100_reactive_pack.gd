extends SceneTree
## Continuous 60 Hz campaign using a hypothetical repeatable 3,000 KRW pack.
## Run with: godot --headless --path . -s tests/acceptance/journey_campaign100_reactive_pack.gd
## Use an isolated user directory for the report. This probe never calls payment or Save.
const Sim := preload("res://src/gameplay/battle_sim.gd")
const Bot := preload("res://src/gameplay/bot_player.gd")
const Plan := preload("res://tests/acceptance/probe_campaign100_balance.gd")
const PRICE := 3000
const SEED := 83
const BOT_SKILL := 2
const DT := 1.0 / 60.0

var wallet := 0
var upgrades: Dictionary = {}
var attempts: Array[Dictionary] = []
var purchased: Array[int] = []
var cleared := 0

func _initialize() -> void:
	_run.call_deferred()

func _attempt(content: Node, n: int, retry: bool) -> bool:
	var start_wallet := wallet
	var old_levels := upgrades.duplicate()
	var plan := Plan.spend(content, n, wallet, upgrades)
	wallet = int(plan.remaining)
	upgrades = plan.upgrades
	var upgrade_cost := start_wallet - wallet
	var levels_bought := 0
	for id in upgrades:
		levels_bought += int(upgrades[id]) - int(old_levels.get(id, 1))
	var sim := Sim.new()
	sim.setup(content, "r%02d" % n, SEED, upgrades)
	var bot := Bot.new(BOT_SKILL, SEED)
	while not sim.ended and sim.t < 600.0:
		bot.act(sim, DT)
		sim.step(DT)
		sim.events.clear()
		sim.cues.clear()
	var result := sim.result()
	var won: bool = sim.ended and sim.won
	var reward: Dictionary = sim.round_def.reward
	var payout := int(result.coins)
	if won:
		payout += int(reward.get("first_clear_coins", reward.get("coins", 0)))
		if int(result.stars) == 3:
			payout += int(reward.get("three_star_bonus_coins", 0))
	wallet += payout
	var row := {
		"round": n, "retry": retry, "won": won, "stars": result.stars,
		"seconds": snappedf(sim.t, 0.1), "payout": payout,
		"player_base_hp_pct": snappedf(100.0 * float(sim.player_base.hp) / float(sim.player_base.hp_max), 0.1),
		"enemy_base_hp_pct": snappedf(100.0 * float(sim.enemy_base.hp) / float(sim.enemy_base.hp_max), 0.1),
		"wallet_before": start_wallet, "wallet_after": wallet,
		"loss_hint": result.hint, "ended": sim.ended,
		"upgrade_gold_spent": upgrade_cost, "levels_bought": levels_bought,
		"upgrades": upgrades.duplicate(), "paid_krw": PRICE * purchased.size()
	}
	attempts.append(row)
	print("ATTEMPT ", JSON.stringify(row))
	return won

func _run() -> void:
	var content := root.get_node("Content")
	var gold := 0
	for product in content.meta.iap_catalog.products:
		if int(product.price_krw) == PRICE:
			gold = int(product.gold)
			break
	if gold <= 0:
		printerr("No 3000 KRW reference pack in the catalog")
		quit(2)
		return
	for n in range(1, 101):
		if not _attempt(content, n, false):
			purchased.append(n)
			wallet += gold
			if not _attempt(content, n, true):
				break
		cleared = n
	var summary := {"cleared": cleared, "purchase_rounds": purchased,
		"pack_gold": gold, "pack_krw": PRICE, "paid_krw": PRICE * purchased.size(),
		"bot_skill": BOT_SKILL, "seed": SEED, "ticks_per_second": 60, "attempts": attempts,
		"policy": "One simulated pack after each first loss; stop if its retry also loses."}
	var out := FileAccess.open("user://campaign100_reactive_pack.json", FileAccess.WRITE)
	if out == null:
		printerr("Cannot write journey report: ", FileAccess.get_open_error())
		quit(2)
		return
	out.store_string(JSON.stringify(summary, "  ") + "\n")
	out.close()
	print("SUMMARY ", JSON.stringify({"cleared": cleared, "purchase_rounds": purchased,
		"pack_gold": gold, "paid_krw": PRICE * purchased.size()}))
	quit()
