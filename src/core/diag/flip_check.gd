extends SceneTree
## Render check (needs a real display; run via tools/build/visible_launch.ps1 -Script on the secondary monitor):
## does a negative-width destination rect in draw_texture_rect_region produce exactly the same pixels as
## draw_set_transform(pos, 0, (-1, 1)) + Rect2(-pivot, size)? Tests two placements and prints which matches.
## Owner: 02-engine.

const POS := Vector2(40, 50)
var results := {}

func _initialize() -> void:
	_run.call_deferred()

func _vp(draw_fn: Callable) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 64)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var n := Node2D.new()
	vp.add_child(n)
	root.add_child(vp)
	draw_fn.call(n.get_canvas_item())
	return vp

func _run() -> void:
	var atlas = root.get_node("Atlas")
	atlas.acquire("char_player")
	var f: Dictionary = atlas.anim_frame("hero_captain", "attack", 0.15)
	if f.is_empty():
		print("FLIP_CHECK no frame"); quit(2); return
	var tex: Texture2D = f.tex
	var r: Rect2 = f.rect
	var pv: Vector2 = f.pivot
	var w := r.size.x
	var h := r.size.y
	var rs := RenderingServer
	var ref := _vp(func(ci):
		rs.canvas_item_add_set_transform(ci, Transform2D(0.0, Vector2(-1, 1), 0.0, POS))
		rs.canvas_item_add_texture_rect_region(ci, Rect2(-pv, r.size), tex.get_rid(), r)
		rs.canvas_item_add_set_transform(ci, Transform2D.IDENTITY))
	var cand := {
		"neg_w_at_pos_plus_pivot": Rect2(POS.x + pv.x, POS.y - pv.y, -w, h),
		"neg_w_at_left_edge": Rect2(POS.x - (w - pv.x), POS.y - pv.y, -w, h),
	}
	var vps := {}
	for k in cand:
		var rect: Rect2 = cand[k]
		vps[k] = _vp(func(ci): rs.canvas_item_add_texture_rect_region(ci, rect, tex.get_rid(), r))
	for i in 6:
		await process_frame
	var ref_img := ref.get_texture().get_image()
	var opaque := 0
	for y in ref_img.get_height():
		for x in ref_img.get_width():
			if ref_img.get_pixel(x, y).a > 0.0: opaque += 1
	for k in vps:
		var img: Image = vps[k].get_texture().get_image()
		var diff := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y) != ref_img.get_pixel(x, y): diff += 1
		results[k] = diff
	print("FLIP_CHECK frame=%s size=%s pivot=%s ref_opaque_px=%d diff_px=%s" % [r.position, r.size, pv, opaque, JSON.stringify(results)])
	quit(0)
