extends "res://src/gameplay/battle_view.gd"
## 08-performance test-only subclass of 02's battle_view: identical drawing, plus per-category on/off switches so the draw-call
## probe (perf_drawcall_probe.gd) can attribute RENDER_TOTAL_DRAW_CALLS_IN_FRAME to categories by removing one at a time.
## Never used by the game. Owner: 08-performance.

const CHAR_PAGES := ["char_player", "char_player_adv", "char_enemy", "char_enemy_adv"]
var cats := {"background": true, "bases": true, "units": true, "bars": true, "projectiles": true, "fx": true, "texts": true}
var drawn := {"units": 0, "projectiles": 0, "fx": 0, "texts": 0, "bars": 0}
## Unit sprites only draw textured quads (bars are flushed afterwards, 08 H2), so a new sprite batch starts whenever the atlas page
## changes between consecutive units in draw order. `runs` counts those page runs in the frame's actual order:
##   real   = pages as shipped
##   row    = order re-sorted by (rounded lane_y row, page, lane_y): same pixel row => same depth, so only ties are reordered
##   merge2 = if the 4 character pages were 2 (player side / enemy side), same order
##   merge1 = if the 4 character pages were 1, same order
##   row_merge2 = row order with 2 pages (player side / enemy side)
## The probe compares runs.real with the measured draw-call delta of the units category to check the model.
var runs := {"real": 0, "row": 0, "merge2": 0, "merge1": 0, "row_merge2": 0}
var page_units := {}
var sort_mode := "lane"
var _orig_sort: Callable

func _page(u) -> String:
	return str(atlas.anim_sets.get(u.anim_set, "?")) if atlas else "?"

func _page2(u) -> String:
	var p := _page(u)
	if p == "char_player" or p == "char_player_adv": return "P"
	if p == "char_enemy" or p == "char_enemy_adv": return "E"
	return p

func _page1(u) -> String:
	var p := _page(u)
	return "C" if CHAR_PAGES.has(p) else p

static func _runs(order: Array, mapper: Callable) -> int:
	var n := 0
	var last := "\u0000"
	for u in order:
		var p: String = mapper.call(u)
		if p != last:
			n += 1
			last = p
	return n

func _row_less(a, b) -> bool:
	var ra := roundf(a.lane_y)
	var rb := roundf(b.lane_y)
	if ra != rb: return ra < rb
	var pa := _page(a)
	var pb := _page(b)
	if pa != pb: return pa < pb
	return a.lane_y < b.lane_y

func _page_less(a, b) -> bool:
	var pa := _page(a)
	var pb := _page(b)
	if pa != pb: return pa < pb
	return a.lane_y < b.lane_y

## "lane" = 02's order; "row" = candidate (see runs.row); "page" = experiment only, page first: changes which unit overlaps which
## across rows, so it is NOT a shipping order, it only shows the floor for the current pages.
func set_sort_mode(mode: String) -> void:
	if not _orig_sort.is_valid(): _orig_sort = _by_lane_y
	sort_mode = mode
	if mode == "page": _by_lane_y = _page_less
	elif mode == "row": _by_lane_y = _row_less
	else: _by_lane_y = _orig_sort

func set_page_sort(on: bool) -> void:
	set_sort_mode("page" if on else "lane")

func _draw() -> void:
	for k in drawn: drawn[k] = 0
	unit_us = 0
	unit_quad_px = 0
	unit_bbox_px = 0
	unit_opaque_px = 0
	unit_onscreen_px = 0.0
	unit_onscreen_bbox_px = 0.0
	unit_onscreen_opaque_px = 0.0
	var t0 := Time.get_ticks_usec()
	super()
	draw_us = Time.get_ticks_usec() - t0
	if not analyze_runs: return
	page_units = {}
	for u in _order:
		var p := _page(u)
		page_units[p] = int(page_units.get(p, 0)) + 1
	runs.real = _runs(_order, _page)
	runs.merge2 = _runs(_order, _page2)
	runs.merge1 = _runs(_order, _page1)
	var row := _order.duplicate()
	row.sort_custom(_row_less)
	runs.row = _runs(row, _page)
	runs.row_merge2 = _runs(row, _page2)

func _draw_background() -> void:
	if cats.background: super()

func _draw_biome_layers(left: float, w: float, front: bool) -> bool:
	if not cats.background: return true   # pretend drawn so the procedural fallback is skipped too
	return super(left, w, front)

func _draw_base(b: Dictionary, side: int) -> void:
	if cats.bases: super(b, side)

func _draw_workers() -> void:
	if cats.bases: super()

