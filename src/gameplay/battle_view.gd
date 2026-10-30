extends Node2D
## Immediate-mode renderer for BattleSim: one CanvasItem, atlas frames when available,
## procedural pixel placeholders otherwise. Owner: 02-engine.

const SimS := preload("res://src/gameplay/battle_sim.gd")

var sim                     # battle_sim.gd instance
var atlas                   # Atlas autoload (may be null in tests)
var ground_y := 290.0
var biome := "meadow"
var cam_x := 320.0
var view_w := 640.0
var show_damage := true
var _order: Array = []
var _font: Font
var _biome_layers: Array = []
var _biome_atlas := ""

const C_PLAYER := Color("4a7fd4")
const C_PLAYER_D := Color("2c4f8c")
const C_ENEMY := Color("c8483f")
const C_ENEMY_D := Color("7d2a25")
const C_SKIN := Color("f1c79a")
const C_HERO := Color("f2c14e")
const C_OUTLINE := Color("1a1c24")

func setup(p_sim, p_atlas, p_ground_y: float, p_biome: String) -> void:
	sim = p_sim
	atlas = p_atlas
	ground_y = p_ground_y
	biome = p_biome
	_font = ThemeDB.fallback_font
	_biome_layers = []
	if atlas and atlas.manifest.get("biomes", {}).has(biome):
		var b: Dictionary = atlas.manifest.biomes[biome]
		_biome_atlas = str(b.get("atlas", ""))
		_biome_layers = b.get("layers", [])

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	_draw_background()
	_draw_base(sim.player_base, 1)
	_draw_base(sim.enemy_base, -1)
	_draw_workers()
	# depth sort: higher lane_y (closer) drawn last
	_order.clear()
	for u in sim.players: _order.append(u)
	for u in sim.enemies: _order.append(u)
	if sim.hero_respawn <= 0.0: _order.append(sim.hero)
	_order.sort_custom(func(a, b): return a.lane_y < b.lane_y)
	for u in _order:
		_draw_unit(u)
	for p in sim.projectiles:
		if p.alive: _draw_projectile(p)
	for f in sim.fxs:
		if f.alive: _draw_fx(f)
	if show_damage:
		for tx in sim.texts:
			if tx.alive: _draw_text(tx)
	if not _biome_layers.is_empty() and atlas:
		_draw_biome_layers(cam_x - view_w * 0.5 - 8.0, view_w + 16.0, true)

# ---------------- background ----------------
func _draw_background() -> void:
	var left := cam_x - view_w * 0.5 - 8.0
	var w := view_w + 16.0
	if not _biome_layers.is_empty() and atlas and _draw_biome_layers(left, w, false):
		return
	var pal := _biome_palette()
	# sky bands
	var bands := 6
	for i in bands:
		var c: Color = pal.sky_top.lerp(pal.sky_bottom, float(i) / (bands - 1))
		draw_rect(Rect2(left, -40.0 + i * 40.0, w, 41.0), c)
	# far hills (parallax 0.3)
	var off := cam_x * 0.7
	var step := 96.0
	var x0 := floorf((left - off) / step) * step + off - step
	var x := x0
	while x < left + w + step:
		var h := 40.0 + fposmod(x * 0.37, 30.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, ground_y - 40), Vector2(x + step * 0.5, ground_y - 40 - h), Vector2(x + step, ground_y - 40)]), pal.hill_far)
		x += step
	# near hills (parallax 0.6)
	off = cam_x * 0.4
	step = 64.0
	x = floorf((left - off) / step) * step + off - step
	while x < left + w + step:
		var h2 := 18.0 + fposmod(x * 0.53, 22.0)
		draw_rect(Rect2(x, ground_y - 30.0 - h2 * 0.5, step * 0.9, 30.0 + h2 * 0.5), pal.hill_near)
		x += step
	# ground
	draw_rect(Rect2(left, ground_y - 12.0, w, 4.0), pal.grass_top)
	draw_rect(Rect2(left, ground_y - 8.0, w, 90.0), pal.ground)
	var gx := floorf(left / 16.0) * 16.0
	while gx < left + w:
		draw_rect(Rect2(gx + fposmod(gx * 0.7, 9.0), ground_y + 10.0 + fposmod(gx * 0.31, 30.0), 2, 2), pal.ground_dot)
		gx += 16.0

