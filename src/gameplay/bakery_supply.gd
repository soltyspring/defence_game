extends RefCounted
## Cosmetic flour transport. The sim's continuous income is authoritative;
## neither trip timing nor sack animation grants/withholds any resources.
const Style := preload("res://src/ui/ui_style.gd")
const Text := preload("res://src/ui/ui_text.gd")
const CYCLE := 10.0
const MILL_FROM_BASE := 152.0
const GATE_FROM_BASE := 26.0

static func worker_state(index: int, seconds: float, base: float) -> Dictionary:
	var phase := fposmod(seconds + index * 1.37, CYCLE)
	var mill := base - MILL_FROM_BASE
	var gate := base - GATE_FROM_BASE
	if phase < 4.0:
		return {"x": lerpf(gate, mill, phase / 4.0), "carry": false, "left": true, "walk": true}
	if phase < 4.8:
		return {"x": mill, "carry": false, "left": false, "walk": false}
	if phase < 8.8:
		return {"x": lerpf(mill, gate, (phase - 4.8) / 4.0), "carry": true, "left": false, "walk": true}
	return {"x": gate, "carry": false, "left": true, "walk": false}

static func sack(v: Node2D, pos: Vector2, scale := 1.0) -> void:
	var body := Rect2(pos + Vector2(-6, -13) * scale, Vector2(12, 13) * scale)
	v.draw_rect(body.grow(scale), Color("554337"))
	v.draw_rect(body, Color("e7d8b2"))
	v.draw_rect(Rect2(body.position + Vector2(2, 2) * scale, Vector2(7, 9) * scale), Color("f5e9cb"))
	v.draw_rect(Rect2(pos + Vector2(-4, -15) * scale, Vector2(8, 3) * scale), Color("b8a178"))
	v.draw_rect(Rect2(pos + Vector2(-4, -12) * scale, Vector2(8, 1) * scale), Color("806446"))
	# A wheat stalk stamp, visible on the carried sack as well as the stock pile.
	v.draw_rect(Rect2(pos + Vector2(0, -10) * scale, Vector2(1, 8) * scale), Color("9e743d"))
	for row in 3:
		var y := -5.0 - row * 2.0
		v.draw_rect(Rect2(pos + Vector2(-2, y - 1) * scale, Vector2(2, 1) * scale), Color("9e743d"))
		v.draw_rect(Rect2(pos + Vector2(1, y - 1) * scale, Vector2(2, 1) * scale), Color("9e743d"))

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
	if texture:
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
	# Hopper and a clearly identifiable supply of flour, no mine entrance or coins.
	v.draw_rect(Rect2(mill + 19, ground - 17, 18, 14), Color("806044"))
	sack(v, Vector2(mill + 26, ground - 15), 0.9)
	sack(v, Vector2(mill - 27, ground + 1), 1.0)
	# A delivery pallet beside the bakery. A stylized buffer grows with available flour;
	# it is not a second numeric inventory or a source of income.
	var depot := base - GATE_FROM_BASE + 3
	v.draw_rect(Rect2(depot - 21, ground - 1, 43, 5), Color("694b36"))
	var fill := clampf(float(sim.gold) / maxf(1.0, float(sim.gold_max)), 0.0, 1.0)
	var count := 3 + int(floorf(fill * 6.0))
	for i in count:
		var row: int = i / 3
		var col := i % 3
		sack(v, Vector2(depot - 13 + col * 13 + (6 if row % 2 else 0), ground - row * 11), 0.9)
	for i in mini(int(sim.workers), 8):
		var worker := worker_state(i, t, base)
		var pos := Vector2(roundf(worker.x), roundf(ground + 1 + (i % 3) * 2))
		if atlas:
			var rec = atlas.anim_rec("worker", "carry" if worker.carry else ("walk" if worker.walk else "idle"))
			if rec == null: rec = atlas.anim_rec("worker", "walk")
			if rec != null:
				v._blit_rec(rec, atlas.rec_index(rec, t + i * 0.13) if worker.walk else 0, pos, worker.left, Color.WHITE)
		else:
			v.draw_rect(Rect2(pos + Vector2(-3,-13),Vector2(6,13)),Color("d2b383"))
			v.draw_rect(Rect2(pos + Vector2(-4,-20),Vector2(8,7)),Color("f1ce9c"))
			v.draw_rect(Rect2(pos + Vector2(-5,-23),Vector2(10,4)),Color("f5e8d0"))
		if worker.carry:
			sack(v, pos + Vector2(7, -13), 1.0)
	# Short world labels keep the economy legible without another interactive HUD panel.
	_sign(v, Text.t("world.flour_mill"), Vector2(mill, ground - 98))


static func _sign(v: Node2D, label: String, center: Vector2) -> void:
	var width := Style.text_width(label, 10) + 10.0
	var plate := Rect2(center - Vector2(width * 0.5, 9), Vector2(width, 18))
	v.draw_rect(plate.grow(1), Color("453e32"))
	v.draw_rect(plate, Color("806341"))
	v.draw_rect(Rect2(plate.position + Vector2(2, 2), Vector2(width - 4, 1)), Color("ac8b59"))
	Style.draw_text_centered(v, label, center, 10, Color("fff0ce"))
