extends "res://src/services/consent/consent_provider.gd"
## DISABLED consent provider (default in every build). Owner: 06-services.
## Reports unsupported; ConsentFlow then finishes with `unsupported` and changes no choices,
## so ads stay blocked by the unknown-consent default.

func kind() -> String:
	return "disabled"

func is_supported() -> bool:
	return false
