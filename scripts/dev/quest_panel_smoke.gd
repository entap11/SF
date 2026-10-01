extends SceneTree

const Warpath = preload("res://scripts/ui/ui_battle_pass_screen.gd")
const QuestPanel = preload("res://scripts/ui/quest_panel.gd")
class FakeBackend extends Node:
	var requests: Array[Dictionary] = []
	var claimed: bool = false
	var fail_claim: bool = true
	var fail_read: bool = false
	func get_quests() -> Dictionary:
		if fail_read:
			return {"ok": false, "err": "offline"}
		return {"ok": true, "enabled": true, "epoch_id": "test", "player_id": "player-a",
			"weekly_bonus": {"eligible": true, "claimed_count": 0, "expected_count": 25},
			"quests": [{"quest_id": "daily_mix", "cadence": "DAILY", "title": "Mixed Modes",
				"cycle_start": "2026-09-29T00:00:00Z", "cycle_end": "2026-09-30T00:00:00Z",
				"ready_to_claim": not claimed, "claimed": claimed,
				"reward": {"honey_centi": 200, "nectar_milli": 40000},
				"objectives": [{"id": "duels", "label": "1v1 games", "progress": 3, "target": 3}]}]}
	func claim_quest(payload: Dictionary) -> Dictionary:
		requests.append(payload.duplicate(true))
		if fail_claim:
			return {"ok": false, "err": "transport_error"}
		claimed = true
		return {"ok": true, "claimed": true}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("SF_ENABLE_QUESTS", "0")
	var hidden_entry := Warpath.new()
	root.add_child(hidden_entry)
	assert(_quest_button(hidden_entry) == null, "Quest entry must default off")
	hidden_entry.queue_free()
	await process_frame
	OS.set_environment("SF_ENABLE_QUESTS", "1")
	var visible_entry := Warpath.new()
	root.add_child(visible_entry)
	var button: Button = _quest_button(visible_entry)
	assert(button != null, "Local debug flag must expose quest entry")
	button.pressed.emit()
	assert(visible_entry.get_node_or_null("QuestPanel") != null)
	visible_entry.queue_free()
	await process_frame
	var backend := FakeBackend.new()
	backend.name = "FakeBackend"
	root.add_child(backend)
	var panel := QuestPanel.new()
	panel.backend_path = NodePath("/root/FakeBackend")
	panel.identity_path = NodePath("/root/NoIdentity")
	root.add_child(panel)
	panel.size = Vector2(540, 800)
	await process_frame
	assert(panel.snapshot.quests.size() == 1)
	var quest: Dictionary = panel.snapshot.quests[0]
	panel.claim_quest(quest)
	assert(not backend.claimed and not panel.snapshot.quests[0].claimed)
	backend.fail_claim = false
	panel.claim_quest(quest)
	assert(backend.requests[0] == backend.requests[1], "Retries must preserve the claim intent")
	assert(backend.requests[1].player_id == "player-a")
	assert(not backend.requests[1].has("reward"))
	assert(panel.snapshot.quests[0].claimed)
	backend.fail_read = true
	panel.refresh_quests()
	assert(panel.snapshot.is_empty(), "Offline snapshots must not leave actionable stale quests")
	panel.claim_quest(quest)
	assert(backend.requests.size() == 2)
	panel.queue_free()
	backend.queue_free()
	await process_frame
	print(JSON.stringify({"ok": true, "smoke": "quest_panel_headless", "stable_claim_retry": true,
		"no_optimistic_rewards": true, "offline_clears_actions": true}))
	quit(0)

func _quest_button(node: Node) -> Button:
	if node is Button and (node as Button).text == "Quests":
		return node as Button
	for child in node.get_children():
		var result: Button = _quest_button(child)
		if result != null:
			return result
	return null
