extends RefCounted

## Local shop preview only. No payment provider is called by this catalog.
const PACKS := [1000, 2900, 4800, 9700]

static func enabled() -> bool:
	return OS.has_feature("gold_shop_preview") or (OS.is_debug_build() and "--gold-shop-preview" in OS.get_cmdline_user_args())

static func formatted(amount: int) -> String:
	var digits := str(amount)
	var split := digits.length() - 3
	while split > 0:
		digits = digits.insert(split, ",")
		split -= 3
	return digits
