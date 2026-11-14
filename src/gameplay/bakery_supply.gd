extends RefCounted
## Cosmetic flour transport. The sim's continuous income is authoritative;
## neither trip timing nor sack animation grants/withholds any resources.
const FLOUR_SACK := preload("res://assets/art/gpt/flour_sack.png")
const CYCLE := 10.0
const MILL_FROM_BASE := 152.0
const GATE_FROM_BASE := 26.0
const PICKUP_OFFSET := 39.0
const PICKUP_START := 4.0
const PICKUP_END := 4.8
const PICKUP_FPS := 8.0

## Bottom row first, then the gaps above it. Every upper sack rests on two below.
const DEPOT_SLOTS := [
	Vector2(0, 0), Vector2(-11, 0), Vector2(11, 0),
	Vector2(-5, -10), Vector2(5, -10), Vector2(0, -20),
]

static func worker_state(index: int, seconds: float, base: float) -> Dictionary:
	var phase := fposmod(seconds + index * 1.37, CYCLE)
	var pickup := base - MILL_FROM_BASE + PICKUP_OFFSET
	var gate := base - GATE_FROM_BASE
	if phase < PICKUP_START:
		return {"x": lerpf(gate, pickup, phase / PICKUP_START), "carry": false, "left": true, "walk": true}
	if phase < PICKUP_END:
		var elapsed := phase - PICKUP_START
		var turning := elapsed >= 6.0 / PICKUP_FPS
		return {"x": pickup, "carry": false, "left": not turning, "walk": false, "pickup": elapsed, "turning": turning}
	if phase < 8.8:
		return {"x": lerpf(pickup, gate, (phase - PICKUP_END) / (8.8 - PICKUP_END)), "carry": true, "left": false, "walk": true}
	return {"x": gate, "carry": false, "left": true, "walk": false}

static func sack(v: Node2D, pos: Vector2, scale := 1.0) -> void:
	var size := (FLOUR_SACK.get_size() * scale).round()
	var origin := (pos - Vector2(size.x * 0.5, size.y)).round()
	v.draw_texture_rect(FLOUR_SACK, Rect2(origin, size), false)

## The home windmill: a 112x112 sprite standing on the ground at its bottom-centre (from the release-slice atlas).
const MILL_PATH := "res://assets/backgrounds/home_mill.png"
static var _mill: Texture2D = null

