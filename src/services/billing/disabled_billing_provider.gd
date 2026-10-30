extends "res://src/services/billing/billing_provider.gd"
## DISABLED billing adapter (default in every build). Owner: 06-services.
## No product catalog is approved (data/meta.json iap_catalog.enabled=false, products=[]).

func kind() -> String:
	return KIND_DISABLED

func is_supported() -> bool:
	return false