func _draw_biome_layers(left: float, w: float, front: bool) -> bool:
	var drew := false
	for layer in _biome_layers:
		if (str(layer.get("z", "")) == "front") != front:
			continue
		var f: Dictionary = atlas.frame(_biome_atlas, str(layer.get("frame", "")))
		if f.is_empty():
			continue
		if not drew and not front and layer.has("clear_color"):
			draw_rect(Rect2(left, -40.0, w, 440.0), Color(str(layer.clear_color)))
		drew = true
		var par := float(layer.get("parallax", 1.0))
		var r: Rect2 = f.rect
		var y: float
		if layer.has("lane_line"):
			y = ground_y - float(layer.lane_line)
		else:
			y = float(layer.get("view_y", ground_y - r.size.y))
		var tile_w := r.size.x
		var off := cam_x * (1.0 - par)
		var x := floorf((left - off) / tile_w) * tile_w + off
		while x < left + w:
			draw_texture_rect_region(f.tex, Rect2(roundf(x), y, tile_w, r.size.y), r)
			x += tile_w
	return drew

func _biome_palette() -> Dictionary:
	match biome:
		"forest", "biome_02":
			return {"sky_top": Color("2b4a5e"), "sky_bottom": Color("8fb8a8"), "hill_far": Color("2f5a46"), "hill_near": Color("244a38"),
				"grass_top": Color("4f8a3a"), "ground": Color("4a3a2a"), "ground_dot": Color("5d4a36")}
		"desert", "biome_03":
			return {"sky_top": Color("e89a5a"), "sky_bottom": Color("f6d7a0"), "hill_far": Color("c9925a"), "hill_near": Color("b47c48"),
				"grass_top": Color("d9b06a"), "ground": Color("b58a52"), "ground_dot": Color("a07846")}
		_:
			return {"sky_top": Color("4f7cc4"), "sky_bottom": Color("b9dcf2"), "hill_far": Color("6aa86a"), "hill_near": Color("4f8f4f"),
				"grass_top": Color("6cbf4a"), "ground": Color("6b4f34"), "ground_dot": Color("7d5d3e")}

# ---------------- bases ----------------
func _draw_base(b: Dictionary, side: int) -> void:
	var x: float = b.x
	var key := "player" if side == 1 else "enemy"
	if atlas:
		var bm: Dictionary = atlas.manifest.get("bases", {}).get(key, {})
		if not bm.is_empty():
			var ratio: float = b.hp / b.hp_max
			var st := "idle" if ratio > 0.5 else ("damaged" if ratio > 0.0 else "ruined")
			var f: Dictionary = {}
			if bm.has("anim_set"):
				f = atlas.anim_frame(str(bm.anim_set), st, sim.t)
				if f.is_empty(): f = atlas.anim_frame(str(bm.anim_set), "idle", sim.t)
			if f.is_empty():
				f = atlas.frame(str(bm.get("atlas", "")), str(bm.get("frame", "")))
			if not f.is_empty():
				var mod := Color(1, 0.6, 0.6) if b.flash > 0.0 else Color.WHITE
				_blit(f, Vector2(x, ground_y), side < 0 and bool(bm.get("flip", false)), mod)
				_hp_bar(Vector2(x, ground_y - f.rect.size.y - 8.0), 44.0, b.hp / b.hp_max, side)
				return
	var main := C_PLAYER if side == 1 else C_ENEMY
	var dark := C_PLAYER_D if side == 1 else C_ENEMY_D
	if b.flash > 0.0:
		main = main.lightened(0.4)
	var bw := 44.0
	var bh := 70.0
	var r := Rect2(x - bw * 0.5, ground_y - bh, bw, bh)
	draw_rect(r.grow(1.0), C_OUTLINE)
	draw_rect(r, Color("8a8f9c"))
	draw_rect(Rect2(r.position.x, r.position.y, bw, 8), Color("6d7280"))
	for i in 4:  # crenellations
		draw_rect(Rect2(r.position.x + i * 12.0, r.position.y - 8.0, 8.0, 8.0), Color("8a8f9c"))
	draw_rect(Rect2(x - 7.0, ground_y - 20.0, 14.0, 20.0), Color("3a2a1e"))
	# banner
	draw_rect(Rect2(x - 1.0, r.position.y - 28.0, 2.0, 20.0), C_OUTLINE)
	draw_rect(Rect2(x + (1.0 if side == 1 else -13.0), r.position.y - 28.0, 12.0, 8.0), main)
	draw_rect(Rect2(x - 12.0, ground_y - 50.0, 24.0, 10.0), dark)
	_hp_bar(Vector2(x, r.position.y - 36.0), 44.0, b.hp / b.hp_max, side)

