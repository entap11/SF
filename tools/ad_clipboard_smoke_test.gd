extends SceneTree

class ClipboardManager:
	extends "res://scripts/state/ad_manager.gd"
	var copied_urls: Array[String] = []
	func _copy_ad_url(url: String) -> Dictionary:
		copied_urls.append(url)
		return {"copied": true, "url": url}

class Provider:
	extends RefCounted
	var opens: int = 0
	func open_ad(_record: Dictionary, _event: Dictionary) -> Dictionary:
		opens += 1
		return {"opened": true}

class MatchState:
	extends Node
	var match_phase: int = 1
	func get_state_iid() -> int:
		return 123

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager := ClipboardManager.new()
	root.add_child(manager)
	var provider := Provider.new()
	manager.set_provider(provider)
	var match_state := MatchState.new()
	match_state.name = "OpsState"
	root.add_child(match_state)
	for placement: String in ["handshake", "in_game", "post_match"]:
		manager.mark_filled(placement, placement, {}, {"destination_url": "www.biodynamicusa.com"})
		var result: Dictionary = manager.record_tap(placement)
		check(result.get("copied", false), "all ad placements should copy their link")
		check(result.get("copy", {}).get("url") == "https://www.biodynamicusa.com", "bare domain should copy with HTTPS")
		check(not result.get("open", {}).get("opened", true), "no tap may open a window")
	manager.record_tap("in_game")
	check(manager.saved_match_ads().size() == 1, "repeat taps must not duplicate saved match entries")
	check(provider.opens == 0, "tap path must never invoke provider open")
	var copied_count: int = manager.copied_urls.size()
	manager.mark_filled("missing", "handshake", {}, {})
	check(not manager.record_tap("missing").get("copied", true), "missing link must not report copied")
	manager.mark_filled("unsupported", "handshake", {}, {"destination_url": "file:///tmp/creative"})
	check(not manager.record_tap("unsupported").get("copied", true), "non-web destination must not be copied")
	check(manager.copied_urls.size() == copied_count and provider.opens == 0, "invalid destinations must not touch clipboard or browser")
	check(not manager.record_tap("unfilled").get("ok", true), "unfilled ads must not accept taps")
	manager.free()
	match_state.free()
	if not _failed:
		print("AD_CLIPBOARD_SMOKE: PASS")
	quit(1 if _failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("AD_CLIPBOARD_SMOKE: %s" % message)
