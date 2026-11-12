extends Node
## Development scene: the real R01 battle (App.start_round, the game's sim / camera / HUD / input) with the
## release-slice art connected by slice_adapter.gd.
##   godot --path . res://scenes/art_preview/slice_preview.tscn            (`-- --slice=off` current art, `-- --chars=off` new field + old characters)
## Uses its own save file (user://art_preview/save.json) and a dev-forced round: the player's save is not written.
const Adapter := preload("res://src/art_preview/slice_adapter.gd")

func _ready() -> void:
	_start.call_deferred()

func _start() -> void:
	var app = get_node("/root/App")
	var save = get_node("/root/Save")
	var atlas = get_node("/root/Atlas")
	DirAccess.make_dir_recursive_absolute("user://art_preview")
	save.path = "user://art_preview/save.json"
	save.progress = save.fresh()
	if app.world == null:
		get_tree().root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		for i in 4: await get_tree().process_frame
	var round_id := "r01"
	var on := true
	var chars := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--round="): round_id = a.get_slice("=", 1)
		if a == "--slice=off": on = false
		if a == "--chars=off": chars = false
	app.start_round(round_id, true)
	for i in 6: await get_tree().process_frame
	if on and not Adapter.apply(app, atlas, chars):
		push_warning("[art_preview] slice art could not be applied; showing the current art")
