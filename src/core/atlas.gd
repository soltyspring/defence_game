extends Node
## Atlas manifest consumer with refcounted per-page residency. Contract: INTERFACES.md §5. Owner: 02-engine.
## Pages are loaded on acquire() and dropped when the refcount reaches 0 (ui pages stay resident).

const MANIFEST := "res://assets/manifest.json"

var manifest: Dictionary = {}
var pages: Dictionary = {}       # atlas_id -> {"meta":{...}, "frames":{}, "anims":{}, "tex":Texture2D|null, "refs":int}
var anim_sets: Dictionary = {}   # anim_set -> atlas_id
var warnings: PackedStringArray = []
var _last_source := "none"

func _ready() -> void:
	reload_manifest()

func reload_manifest() -> void:
	manifest = {}
	pages.clear()
	anim_sets.clear()
	var m = _read_json(MANIFEST)
	if not (m is Dictionary):
		return
	manifest = m
	for a in m.get("atlases", []):
		if a is Dictionary and a.has("id"):
			pages[str(a.id)] = {"meta": a, "frames": {}, "anims": {}, "tex": null, "refs": 0, "loaded": false, "source": "none"}
	var sets = m.get("anim_sets", {})
	if sets is Dictionary:
		for k in sets:
			anim_sets[str(k)] = str(sets[k])

func has_manifest() -> bool:
	return not pages.is_empty()

## Increase refcount and make the page resident.
func acquire(atlas_id: String) -> bool:
	if not pages.has(atlas_id):
		return false
	var p: Dictionary = pages[atlas_id]
	p.refs += 1
	if not p.loaded:
		_load_page(atlas_id)
	return p.tex != null

func release(atlas_id: String) -> void:
	if not pages.has(atlas_id):
		return
	var p: Dictionary = pages[atlas_id]
	p.refs = maxi(0, p.refs - 1)
	if p.refs == 0 and str(p.meta.get("group", "")) != "ui":
		p.tex = null
		p.loaded = false

## Atlas ids needed by a battle: roster anim sets + fx/base groups + biome page.
func pages_for_battle(anim_set_ids: Array, biome: String) -> PackedStringArray:
	var out := PackedStringArray()
	for s in anim_set_ids:
		var a := str(anim_sets.get(str(s), ""))
		if a != "" and not out.has(a):
			out.append(a)
	for id in pages:
		var g := str(pages[id].meta.get("group", ""))
		var b := str(pages[id].meta.get("biome", ""))
		if (g == "fx" or g == "base") and not out.has(id):
			out.append(id)
		if g == "biome" and (b == biome or id == "biome_" + biome) and not out.has(id):
			out.append(id)
	var bio = manifest.get("biomes", {}).get(biome, {})
	if bio is Dictionary and bio.has("atlas") and not out.has(str(bio.atlas)):
		out.append(str(bio.atlas))
	return out

func _load_page(atlas_id: String) -> void:
	var p: Dictionary = pages[atlas_id]
	p.loaded = true
	var fr = _read_json(str(p.meta.get("frames", "")))
	if fr is Dictionary:
		p.frames = fr.get("frames", {})
		p.anims = fr.get("anims", {})
	var img_path := str(p.meta.get("image", ""))
	if img_path == "" and fr is Dictionary:
		img_path = str(p.meta.get("frames", "")).get_base_dir() + "/" + str(fr.get("image", ""))
	p.tex = _load_texture(img_path)
	p.source = _last_source
	if p.tex == null:
		warnings.append("atlas %s: image %s not loadable" % [atlas_id, img_path])

func _load_texture(path: String) -> Texture2D:
	_last_source = "none"
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			_last_source = "import"
			return t
	# Not imported yet (dev only, never available in exported builds): decode PNG directly.
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			_last_source = "raw_png_dev_fallback"
			push_warning("[Atlas] %s loaded via raw PNG dev fallback (not imported)" % path)
			return ImageTexture.create_from_image(img)
	return null

# ---- lookup API for renderers ----
## Returns {"tex":Texture2D, "rect":Rect2, "pivot":Vector2} or {} if unavailable.
func frame(atlas_id: String, frame_name: String) -> Dictionary:
	var p = pages.get(atlas_id)
	if p == null or p.tex == null:
		return {}
	var f = p.frames.get(frame_name)
	if not (f is Dictionary):
		return {}
	var w := float(f.get("w", 0)); var h := float(f.get("h", 0))
	var pv = f.get("pivot", [w * 0.5, h])
	return {"tex": p.tex, "rect": Rect2(float(f.x), float(f.y), w, h), "pivot": Vector2(float(pv[0]), float(pv[1]))}

## Returns {"atlas":id, "frames":[names], "fps":float, "loop":bool, "hit_frame":int} or {}.
func anim(anim_set: String, anim_name: String) -> Dictionary:
	var a := str(anim_sets.get(anim_set, ""))
	if a == "" or not pages.has(a):
		return {}
	var p: Dictionary = pages[a]
	if p.tex == null:
		return {}
	var set_d = p.anims.get(anim_set)
	if not (set_d is Dictionary):
		return {}
	var d = set_d.get(anim_name)
	if not (d is Dictionary) or d.get("frames", []).is_empty():
		return {}
	return {"atlas": a, "frames": d.frames, "fps": float(d.get("fps", 8)), "loop": bool(d.get("loop", true)), "hit_frame": int(d.get("hit_frame", -1))}

## Frame lookup by elapsed time; returns frame() dictionary or {}.
func anim_frame(anim_set: String, anim_name: String, t: float) -> Dictionary:
	var a := anim(anim_set, anim_name)
	if a.is_empty():
		return {}
	var n: int = a.frames.size()
	var i := int(t * a.fps)
	i = i % n if a.loop else mini(i, n - 1)
	return frame(a.atlas, str(a.frames[i]))

## UI helper (icons). Returns AtlasTexture or null.
func get_frame_texture(atlas_id: String, frame_name: String) -> AtlasTexture:
	if pages.has(atlas_id) and not pages[atlas_id].loaded:
		acquire(atlas_id)
	var f := frame(atlas_id, frame_name)
	if f.is_empty():
		return null
	var at := AtlasTexture.new()
	at.atlas = f.tex
	at.region = f.rect
	at.filter_clip = true
	return at

## Resident GPU bytes estimate (RGBA8, no mipmaps) for budget checks.
func texture_report() -> Dictionary:
	var total := 0
	var resident := []
	for id in pages:
		var t: Texture2D = pages[id].tex
		if t:
			var b := t.get_width() * t.get_height() * 4
			total += b
			resident.append({"id": id, "w": t.get_width(), "h": t.get_height(), "gpu_bytes": b, "refs": pages[id].refs, "source": pages[id].source})
	return {"resident_gpu_bytes": total, "pages": resident}

func _read_json(path: String) -> Variant:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		warnings.append("%s: JSON error %s" % [path, j.get_error_message()])
		return null
	return j.data