func _draw_unit(u) -> void:
	if cats.units:
		drawn.units += 1
		_cur_page = _page(u)
		var t0 := Time.get_ticks_usec()
		super(u)
		unit_us += Time.get_ticks_usec() - t0
		_cur_page = ""

## CPU time of the frame's canvas recording (GDScript): whole _draw() and the part spent in _draw_unit (incl. its hp-bar queueing).
## Per-unit timing adds 2 ticks calls per unit (≈ 73 at caps); compare builds with the same instrumentation only.
var draw_us := 0
var unit_us := 0
var unit_quad_px := 0
## Set by the probe: tex rid id -> {Vector4i(x, y, w, h): Vector3i(quad, alpha bbox, opaque px)} for character pages.
var alpha_stats := {}
var unit_bbox_px := 0
var unit_opaque_px := 0
## On-screen parts (world px; multiply by (canvas scale × camera zoom)² for physical screen px).
var unit_onscreen_px := 0.0
var unit_onscreen_bbox_px := 0.0
var unit_onscreen_opaque_px := 0.0
## false = skip the per-frame page-run bookkeeping (a copy + sort of all units) so it does not add to frame time in timing A/Bs.
var analyze_runs := true

## SIMULATED page merge (counts only, WRONG PIXELS): bind every character-unit sprite to one shared page texture ("merge1") or to one
## texture per side ("merge2": player pages -> char_player, enemy pages -> char_enemy), keeping each sprite's own region rect. The GPU
## then sees the texture changes a merged atlas would cause, so RENDER_TOTAL_DRAW_CALLS_IN_FRAME shows what 03 A9 would save without a
## repack. Workers, bases, projectiles and fx keep their real textures (_cur_page is "" for them).
var tex_mode := "real"
var _cur_page := ""

func _sim_tex(real_tex: Texture2D) -> Texture2D:
	if tex_mode == "real" or _cur_page == "" or not CHAR_PAGES.has(_cur_page) or atlas == null: return real_tex
	var target := "char_player"
	if tex_mode == "merge2" and (_cur_page == "char_enemy" or _cur_page == "char_enemy_adv"): target = "char_enemy"
	var p = atlas.pages.get(target)
	if p == null or p.tex == null: return real_tex
	return p.tex

func _blit_rec(rec, i: int, pos: Vector2, flip: bool, mod: Color) -> void:
	if _cur_page != "":
		var rr: Rect2 = rec.rects[i]
		var qa := absf(rr.size.x * rr.size.y)
		unit_quad_px += int(qa)   # destination quad area in world px (scale 1): fill-rate proxy
		# on-screen part only (the GPU rasterises nothing outside the view). A flip draws the region mirrored about pos.x; the
		# canvas keeps x0 and flips the texture, so the covered span is [pos.x - w + pv.x, pos.x + pv.x].
		var pv: Vector2 = rec.pivots[i]
		var x0 := (pos.x - pv.x) if not flip else (pos.x - rr.size.x + pv.x)
		var vis := Rect2(cam_x - view_w * 0.5, view_top, view_w, view_bottom - view_top).intersection(Rect2(x0, pos.y - pv.y, rr.size.x, rr.size.y))
		var frac := vis.get_area() / qa if qa > 0.0 else 0.0
		unit_onscreen_px += vis.get_area()
		if not alpha_stats.is_empty():
			var tab = alpha_stats.get(rec.tex.get_rid().get_id())
			if tab != null:
				var st = tab.get(Vector4i(int(rr.position.x), int(rr.position.y), int(rr.size.x), int(rr.size.y)))
				if st != null:
					unit_bbox_px += st.y
					unit_opaque_px += st.z
					unit_onscreen_bbox_px += st.y * frac
					unit_onscreen_opaque_px += st.z * frac
	if tex_mode == "real" or _cur_page == "":
		super(rec, i, pos, flip, mod)
		return
	var r: Rect2 = rec.rects[i]
	var pv: Vector2 = rec.pivots[i]
	var t := _sim_tex(rec.tex)
	if flip:
		draw_texture_rect_region(t, Rect2(pos.x - (r.size.x - pv.x), pos.y - pv.y, -r.size.x, r.size.y), r, mod)
	else:
		draw_texture_rect_region(t, Rect2(pos - pv, r.size), r, mod)

func _hp_bar(center: Vector2, w: float, ratio: float, side: int) -> void:
	if cats.bars:
		drawn.bars += 1
		super(center, w, ratio, side)

func _draw_projectile(p) -> void:
	if cats.projectiles:
		drawn.projectiles += 1
		super(p)

func _draw_fx(f) -> void:
	if cats.fx:
		drawn.fx += 1
		super(f)

func _draw_text(tx) -> void:
	if cats.texts:
		drawn.texts += 1
		super(tx)
