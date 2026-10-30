extends RefCounted
## Network reachability boundary. Owner: 06-services.
## Godot has no built-in connectivity API on Android. Until 04 ships a native check, the
## default reports UNKNOWN and services let the SDK fail with its own network error, which the
## services map to "offline". Tests subclass this to force ONLINE/OFFLINE.

const ONLINE := "online"
const OFFLINE := "offline"
const UNKNOWN := "unknown"

func status() -> String:
	return UNKNOWN

func is_known_offline() -> bool:
	return status() == OFFLINE
