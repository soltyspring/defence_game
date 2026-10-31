extends SceneTree
## Prints the Content autoload's content_version and the CR/LF byte counts of the data it hashed (10 AC1 check:
## the same commit archived with core.autocrlf=true and =false must print the same value). Headless, writes nothing.
## Run with a PRIVATE APPDATA (Save boots as an autoload):
##   & docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @('--headless','--path','<proj>','-s','res://src/core/diag/print_content_version.gd')
## Output: "CONTENT_VERSION <json>". Owner: 02-engine.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var c = root.get_node("Content")
	var cr := 0
	var lf := 0
	var files: PackedStringArray = c._json_files("res://data")
	for f in files:
		var b := FileAccess.get_file_as_bytes(f)
		cr += b.count(13)
		lf += b.count(10)
	print("CONTENT_VERSION ", JSON.stringify({"content_version": c.content_version, "files": files.size(), "cr_bytes": cr, "lf_bytes": lf}))
	quit(0)
