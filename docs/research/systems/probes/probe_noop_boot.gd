extends SceneTree
## Research probe (10-research-systems): what a plain boot does to user:// when NOTHING else runs.
## It writes nothing itself. It prints where user:// resolves to and what the Save autoload did during its own
## _ready() (load_progress -> R5 content migration). Use it with an isolated APPDATA (see §9.17) to show that any
## Godot run of this project with autoloads can rewrite <user>/save.json at boot.
## Output: "PROBE10_NOOP_BOOT <json>". Exit 0.

func _initialize() -> void:
	_report.call_deferred()

func _report() -> void:
	var save = root.get_node_or_null("Save")
	var content = root.get_node_or_null("Content")
	var out := {"marker": OS.get_environment("PROBE10_MARKER"), "user_data_dir": OS.get_user_data_dir(),
		"appdata_env": OS.get_environment("APPDATA"), "project_name": str(ProjectSettings.get_setting("application/config/name")),
		"autoload_save": save != null}
	if save:
		out["save_path"] = str(save.path)
		out["recovery_source"] = str(save.recovery_source)
		out["migration_log"] = save.get("migration_log")
		out["progress_content_version"] = str(save.progress.get("content_version", ""))
	if content:
		out["data_content_version"] = str(content.get("content_version"))
	print("PROBE10_NOOP_BOOT ", JSON.stringify(out))
	quit(0)