func _draw_workers() -> void:
	var n := mini(sim.workers, 8)
	var px: float = sim.player_base.x
	# gold mine behind the base
	draw_rect(Rect2(px - 64.0, ground_y - 16.0, 22.0, 16.0), Color("5a4a3a"))
	draw_rect(Rect2(px - 60.0, ground_y - 10.0, 14.0, 10.0), Color("1e1a16"))
	draw_rect(Rect2(px - 58.0, ground_y - 20.0, 4.0, 4.0), Color("f2d16b"))
	for i in n:
		var ph := fposmod(sim.t * 0.35 + i * 0.37, 1.0)
		var going := ph < 0.5
		var k := ph * 2.0 if going else (1.0 - ph) * 2.0
		var wx := lerpf(px - 46.0, px - 18.0, k)
		var wy := ground_y - 1.0 + (i % 3) * 2.0
		var bob := 1.0 if int(sim.t * 8.0 + i) % 2 == 0 else 0.0
		if atlas:
			var wf: Dictionary = atlas.anim_frame("worker", "walk" if going else "carry", sim.t + i * 0.13)
			if not wf.is_empty():
				_blit(wf, Vector2(roundf(wx), roundf(wy)), not going, Color.WHITE)
				continue
		draw_rect(Rect2(wx - 2.0, wy - 8.0 - bob, 4.0, 6.0), Color("8d6e4a"))
		draw_rect(Rect2(wx - 2.0, wy - 11.0 - bob, 4.0, 3.0), C_SKIN)
		if not going:
			draw_rect(Rect2(wx + 2.0, wy - 7.0 - bob, 3.0, 3.0), Color("f2d16b"))

# ---------------- units ----------------
func _anim_name(u) -> String:
	match u.state:
		SimS.S_WALK: return "walk"
		SimS.S_ATTACK: return "attack"
		SimS.S_DYING: return "death"
	return "idle"

func _draw_unit(u) -> void:
	var pos := Vector2(roundf(u.x), roundf(ground_y + u.lane_y))
	var flip: bool = u.side < 0
	if u.is_hero:
		flip = sim.hero_dir < 0
	var mod := Color.WHITE
	if u.flash > 0.0: mod = Color(1.0, 0.55, 0.55)
	if u.dying: mod.a = clampf(u.dead_t / 0.7, 0.0, 1.0)
	elif u.buff_t > 0.0: mod = mod * Color(1.0, 1.0, 0.8)
	var drawn := false
	if atlas:
		var aset := str(u.def.get("anim_set", u.id))
		var f: Dictionary = atlas.anim_frame(aset, _anim_name(u), u.anim_t)
		if f.is_empty() and u.state == SimS.S_IDLE:
			f = atlas.anim_frame(aset, "walk", 0.0)
		if not f.is_empty():
			_blit(f, pos, flip, mod)
			drawn = true
			if not u.dying:
				_hp_bar(pos + Vector2(0, -f.rect.size.y - 3.0), 12.0 + 4.0 * float(u.def.get("size", 1.0)), u.hp / u.hp_max, u.side)
	if not drawn:
		_draw_placeholder(u, pos, flip, mod)

func _blit(f: Dictionary, pos: Vector2, flip: bool, mod: Color) -> void:
	var r: Rect2 = f.rect
	var pv: Vector2 = f.pivot
	if flip:
		draw_set_transform(pos, 0.0, Vector2(-1, 1))
		draw_texture_rect_region(f.tex, Rect2(-pv, r.size), r, mod)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(f.tex, Rect2(pos - pv, r.size), r, mod)

