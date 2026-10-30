extends RefCounted
## Receipt verification boundary. Owner: 06-services. Spec: SERVICES.md §4.4.
## Result codes via `verified(token, code, info)`:
##   ok                        trusted verifier confirmed a paid, unrefunded purchase
##   invalid_receipt           signature/token rejected -> never grant, never acknowledge
##   revoked                   refunded/voided -> remove entitlement
##   verification_unavailable  no trusted verifier / network / timeout -> do NOT grant; retry later
##
## There is deliberately NO adapter that returns ok for production purchases on this device.
## Real-money verification needs a server holding the Play Developer API service account
## (docs/services/PRODUCTION_REQUIREMENTS.md). That server does not exist yet.

signal verified(token: String, code: String, info: Dictionary)

func kind() -> String:
	return "unavailable"

func verify(_purchase: Dictionary) -> void:
	pass

func poll() -> void:
	pass
