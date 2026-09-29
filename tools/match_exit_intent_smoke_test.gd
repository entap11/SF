extends SceneTree

const Exit = preload("res://scripts/state/match_exit_intent.gd")
var failed := false

class Service:
	extends Node
	var calls := 0
	var response := {"ok": true}
	func leave_session(_session: String, _uid: String) -> Dictionary:
		calls += 1
		return response
	func intent_record_lifecycle(_id: String, event: String, _uid: String, _metadata: Dictionary) -> Dictionary:
		calls += 1
		return {"ok": event == "voluntary_quit"}

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var service := Service.new()
	set_meta("vs_price_usd", 0.5)
	check(bool(Exit.context(self).paid), "fractional dollar stakes are still paid matches")
	remove_meta("vs_price_usd")
	set_meta("vs_ruleset", "CRUCIBLE")
	check(bool(Exit.context(self).crucible), "canonical Crucible ruleset gets stake warning")
	remove_meta("vs_ruleset")
	check(Exit.warning({"paid": true}).contains("stake"), "paid exit discloses stake loss")
	check(Exit.warning({"campaign": true}).contains("won't unlock"), "campaign exit explains no unlock")
	check(bool(Exit.request_leave({"campaign": true}, service, service).ok) and service.calls == 0, "local quit does not call remote settlement")
	check(not bool(Exit.request_leave({"paid": true}, service, service).ok), "missing money authority cannot silently leave")
	check(bool(Exit.request_leave({"live": true, "session_id": "fixture", "player_id": "local"}, service, service).ok) and service.calls == 1, "live exit goes through match service")
	service.response = {"ok": false, "err": "transport_unavailable"}
	check(not bool(Exit.request_leave({"session_id": "fixture", "paid": true}, service, service).ok), "failed paid exit stays in match")
	check(bool(Exit.request_leave({"finished": true, "paid": true}, service, service).ok) and service.calls == 2, "finished match does not forfeit again")
	var panel: Control = preload("res://scripts/ui/match_menu_panel.gd").new()
	panel.set("warning_text", Exit.warning({"paid": true}))
	root.add_child(panel)
	await process_frame
	var exit_signals := [0]
	panel.connect("leave_requested", func(): exit_signals[0] += 1)
	panel.call("_on_leave")
	check(exit_signals[0] == 0, "first Leave only asks for confirmation")
	check((panel.get("_resume") as Button).has_focus(), "confirmation defaults to keeping the match")
	panel.call("_on_leave")
	check(exit_signals[0] == 1, "explicit Yes emits exit intent")
	panel.queue_free()
	service.free()
	print("MATCH_EXIT_INTENT_SMOKE: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