func _draw_placeholder(u, pos: Vector2, flip: bool, mod: Color) -> void:
	var s := float(u.def.get("size", 1.0))
	if u.is_hero: s = 1.35
	var dir := -1.0 if flip else 1.0
	var main: Color = C_PLAYER if u.side == 1 else C_ENEMY
	var dark: Color = C_PLAYER_D if u.side == 1 else C_ENEMY_D
	if u.is_hero:
		main = C_HERO
		dark = Color("b0802a")
	var tags: Array = u.def.get("tags", [])
	var kind := str(u.def.get("attack_type", "melee"))
	var bob := 0.0
	var lunge := 0.0
	if u.state == SimS.S_WALK:
		bob = 1.0 if int(u.anim_t * 8.0) % 2 == 0 else 0.0
	elif u.state == SimS.S_ATTACK:
		lunge = 3.0 * dir if u.anim_t < 0.15 else 0.0
	var tilt := 0.0
	if u.dying:
		tilt = minf(1.0, u.anim_t * 3.0)
	var bw := roundf(8.0 * s)
	var bh := roundf(10.0 * s)
	var hw := roundf(6.0 * s)
	var base := pos + Vector2(lunge, -bob)
	if tilt > 0.0:
		draw_set_transform(pos, -dir * tilt * 1.4, Vector2.ONE)
		base = Vector2.ZERO
	var c_main := main * mod
	var c_dark := dark * mod
	var c_out := C_OUTLINE * Color(1, 1, 1, mod.a)
	# legs
	draw_rect(Rect2(base.x - bw * 0.5, base.y - 4.0, 3.0, 4.0), c_dark)
	draw_rect(Rect2(base.x + bw * 0.5 - 3.0, base.y - 4.0 + (bob if u.state == SimS.S_WALK else 0.0), 3.0, 4.0 - bob), c_dark)
	# body
	var body := Rect2(base.x - bw * 0.5, base.y - 4.0 - bh, bw, bh)
	draw_rect(body.grow(1.0), c_out)
	draw_rect(body, c_main)
	if tags.has("tank") or u.id.contains("shield"):
		draw_rect(Rect2(base.x + dir * bw * 0.5 - (0.0 if dir > 0 else 5.0), body.position.y + 1.0, 5.0, bh), Color("c0c4cc") * mod)
	# head
	var head := Rect2(base.x - hw * 0.5, body.position.y - hw, hw, hw)
	draw_rect(head.grow(1.0), c_out)
	draw_rect(head, (C_SKIN if u.side == 1 else Color("8fbf5a")) * mod)
	draw_rect(Rect2(base.x + dir * 1.0, head.position.y + 2.0, 1.0, 1.0), c_out)
	if u.is_hero:
		draw_rect(Rect2(head.position.x - 1.0, head.position.y - 2.0, hw + 2.0, 2.0), Color("f2d16b") * mod)
		draw_rect(Rect2(base.x - dir * (bw * 0.5 + 2.0) - 1.0, body.position.y, 3.0, bh), Color("a83a3a") * mod)
	if u.is_boss or tags.has("boss"):
		draw_rect(Rect2(head.position.x - 2.0, head.position.y - 3.0, 3.0, 3.0), Color("e6e6e6") * mod)
		draw_rect(Rect2(head.end.x - 1.0, head.position.y - 3.0, 3.0, 3.0), Color("e6e6e6") * mod)
	# weapon
	var wy := body.position.y + bh * 0.4
	if kind == "ranged":
		draw_line(Vector2(base.x + dir * (bw * 0.5 + 2.0), wy - 5.0), Vector2(base.x + dir * (bw * 0.5 + 2.0), wy + 5.0), Color("8d6e4a") * mod, 1.0)
	elif kind == "siege":
		draw_rect(Rect2(base.x - bw, base.y - 6.0, bw * 2.0, 4.0), Color("6b4f34") * mod)
		draw_circle(Vector2(base.x - bw * 0.6, base.y - 2.0), 2.5, c_out)
		draw_circle(Vector2(base.x + bw * 0.6, base.y - 2.0), 2.5, c_out)
	else:
		var wl := 7.0 * s + (3.0 if u.state == SimS.S_ATTACK and u.anim_t < 0.15 else 0.0)
		draw_line(Vector2(base.x + dir * bw * 0.5, wy), Vector2(base.x + dir * (bw * 0.5 + wl), wy - 2.0), Color("d8dde6") * mod, 1.0)
	if tilt > 0.0:
		draw_set_transform(Vector2.ZERO)
	if not u.dying:
		_hp_bar(pos + Vector2(0, -bh - hw - 9.0), 10.0 + 4.0 * s, u.hp / u.hp_max, u.side)

