class_name EconomyQuarantineUiPolicy
extends RefCounted

const CRUCIBLE_UNAVAILABLE_TEXT: String = "Crucible is temporarily unavailable during beta testing."
const HONEY_UNAVAILABLE_TEXT: String = "Honey purchases are temporarily unavailable during beta testing."

static func is_economy_quarantined_result(result: Dictionary) -> bool:
	return str(result.get("code", result.get("err", result.get("reason", "")))).strip_edges() == "economy_disabled"

static func honey_purchase_failure_text(result: Dictionary, title: String, price_honey: int, cached_balance: int) -> String:
	if is_economy_quarantined_result(result):
		return HONEY_UNAVAILABLE_TEXT
	return "Not enough Honey for %s (H%d needed, H%d available)." % [
		title,
		price_honey,
		int(result.get("honey_balance", cached_balance))
	]
