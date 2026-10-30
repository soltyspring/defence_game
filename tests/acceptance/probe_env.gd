extends SceneTree
## 07-qa environment probe: confirms autoloads/display used by the acceptance suite.
## Run: tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/acceptance/probe_env.gd

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var names := []
	for n in ["Events", "Perf", "Content", "Atlas", "Save", "App"]:
		names.append("%s=%s" % [n, root.get_node_or_null(n) != null])
	print("[probe] display=", DisplayServer.get_name(), " root=", root.get_visible_rect().size, " autoloads: ", ", ".join(names))
	print("[probe] user_dir=", OS.get_user_data_dir(), " max_fps=", Engine.max_fps)
	quit(0)