static func draw(v: Node2D, sim, atlas, ground: float) -> void:
	var base := float(sim.player_base.x)
	var mill := base - MILL_FROM_BASE
	var t := float(sim.t)
	# Mill yard and the full return path, with wheel ruts and delivery stones.
	v.draw_rect(Rect2(mill - 29, ground - 3, MILL_FROM_BASE + 15, 7), Color("b79767"))
	for row in 2:
		v.draw_rect(Rect2(mill + 6, ground + row * 3, base - 30 - mill, 1), Color("8e795a"))
	# The same original village texture supplies a detailed, readable flour mill.
	# It is shared with the backdrop, so this does not allocate another texture page.
	var texture: Texture2D = v.environment.village_texture if v.environment else null
	var set_texture: Texture2D = v.environment.set_texture if v.environment else null
	if _mill == null and ResourceLoader.exists(MILL_PATH): _mill = load(MILL_PATH)
	if _mill != null:
		# release-slice windmill (docs/art/release_slice): outlined, lit from the upper left like the units
		v.draw_texture(_mill, Vector2(mill - 56, ground - 111))
	elif set_texture:
		# v2 lane set: the windmill is the home landmark, drawn on the same pixel grid as the units.
		var region: Rect2 = v.environment.SET_MILL
		v.draw_texture_rect_region(set_texture, Rect2(mill - 56, ground - 111, region.size.x, region.size.y), region)
	elif texture:
		var ratio := float(texture.get_width()) / 2172.0
		v.draw_texture_rect_region(texture, Rect2(mill-55, ground-96, 110, 96), Rect2(Vector2(0,240)*ratio,Vector2(440,384)*ratio))
	else:
		v.draw_rect(Rect2(mill - 22, ground - 13, 45, 14), Color("665b4a"))
		v.draw_colored_polygon(PackedVector2Array([Vector2(mill-18,ground-12), Vector2(mill-11,ground-66), Vector2(mill+11,ground-66), Vector2(mill+18,ground-12)]), Color("d0c0a0"))
		for dx in [-10, 10]: v.draw_line(Vector2(mill+dx,ground-60), Vector2(mill+dx*1.5,ground-14), Color("765d47"), 3)
		v.draw_rect(Rect2(mill - 15, ground - 42, 30, 4), Color("765d47"))
		v.draw_colored_polygon(PackedVector2Array([Vector2(mill-19,ground-65),Vector2(mill,ground-82),Vector2(mill+19,ground-65)]), Color("8a513d"))
		v.draw_rect(Rect2(mill - 6, ground - 23, 12, 22), Color("40392f"))
		var hub := Vector2(mill, ground - 59)
		var angle := floorf(t * 5.0) / 5.0 * 0.55
		for blade in 4:
			var dir := Vector2.from_angle(angle + blade * PI * 0.5)
			var side := dir.orthogonal()
			var tip := (hub + dir * 32).round()
			v.draw_line(hub, tip, Color("4c4239"), 3)
			v.draw_colored_polygon(PackedVector2Array([(hub+dir*9-side*2).round(),(tip-side*2).round(),(tip+side*7).round(),(hub+dir*11+side*4).round()]), Color("f0dfbd"))
		v.draw_rect(Rect2(hub - Vector2(3,3),Vector2(6,6)),Color("a27c4d"))
	# A fixed reserve set back from the pickup point. Only the pickup animation
	# shows the sack being lifted; no shared ground sprite flashes between workers.
	var worker_count := mini(int(sim.workers), 8)
	var pickup_rec = atlas.anim_rec("worker", "pickup") if atlas else null
	var reserve := Vector2(mill + 25, ground - 2)
	sack(v, reserve + Vector2(-8, 0), 0.8)
	sack(v, reserve, 0.8)
	sack(v, reserve + Vector2(-4, -9), 0.8)
	# The pile sits against the bakery, clear of the worker's unloading stop.
	# The displayed amount follows flour, never the animation phase of a worker.
	var depot := Vector2(base - GATE_FROM_BASE + 20, ground - 2)
	v.draw_rect(Rect2(depot + Vector2(-18, -1), Vector2(36, 4)), Color("694b36"))
	var fill := clampf(float(sim.gold) / maxf(1.0, float(sim.gold_max)), 0.0, 1.0)
	var count := 1 + int(floorf(fill * 5.0 + 0.5))
	for i in count:
		sack(v, depot + DEPOT_SLOTS[i], 0.9)
	for i in worker_count:
		var worker := worker_state(i, t, base)
		var picking := worker.has("pickup")
		var pos := Vector2(roundf(worker.x), roundf(ground + 1 + (0 if picking else (i % 3) * 2)))
		var state := "carry" if worker.carry else ("walk" if worker.walk else "idle")
		var has_carry_sprite := false
		if atlas:
			if picking and pickup_rec != null:
				var turning: bool = worker.turning
				var pose = atlas.anim_rec("worker", "carry") if turning else pickup_rec
				if pose != null:
					var frame := 0 if turning else int(atlas.rec_index(pose, float(worker.pickup)))
					v._blit_rec(pose, frame, pos, worker.left, Color.WHITE)
					continue
			var rec = atlas.anim_rec("worker", state)
			has_carry_sprite = worker.carry and rec != null
			if rec == null: rec = atlas.anim_rec("worker", "walk")
			if rec != null:
				v._blit_rec(rec, atlas.rec_index(rec, t + i * 0.13) if worker.walk else 0, pos, worker.left, Color.WHITE)
		else:
			v.draw_rect(Rect2(pos + Vector2(-3,-13),Vector2(6,13)),Color("d2b383"))
			v.draw_rect(Rect2(pos + Vector2(-4,-20),Vector2(8,7)),Color("f1ce9c"))
			v.draw_rect(Rect2(pos + Vector2(-5,-23),Vector2(10,4)),Color("f5e8d0"))
		if worker.carry and not has_carry_sprite:
			sack(v, pos + Vector2(7, -13), 1.0)
