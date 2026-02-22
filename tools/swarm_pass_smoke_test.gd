extends SceneTree

const SwarmPassStateScript = preload("res://scripts/state/swarm_pass_state.gd")
const SwarmPassPanelScene: PackedScene = preload("res://scenes/ui/SwarmPassPanel.tscn")

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://swarm_pass_state.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://swarm_pass_telemetry.json"))

	var manager: Node = SwarmPassStateScript.new()
	manager.name = "SwarmPassState"
	get_root().add_child(manager)
	await process_frame

	var r1: Dictionary = manager.intent_record_nectar_award("match_completed_free", 10, {})
	if not bool(r1.get("ok", false)):
		push_error("SWARMPASS_SMOKE: free nectar award failed")
		quit(1)
		return
	if int(round(float(r1.get("pass_xp_gain", 0.0)))) < 10:
		push_error("SWARMPASS_SMOKE: free multiplier mismatch")
		quit(1)
		return

	var tier_upgrade: Dictionary = manager.intent_purchase_pass_tier("ELITE")
	if not bool(tier_upgrade.get("ok", false)):
		push_error("SWARMPASS_SMOKE: elite purchase intent failed")
		quit(1)
		return

	var r2: Dictionary = manager.intent_record_nectar_award("match_completed_free", 10, {})
	if not bool(r2.get("ok", false)):
		push_error("SWARMPASS_SMOKE: elite nectar award failed")
		quit(1)
		return
	if int(round(float(r2.get("pass_xp_gain", 0.0)))) < 12:
		push_error("SWARMPASS_SMOKE: elite multiplier too low")
		quit(1)
		return

	var store_award: Dictionary = manager.intent_record_store_purchase(4.0, {"sku": "bundle_test"})
	if not bool(store_award.get("ok", false)):
		push_error("SWARMPASS_SMOKE: store kickback failed")
		quit(1)
		return

	var snapshot: Dictionary = manager.get_snapshot()
	if not snapshot.has("guardrail_text"):
		push_error("SWARMPASS_SMOKE: guardrail text missing")
		quit(1)
		return
	if str(snapshot.get("guardrail_text", "")).find("Pass multipliers affect Nectar") == -1:
		push_error("SWARMPASS_SMOKE: guardrail text invalid")
		quit(1)
		return

	var telemetry: Dictionary = manager.get_telemetry_dashboard()
	if typeof(telemetry) != TYPE_DICTIONARY:
		push_error("SWARMPASS_SMOKE: telemetry snapshot invalid")
		quit(1)
		return

	var panel_any: Variant = SwarmPassPanelScene.instantiate()
	if not (panel_any is Control):
		push_error("SWARMPASS_SMOKE: panel instantiate failed")
		quit(1)
		return
	var panel: Control = panel_any as Control
	get_root().add_child(panel)
	await process_frame
	panel.queue_free()

	print("SWARMPASS_SMOKE: PASS")
	quit(0)
