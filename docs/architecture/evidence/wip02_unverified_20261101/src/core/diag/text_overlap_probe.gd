extends SceneTree
## QA-B012 probe: replays the damage-number layout of battle_view.gd on a real headless battle, frame by frame, and
## counts overlapping number rects with the OLD stagger (10 px step under an 11 px rect, 6 tries, then drawn anyway)
## and the NEW one (BattleView.place_text: TEXT_STEP = rect height, TEXT_MAX_STEPS, skip when no slot).
## Same inputs as 07's capture_crowd: r08, App autoplay seed (combat.deterministic_seed_default + round index),
## competent bot, 60 frames/s, one sim step per frame. No rendering; widths from the bundled Galmuri9 font,
## anchor heights from the Atlas frame data (as battle_view does).
## Run with a PRIVATE APPDATA (Save boots as an autoload), one heavy run at a time:
##   & .\coordination\heavy_run.ps1 -Label '02-text-overlap' -Script { & docs/research/systems/probes/isolated_godot.ps1
##     -GodotArgs @('--headless','--path','.','-s','res://src/core/diag/text_overlap_probe.gd','--','--round=r08','--seconds=185') }
## Output: "TEXT_OVERLAP_PROBE <json>". Owner: 02-engine.

const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const ViewS := preload("res://src/gameplay/battle_view.gd")
const NUM_PX := 10
const OLD_GUARD := 6

func _initialize() -> void:
	_run.call_deferred()   # autoloads (Content, Atlas) finish _ready first

func _run() -> void:
	var rid := "r08"
	var seconds := 185.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--round="): rid = a.get_slice("=", 1)
		if a.begins_with("--seconds="): seconds = float(a.get_slice("=", 1))
	var content = root.get_node("Content")
	var atlas = root.get_node_or_null("Atlas")
	if content.round_order.find(rid) < 0:
		print("TEXT_OVERLAP_PROBE ", JSON.stringify({"error": "unknown round " + rid, "rounds": Array(content.round_order)}))
		quit(1)
		return
	var font: Font = load("res://assets/fonts/Galmuri9.ttf") if ResourceLoader.exists("res://assets/fonts/Galmuri9.ttf") else ThemeDB.fallback_font
	var cur_font: Font = load(ViewS.NUM_FONT_PATH) if ResourceLoader.exists(ViewS.NUM_FONT_PATH) else ThemeDB.fallback_font
	var idx: int = content.round_order.find(rid)
	var seed_v := int(content.config.get("combat", {}).get("deterministic_seed_default", 12345)) + idx
	var ground_y := float(content.config.get("lane", {}).get("ground_y", 290.0))
	var sim = SimS.new()
	sim.setup(content, rid, seed_v, {})
	var bot = BotS.new(2, seed_v)
	var dt := 1.0 / 60.0
	var frames := 0
	var old_pairs := 0
	var new_pairs := 0
	var old_frames_with := 0
	var new_frames_with := 0
	var max_alive := 0
	var max_new_drawn := 0
	var dropped := 0
	var frames_dropping := 0
	var widths := {}
	while sim.t < seconds and not sim.ended and frames < int(seconds * 60.0) + 10:
		bot.act(sim, dt)
		sim.step(dt)
		sim.events.clear()
		sim.cues.clear()
		frames += 1
		var old_placed: Array[Rect2] = []
		var new_placed: Array[Rect2] = []
		var alive := 0
		var drop_here := 0
		for tx in sim.texts:
			if not tx.alive: continue
			alive += 1
			if not widths.has(tx.text):
				widths[tx.text] = [font.get_string_size(tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX).x,
					cur_font.get_string_size(tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ViewS.NUM_PX).x]
			var w: float = widths[tx.text][0]
			var wc: float = widths[tx.text][1]
			var by: float = ground_y + tx.y
			if tx.anchor_set != "" and atlas:
				var rec = atlas.anim_rec(tx.anchor_set, "idle")
				if rec == null: rec = atlas.anim_rec(tx.anchor_set, "walk")
				var h: float = rec.rects[0].size.y if rec != null else 24.0
				by = ground_y - h - 12.0 - tx.rise
			var p := Vector2(roundf(tx.x - w * 0.5), roundf(by))
			var pc := Vector2(roundf(tx.x - wc * 0.5), roundf(by))
			# OLD (before QA-B012: Galmuri9 10 px, 10 px step under an 11 px rect, 6 tries, then drawn anyway)
			var r := Rect2(p.x - 1.0, p.y - NUM_PX, w + 2.0, NUM_PX + 1.0)
			var guard := 0
			while guard < OLD_GUARD and _hits(r, old_placed):
				r.position.y -= NUM_PX
				guard += 1
			old_placed.append(r)
			# CURRENT battle_view (font NUM_FONT_PATH at NUM_PX, place_text)
			var slot: Rect2 = ViewS.place_text(Rect2(pc.x - 1.0, pc.y - ViewS.NUM_PX - 1.0, wc + 2.0, ViewS.TEXT_STEP), new_placed, ViewS.TEXT_STEP, ViewS.TEXT_MAX_STEPS)
			if slot.size == Vector2.ZERO:
				drop_here += 1
			else:
				new_placed.append(slot)
		var op := _pairs(old_placed)
		var np := _pairs(new_placed)
		old_pairs += op
		new_pairs += np
		if op > 0: old_frames_with += 1
		if np > 0: new_frames_with += 1
		dropped += drop_here
		if drop_here > 0: frames_dropping += 1
		max_alive = maxi(max_alive, alive)
		max_new_drawn = maxi(max_new_drawn, new_placed.size())
	var out := {"round": rid, "seed": seed_v, "frames": frames, "sim_t": snappedf(sim.t, 0.01), "ended": sim.ended,
		"max_numbers_alive": max_alive, "text_cap": int(sim.caps.text), "font": ViewS.NUM_FONT_PATH if cur_font != ThemeDB.fallback_font else "fallback", "num_px": ViewS.NUM_PX,
		"old": {"overlap_pairs": old_pairs, "frames_with_overlap": old_frames_with},
		"new": {"overlap_pairs": new_pairs, "frames_with_overlap": new_frames_with, "max_drawn": max_new_drawn,
			"dropped_number_frames": dropped, "frames_with_a_drop": frames_dropping, "step": ViewS.TEXT_STEP, "max_steps": ViewS.TEXT_MAX_STEPS}}
	print("TEXT_OVERLAP_PROBE ", JSON.stringify(out))
	quit(0)

static func _hits(r: Rect2, placed: Array[Rect2]) -> bool:
	for q in placed:
		if q.intersects(r): return true
	return false

static func _pairs(placed: Array[Rect2]) -> int:
	var n := 0
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			if placed[i].intersects(placed[j]): n += 1
	return n
