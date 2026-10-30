extends RefCounted
## Binds service state to 02's Save node WITHOUT changing src/core/save.gd. Owner: 06-services.
## Proposed 02 integration (request S2), after every Save.load_progress():
##     Services.setup({"store": SaveBridge.make_store(Save, Events)})
## What it does:
##  - ensures Save.progress["services"] is a Dictionary (save.gd's _migrate keeps unknown keys);
##  - commit = Save.save_progress() (atomic tmp -> rename, .bak kept, checksum: INTERFACES.md §3);
##  - save epoch = count of Events.progress_changed emissions (save.gd emits it after every
##    successful save), so services can detect a grant sink that saved on its own.
## Tested against the real save.gd script with isolated user:// paths in
## tests/services/test_services_m3.gd. That is NOT evidence that the game calls it: 02 has
## not integrated it.

const Store := preload("res://src/services/service_store.gd")

## Returns a ServiceStore or null if `save` does not look like src/core/save.gd.
static func make_store(save: Object, events: Object = null):
	if save == null or not ("progress" in save) or not save.has_method("save_progress"):
		return null
	if not (save.progress is Dictionary):
		return null
	if not (save.progress.get("services") is Dictionary):
		save.progress["services"] = {}
	var st = Store.new(save.progress["services"], save.save_progress)
	if events != null and events.has_signal("progress_changed"):
		st.external_epoch = 0
		events.progress_changed.connect(st.on_game_saved)
	return st