func _hp_bar(center: Vector2, w: float, ratio: float, side: int) -> void:
	if ratio >= 0.999 and w < 30.0:
		return   # hide full bars on troops to reduce clutter
	var r := Rect2(roundf(center.x - w * 0.5), roundf(center.y), roundf(w), 2.0)
	draw_rect(r.grow(1.0), C_OUTLINE)
	draw_rect(Rect2(r.position, Vector2(roundf(w * clampf(ratio, 0.0, 1.0)), 2.0)), Color("6fd36f") if side == 1 else Color("e5534b"))

# ---------------- projectiles / fx / text ----------------
func _draw_projectile(p) -> void:
	var k: float = clampf(p.t / p.dur, 0.0, 1.0)
	var y: float = ground_y + p.y - sin(k * PI) * p.arc
	var pos := Vector2(roundf(p.x), roundf(y))
	if atlas:
		var f: Dictionary = atlas.anim_frame(p.kind, "fly", p.t)
		if not f.is_empty():
			_blit(f, pos, p.side < 0, Color.WHITE)
			return
	match p.kind:
		"rock":
			draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), Color("6d6359"))
		"tower_bolt":
			draw_rect(Rect2(pos - Vector2(2, 1), Vector2(5, 2)), Color("f2d16b"))
		"spit":
			draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3, 3)), Color("9ad14b"))
		_:
			var d := float(p.side)
			draw_line(pos - Vector2(4.0 * d, 0), pos + Vector2(2.0 * d, 0), Color("e8e0c8"), 1.0)

func _draw_fx(f) -> void:
	var k := clampf(f.t / f.dur, 0.0, 1.0)
	var pos := Vector2(f.x, ground_y + f.y)
	if atlas:
		var fr: Dictionary = atlas.anim_frame(f.kind, "play", f.t)
		if fr.is_empty(): fr = atlas.anim_frame(f.kind, "loop", f.t)
		if not fr.is_empty():
			_blit(fr, pos, false, Color.WHITE)
			return
	match f.kind:
		"hit_spark":
			var s := 2.0 + k * 3.0
			draw_rect(Rect2(pos - Vector2(s, 0.5), Vector2(s * 2.0, 1.0)), Color(1, 1, 0.7, 1.0 - k))
			draw_rect(Rect2(pos - Vector2(0.5, s), Vector2(1.0, s * 2.0)), Color(1, 1, 0.7, 1.0 - k))
		"explosion":
			draw_circle(pos, maxf(4.0, f.radius) * (0.4 + k * 0.6), Color(1.0, 0.6, 0.2, 0.7 * (1.0 - k)))
		"target_mark":
			draw_arc(Vector2(f.x, ground_y), f.radius, 0, TAU, 24, Color(1, 0.3, 0.2, 0.4 + 0.4 * sin(f.t * 20.0)), 1.0)
		"rally", "skill_rally":
			draw_arc(Vector2(f.x, ground_y - 12.0), 10.0 + k * f.radius * 0.5, 0, TAU, 24, Color(1.0, 0.85, 0.3, 1.0 - k), 2.0)
		"heal":
			draw_arc(Vector2(f.x, ground_y - 12.0), 8.0 + k * f.radius, 0, TAU, 24, Color(0.4, 1.0, 0.5, 1.0 - k), 2.0)
		_:  # shockwave / slam / meteor / barrage
			var r := maxf(8.0, f.radius) * (0.2 + 0.8 * k)
			draw_arc(Vector2(f.x, ground_y), r, PI, TAU, 20, Color(1.0, 0.95, 0.7, 1.0 - k), 3.0)
			draw_rect(Rect2(f.x - r, ground_y - 2.0, r * 2.0, 2.0), Color(0.9, 0.8, 0.6, 0.6 * (1.0 - k)))

func _draw_text(tx) -> void:
	var a := clampf(1.0 - tx.t / 0.8, 0.0, 1.0)
	var c := Color(1, 1, 1, a)
	match tx.kind:
		&"gold": c = Color(1.0, 0.85, 0.3, a)
		&"heal": c = Color(0.4, 1.0, 0.5, a)
		&"crit": c = Color(1.0, 0.4, 0.3, a)
	var p := Vector2(roundf(tx.x - 6.0), roundf(ground_y + tx.y))
	draw_string_outline(_font, p, tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0, 0, 0, a))
	draw_string(_font, p, tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
