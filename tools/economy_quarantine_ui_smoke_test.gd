extends SceneTree

const UiPolicyScript := preload("res://scripts/ui/economy_quarantine_ui_policy.gd")

var _failed: bool = false

func _init() -> void:
	var quarantined: Dictionary = {
		"ok": false,
		"err": "economy_disabled",
		"code": "economy_disabled",
		"honey_balance": 321
	}
	_expect(UiPolicyScript.is_economy_quarantined_result(quarantined), "economy_disabled was not recognized")
	var honey_text: String = UiPolicyScript.honey_purchase_failure_text(quarantined, "Test SKU", 50, 321)
	_expect(honey_text == "Honey purchases are temporarily unavailable during beta testing.", "Honey quarantine text changed: %s" % honey_text)
	_expect(not "Not enough Honey" in honey_text, "Honey quarantine was presented as insufficient balance")
	var insufficient_text: String = UiPolicyScript.honey_purchase_failure_text({"ok": false, "reason": "insufficient_honey", "honey_balance": 12}, "Test SKU", 50, 321)
	_expect("Not enough Honey" in insufficient_text and "H12" in insufficient_text, "real insufficient-balance message regressed")
	var crucible_text: String = UiPolicyScript.CRUCIBLE_UNAVAILABLE_TEXT
	_expect(not "economy_disabled" in crucible_text, "Crucible text exposes a backend code")
	if not _failed:
		print("ECONOMY_QUARANTINE_UI_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("ECONOMY_QUARANTINE_UI_SMOKE: %s" % message)
