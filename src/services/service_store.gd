extends RefCounted
## Persistence boundary for service state (reward ledger, daily caps, entitlements, consent).
## Owner: 06-services. 06 does NOT own the save file (02 does, INTERFACES.md §3).
##
## Integration contract (requested from 02 in coordination/requests/06-services-to-02-engine.md):
##   - `data` is a Dictionary that 02 embeds in the save payload, e.g. Save.progress["services"].
##   - `commit_fn` is a Callable() -> bool that performs ONE atomic save of the whole payload
##     (Save.save_progress). Because the reward/entitlement and the ledger entry live in the same
##     payload, a crash either persists both or neither, which is what makes "reward once" hold.
## Without integration the store is memory-only: state is lost on restart. That is the honest
## default and is reported by `is_persistent()`.

var data: Dictionary
var commit_fn: Callable
## Optional Callable() -> int that increases whenever the game save is written by ANYONE
## (see save_bridge.gd: counts Events.progress_changed, which src/core/save.gd emits after
## every successful save). Lets services detect a grant sink that saved on its own.
var save_epoch_fn: Callable
var commits := 0
var failed_commits := 0

func _init(backing: Dictionary = {}, commit_callable: Callable = Callable(), epoch_callable: Callable = Callable()) -> void:
	data = backing
	commit_fn = commit_callable
	save_epoch_fn = epoch_callable

func is_persistent() -> bool:
	return commit_fn.is_valid()

## Optional Callable() -> bool. False means this store is bound to stale data (e.g. the game
## save was reloaded after binding) and services must not grant through it.
var usable_fn: Callable

func is_usable() -> bool:
	return not usable_fn.is_valid() or bool(usable_fn.call())

## -1 = unknown (no epoch source). Otherwise a counter of completed game saves.
func save_epoch() -> int:
	if save_epoch_fn.is_valid():
		return int(save_epoch_fn.call())
	return external_epoch

## Connected by save_bridge.gd to Events.progress_changed (emitted after each successful save).
var external_epoch := -1
func on_game_saved(_p: Variant = null) -> void:
	external_epoch = maxi(external_epoch, 0) + 1

func get_value(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)

func set_value(key: String, value: Variant) -> void:
	data[key] = value

## Returns a nested Dictionary stored at key, creating it if absent.
func section(key: String) -> Dictionary:
	var v = data.get(key)
	if not (v is Dictionary):
		v = {}
		data[key] = v
	return v

## Snapshot used to roll back in-memory changes when a commit fails.
func snapshot() -> Dictionary:
	return data.duplicate(true)

func restore(snap: Dictionary) -> void:
	data.clear()
	for k in snap:
		data[k] = snap[k]

func commit() -> bool:
	if not commit_fn.is_valid():
		commits += 1
		return true  # memory-only store: nothing to write
	var ok := bool(commit_fn.call())
	if ok:
		commits += 1
	else:
		failed_commits += 1
	return ok
