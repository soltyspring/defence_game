extends Node
## Entry point (run/main_scene). Hands World + UI layer to the App router. Owner: 02-engine.

func _ready() -> void:
	App.boot(self, $World, $UI)
