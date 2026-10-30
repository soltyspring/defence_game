extends "res://src/services/ads/ad_provider.gd"
## DISABLED adapter (default in every build). Reports unsupported and never emits callbacks.
## Owner: 06-services. Used until 01 confirms a business model with ads and 04 integrates an SDK.

func kind() -> String:
	return KIND_DISABLED

func is_supported() -> bool:
	return false
