# Authoritative CPU bot ticking. BotRunner owns cognition; BotCommandGateway
# translates actions and emits them through OpsState only.
class_name BotSystem
extends Node

const BotRunnerScript := preload("res://scripts/bot/bot_runner.gd")
const BaselineBotPolicyScript := preload("res://scripts/bot/baseline_bot_policy.gd")

var state: GameState = null
var policy: RefCounted = BaselineBotPolicyScript.new()
var runner: RefCounted = BotRunnerScript.new()
var last_outcomes: Array[Dictionary] = []
var last_shadow_outcomes: Array[Dictionary] = []

var _ops_state: Object = null
var _shadow_runner: RefCounted = null
var _shadow_active: bool = false


func bind_state(state_ref: GameState, ops_state_override: Object = null) -> void:
	state = state_ref
	runner.set("policy", policy)
	_ops_state = ops_state_override
	if _ops_state == null:
		_ops_state = get_node_or_null("/root/OpsState")
	runner.call("bind_state", state_ref, _ops_state)
	_shadow_runner = null
	_shadow_active = false
	last_shadow_outcomes.clear()


func tick(_dt: float) -> void:
	if runner == null:
		return
	_tick_shadow_mode()
	if runner.get("policy") != policy:
		runner.set("policy", policy)
	last_outcomes = runner.call("step") as Array[Dictionary]
	if (
		_shadow_active
		and (not last_shadow_outcomes.is_empty() or not last_outcomes.is_empty())
		and _ops_state != null
		and _ops_state.has_method("record_bot_shadow_outcomes")
	):
		_ops_state.call("record_bot_shadow_outcomes", last_shadow_outcomes, last_outcomes)


func get_last_outcomes() -> Array[Dictionary]:
	return last_outcomes.duplicate(true)


func get_last_shadow_outcomes() -> Array[Dictionary]:
	return last_shadow_outcomes.duplicate(true)


func export_runtime_state() -> Dictionary:
	if runner == null:
		return {}
	return runner.call("export_runtime_state") as Dictionary


func import_runtime_state(snapshot: Dictionary) -> bool:
	if runner == null:
		return false
	return bool(runner.call("import_runtime_state", snapshot))


func _tick_shadow_mode() -> void:
	var enabled: bool = (
		_ops_state != null
		and _ops_state.has_method("is_bot_adaptive_shadow_enabled")
		and bool(_ops_state.call("is_bot_adaptive_shadow_enabled"))
	)
	if not enabled:
		_shadow_active = false
		last_shadow_outcomes.clear()
		return
	if not _shadow_active or _shadow_runner == null:
		_shadow_runner = BotRunnerScript.new()
		_shadow_runner.set("policy", policy)
		_shadow_runner.set("execution_enabled", false)
		_shadow_runner.set("persist_runtime_state", false)
		_shadow_runner.set("policy_version_override", "adaptive_v3.0")
		_shadow_runner.call("bind_state", state, _ops_state)
		_shadow_active = true
	last_shadow_outcomes = _shadow_runner.call("step") as Array[Dictionary]
