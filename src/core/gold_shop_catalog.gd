extends RefCounted

## Local shop preview only. No payment provider is called by this catalog.
const PACKS := [1000, 2900, 4800, 9700]

## Set by the upgrade screen's 골드 구매 button: the menu reopens the upgrade screen when the shop is left.
static var return_to_upgrades := false

## On in every build (2026-11-14 user: the shop must be reachable from the lobby and the upgrade screen after a
## round). It still grants gold locally without any payment, so it must be wired to real payments or turned back
## off (ALWAYS_ON = false) before release.
const ALWAYS_ON := true

static func enabled() -> bool:
	return ALWAYS_ON or OS.has_feature("gold_shop_preview") or (OS.is_debug_build() and "--gold-shop-preview" in OS.get_cmdline_user_args())

static func formatted(amount: int) -> String:
	var digits := str(amount)
	var split := digits.length() - 3
	while split > 0:
		digits = digits.insert(split, ",")
		split -= 3
	return digits
