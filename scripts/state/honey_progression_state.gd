extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")

signal honey_progression_changed(snapshot: Dictionary)
signal honey_event(event: Dictionary)

const SAVE_PATH: String = "user://honey_progression_state.json"
const SAVE_SCHEMA_VERSION: int = 1
const TENTHS_PER_HONEY: int = 10
const EVENT_DEDUPE_MAX: int = 5000
const RECENT_EVENT_MAX: int = 64
const ASYNC_FREE_TENTHS: int = 2
const PVP_FREE_TENTHS: int = 3
const PVP_FREE_WIN_BONUS_TENTHS: int = 1
const TOURNAMENT_PARTICIPATION_TENTHS: int = 10

const WEEKLY_BONUS_SPECS: Dictionary = {
	"free_pvp_variety": {
		"amount": 50,
		"group": "free_pvp",
		"required": ["1V1", "2V2", "3P_FFA", "4P_FFA"]
	},
	"money_pvp_variety": {
		"amount": 100,
		"group": "money_pvp",
		"required": ["1V1", "2V2", "3P_FFA", "4P_FFA"]
	},
	"free_async_variety": {
		"amount": 50,
		"group": "free_async_modes",
		"required": ["STAGE_RACE", "TIMED_RACE", "MISS_N_OUT"]
	},
	"async_3_map_variety": {
		"amount": 100,
		"group": "async_3_map",
		"required": ["STAGE_RACE_3", "TIMED_RACE_3", "MISS_N_OUT_3"]
	},
	"async_5_map_variety": {
		"amount": 50,
		"group": "async_5_map",
		"required": ["STAGE_RACE_5", "TIMED_RACE_5", "MISS_N_OUT_5"]
	}
}

var _save_schema_version: int = SAVE_SCHEMA_VERSION
var _total_honey_tenths_awarded: int = 0
var _community_honey_tenths: int = 0
var _pending_profile_honey_tenths: int = 0
var _awarded_event_ids: Dictionary = {}
var _awarded_event_order: Array[String] = []
var _weekly_cycle_key: String = ""
var _weekly_progress: Dictionary = {}
var _weekly_claimed: Dictionary = {}
var _recent_events: Array[Dictionary] = []
var _ephemeral_event_counter: int = 0

func _ready() -> void:
	SFLog.allow_tag("HONEY_STATE")
	SFLog.allow_tag("HONEY_EVENT")
	_load_state()
	_roll_week_if_needed()
	_flush_pending_profile_honey("honey_progression_boot")
	_connect_tree_signals()
	_scan_for_sim_runner()
	SFLog.info("HONEY_STATE", {
		"weekly_cycle_key": _weekly_cycle_key,
		"pending_profile_tenths": _pending_profile_honey_tenths,
		"total_honey_tenths_awarded": _total_honey_tenths_awarded
	})
	_emit_changed()

func get_snapshot() -> Dictionary:
	return {
		"schema_version": _save_schema_version,
		"profile_honey_balance": _profile_honey_balance(),
		"pending_profile_honey_tenths": _pending_profile_honey_tenths,
		"pending_profile_honey_progress": float(_pending_profile_honey_tenths) / float(TENTHS_PER_HONEY),
		"total_honey_tenths_awarded": _total_honey_tenths_awarded,
		"community_honey_tenths": _community_honey_tenths,
		"community_honey_whole": int(_community_honey_tenths / TENTHS_PER_HONEY),
		"weekly_cycle_key": _weekly_cycle_key,
		"weekly_progress": _weekly_progress.duplicate(true),
		"weekly_claimed": _weekly_claimed.duplicate(true),
		"recent_events": _recent_events.duplicate(true)
	}

func intent_record_async_completion(mode_id: String, map_count: int, paid_entry: bool, metadata: Dictionary = {}) -> Dictionary:
	var normalized_mode: String = _normalize_async_mode(mode_id)
	if normalized_mode.is_empty():
		return {"ok": false, "reason": "invalid_async_mode", "mode_id": mode_id}
	var resolved_map_count: int = maxi(1, map_count)
	var updates: Array[Dictionary] = []
	if not paid_entry:
		updates.append({"group": "free_async_modes", "entry": normalized_mode})
		if resolved_map_count == 3:
			updates.append({"group": "async_3_map", "entry": "%s_3" % normalized_mode})
		elif resolved_map_count == 5:
			updates.append({"group": "async_5_map", "entry": "%s_5" % normalized_mode})
	var amount: int = ASYNC_FREE_TENTHS * (2 if paid_entry else 1)
	var meta: Dictionary = metadata.duplicate(true)
	meta["mode_id"] = normalized_mode
	meta["map_count"] = resolved_map_count
	meta["paid_entry"] = paid_entry
	return _award_honey_tenths("async_completion", amount, meta, updates)

func intent_record_async_final_placement(mode_id: String, map_count: int, placement: int, paid_entry: bool, contest_scope: String = "", metadata: Dictionary = {}) -> Dictionary:
	var normalized_mode: String = _normalize_async_mode(mode_id)
	if normalized_mode.is_empty():
		return {"ok": false, "reason": "invalid_async_mode", "mode_id": mode_id}
	var amount: int = _placement_bonus_tenths(placement, paid_entry)
	if amount <= 0:
		return {"ok": false, "reason": "placement_not_rewarded", "placement": placement}
	var meta: Dictionary = metadata.duplicate(true)
	meta["mode_id"] = normalized_mode
	meta["map_count"] = maxi(1, map_count)
	meta["placement"] = maxi(1, placement)
	meta["paid_entry"] = paid_entry
	meta["contest_scope"] = contest_scope.strip_edges().to_upper()
	return _award_honey_tenths("async_final_placement", amount, meta, [])

func intent_record_pvp_completion(pvp_mode_id: String, paid_entry: bool, money_tier: int = 0, did_win: bool = false, metadata: Dictionary = {}) -> Dictionary:
	var normalized_mode: String = _normalize_pvp_mode(pvp_mode_id)
	if normalized_mode.is_empty():
		return {"ok": false, "reason": "invalid_pvp_mode", "mode_id": pvp_mode_id}
	var amount: int = 0
	if paid_entry:
		amount = _money_pvp_tenths(money_tier)
		if amount <= 0:
			return {"ok": false, "reason": "invalid_money_tier", "money_tier": money_tier}
	else:
		amount = PVP_FREE_TENTHS + (PVP_FREE_WIN_BONUS_TENTHS if did_win else 0)
	var updates: Array[Dictionary] = [{
		"group": "money_pvp" if paid_entry else "free_pvp",
		"entry": normalized_mode
	}]
	var meta: Dictionary = metadata.duplicate(true)
	meta["mode_id"] = normalized_mode
	meta["paid_entry"] = paid_entry
	meta["money_tier"] = money_tier
	meta["did_win"] = did_win
	return _award_honey_tenths("pvp_completion", amount, meta, updates)

func intent_record_tournament_participation(metadata: Dictionary = {}) -> Dictionary:
	return _award_honey_tenths("tournament_participation", TOURNAMENT_PARTICIPATION_TENTHS, metadata.duplicate(true), [])

func intent_record_tournament_placement(placement: int, metadata: Dictionary = {}) -> Dictionary:
	var amount: int = _placement_bonus_tenths(placement, false)
	if amount <= 0:
		return {"ok": false, "reason": "placement_not_rewarded", "placement": placement}
	var meta: Dictionary = metadata.duplicate(true)
	meta["placement"] = maxi(1, placement)
	return _award_honey_tenths("tournament_placement", amount, meta, [])

func intent_record_contest_winner(scope: String, metadata: Dictionary = {}) -> Dictionary:
	var normalized_scope: String = scope.strip_edges().to_upper()
	var amount: int = _contest_winner_bonus_tenths(normalized_scope)
	if amount <= 0:
		return {"ok": false, "reason": "invalid_scope", "scope": scope}
	var meta: Dictionary = metadata.duplicate(true)
	meta["scope"] = normalized_scope
	return _award_honey_tenths("contest_winner", amount, meta, [])

func debug_reset_state() -> void:
	_total_honey_tenths_awarded = 0
	_community_honey_tenths = 0
	_pending_profile_honey_tenths = 0
	_awarded_event_ids.clear()
	_awarded_event_order.clear()
	_weekly_cycle_key = _current_week_cycle_key()
	_weekly_progress.clear()
	_weekly_claimed.clear()
	_recent_events.clear()
	_save_state()
	_emit_changed()

func _award_honey_tenths(source_name: String, honey_tenths: int, metadata: Dictionary, weekly_updates: Array[Dictionary]) -> Dictionary:
	_roll_week_if_needed()
	var safe_amount: int = maxi(0, honey_tenths)
	if safe_amount <= 0:
		return {"ok": false, "reason": "no_honey"}
	var event_id: String = _event_id_from_metadata(source_name, metadata)
	if _awarded_event_ids.has(event_id):
		return {
			"ok": false,
			"reason": "event_already_awarded",
			"event_id": event_id,
			"profile_honey_balance": _profile_honey_balance()
		}
	_awarded_event_ids[event_id] = true
	_awarded_event_order.append(event_id)
	_prune_awarded_event_dedupe()
	_apply_weekly_updates(weekly_updates)
	var grant_result: Dictionary = _grant_tenths_to_profile(safe_amount, "%s:%s" % [source_name, event_id])
	var claimed_bonuses: Array[Dictionary] = _claim_ready_weekly_bonuses(metadata)
	var event: Dictionary = {
		"type": "honey_awarded",
		"source": source_name,
		"event_id": event_id,
		"honey_tenths_awarded": safe_amount,
		"whole_honey_granted": int(grant_result.get("whole_honey_granted", 0)),
		"profile_honey_balance": _profile_honey_balance(),
		"metadata": metadata.duplicate(true),
		"claimed_weekly_bonuses": claimed_bonuses.duplicate(true)
	}
	_append_recent_event(event)
	_save_state()
	honey_event.emit(event)
	SFLog.info("HONEY_EVENT", event)
	_emit_changed()
	return {
		"ok": true,
		"event_id": event_id,
		"honey_tenths_awarded": safe_amount,
		"whole_honey_granted": int(grant_result.get("whole_honey_granted", 0)),
		"profile_honey_balance": _profile_honey_balance(),
		"claimed_weekly_bonuses": claimed_bonuses.duplicate(true)
	}

func _grant_tenths_to_profile(honey_tenths: int, reason: String) -> Dictionary:
	var safe_amount: int = maxi(0, honey_tenths)
	if safe_amount <= 0:
		return {"whole_honey_granted": 0}
	_total_honey_tenths_awarded += safe_amount
	_community_honey_tenths += safe_amount
	_pending_profile_honey_tenths += safe_amount
	return _flush_pending_profile_honey(reason)

func _flush_pending_profile_honey(reason: String) -> Dictionary:
	var whole_honey_ready: int = int(_pending_profile_honey_tenths / TENTHS_PER_HONEY)
	if whole_honey_ready <= 0:
		return {"whole_honey_granted": 0}
	var profile_manager: Node = _profile_manager()
	if profile_manager == null or not profile_manager.has_method("add_honey"):
		return {"whole_honey_granted": 0}
	var result_any: Variant = profile_manager.call("add_honey", whole_honey_ready, reason)
	if typeof(result_any) != TYPE_DICTIONARY:
		return {"whole_honey_granted": 0}
	var result: Dictionary = result_any as Dictionary
	if not bool(result.get("ok", false)):
		return {"whole_honey_granted": 0}
	_pending_profile_honey_tenths = _pending_profile_honey_tenths % TENTHS_PER_HONEY
	return {
		"whole_honey_granted": whole_honey_ready,
		"profile_honey_balance": int(result.get("honey_balance", _profile_honey_balance()))
	}

func _apply_weekly_updates(weekly_updates: Array[Dictionary]) -> void:
	for update_any in weekly_updates:
		if typeof(update_any) != TYPE_DICTIONARY:
			continue
		var update: Dictionary = update_any as Dictionary
		var group_id: String = str(update.get("group", "")).strip_edges()
		var entry_id: String = str(update.get("entry", "")).strip_edges().to_upper()
		if group_id.is_empty() or entry_id.is_empty():
			continue
		var group_progress: Dictionary = _weekly_progress.get(group_id, {})
		group_progress[entry_id] = true
		_weekly_progress[group_id] = group_progress

func _claim_ready_weekly_bonuses(metadata: Dictionary) -> Array[Dictionary]:
	var claimed: Array[Dictionary] = []
	for bonus_id_any in WEEKLY_BONUS_SPECS.keys():
		var bonus_id: String = str(bonus_id_any)
		if bool(_weekly_claimed.get(bonus_id, false)):
			continue
		var spec: Dictionary = WEEKLY_BONUS_SPECS.get(bonus_id, {})
		if not _weekly_bonus_ready(spec):
			continue
		_weekly_claimed[bonus_id] = true
		var amount: int = maxi(0, int(spec.get("amount", 0)))
		var grant_result: Dictionary = _grant_tenths_to_profile(amount, "weekly_bonus:%s:%s" % [_weekly_cycle_key, bonus_id])
		var event: Dictionary = {
			"type": "weekly_honey_bonus_awarded",
			"bonus_id": bonus_id,
			"weekly_cycle_key": _weekly_cycle_key,
			"honey_tenths_awarded": amount,
			"whole_honey_granted": int(grant_result.get("whole_honey_granted", 0)),
			"profile_honey_balance": _profile_honey_balance(),
			"metadata": metadata.duplicate(true)
		}
		_append_recent_event(event)
		honey_event.emit(event)
		SFLog.info("HONEY_EVENT", event)
		claimed.append(event)
	return claimed

func _weekly_bonus_ready(spec: Dictionary) -> bool:
	var group_id: String = str(spec.get("group", "")).strip_edges()
	if group_id.is_empty():
		return false
	var progress: Dictionary = _weekly_progress.get(group_id, {})
	var required_any: Variant = spec.get("required", [])
	if typeof(required_any) != TYPE_ARRAY:
		return false
	for required_id_any in required_any as Array:
		var required_id: String = str(required_id_any).strip_edges().to_upper()
		if required_id.is_empty():
			continue
		if not bool(progress.get(required_id, false)):
			return false
	return true

func _placement_bonus_tenths(placement: int, paid_entry: bool) -> int:
	var base: int = 0
	match maxi(1, placement):
		1:
			base = 50
		2:
			base = 20
		3:
			base = 10
		_:
			base = 0
	return base * (2 if paid_entry else 1)

func _money_pvp_tenths(money_tier: int) -> int:
	match money_tier:
		1:
			return 5
		2:
			return 10
		3:
			return 15
		_:
			return 0

func _contest_winner_bonus_tenths(scope: String) -> int:
	match scope:
		"DAILY":
			return 50
		"WEEKLY":
			return 100
		"MONTHLY":
			return 150
		_:
			return 0

func _event_id_from_metadata(source_name: String, metadata: Dictionary) -> String:
	var explicit_id: String = str(metadata.get("event_id", "")).strip_edges()
	if not explicit_id.is_empty():
		return explicit_id
	_ephemeral_event_counter += 1
	return "%s:auto:%d:%d" % [source_name, int(round(Time.get_unix_time_from_system() * 1000.0)), _ephemeral_event_counter]

func _normalize_async_mode(mode_id: String) -> String:
	var clean: String = mode_id.strip_edges().to_upper()
	match clean:
		"STAGE_RACE", "TIMED_RACE", "MISS_N_OUT":
			return clean
		_:
			return ""

func _normalize_pvp_mode(mode_id: String) -> String:
	var clean: String = mode_id.strip_edges().to_upper()
	match clean:
		"1V1", "2V2":
			return clean
		"3P FFA", "3P_FFA":
			return "3P_FFA"
		"4P FFA", "4P_FFA":
			return "4P_FFA"
		_:
			return ""

func _current_week_cycle_key() -> String:
	return "wk_%d" % int(floor(Time.get_unix_time_from_system() / 604800.0))

func _roll_week_if_needed() -> void:
	var current_key: String = _current_week_cycle_key()
	if current_key == _weekly_cycle_key:
		return
	_weekly_cycle_key = current_key
	_weekly_progress = {}
	_weekly_claimed = {}
	_save_state()

func _append_recent_event(event: Dictionary) -> void:
	_recent_events.append(event.duplicate(true))
	while _recent_events.size() > RECENT_EVENT_MAX:
		_recent_events.remove_at(0)

func _prune_awarded_event_dedupe() -> void:
	while _awarded_event_order.size() > EVENT_DEDUPE_MAX:
		var removed_id: String = _awarded_event_order[0]
		_awarded_event_order.remove_at(0)
		_awarded_event_ids.erase(removed_id)

func _profile_manager() -> Node:
	return get_node_or_null("/root/ProfileManager")

func _profile_honey_balance() -> int:
	var profile_manager: Node = _profile_manager()
	if profile_manager != null and profile_manager.has_method("get_honey_balance"):
		return maxi(0, int(profile_manager.call("get_honey_balance")))
	return 0

func _connect_tree_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var node_added_cb: Callable = Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(node_added_cb):
		tree.node_added.connect(node_added_cb)

func _scan_for_sim_runner() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Node = tree.get_root()
	if root == null:
		return
	var runner: Node = root.find_child("SimRunner", true, false)
	if runner != null:
		_connect_sim_runner(runner)

func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	if node.name != "SimRunner" and not node.has_signal("match_ended"):
		return
	_connect_sim_runner(node)

func _connect_sim_runner(node: Node) -> void:
	if node == null or not node.has_signal("match_ended"):
		return
	var callback: Callable = Callable(self, "_on_runtime_match_ended")
	if not node.is_connected("match_ended", callback):
		node.connect("match_ended", callback)

func _on_runtime_match_ended(winner_id: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or not tree.has_meta("vs_mode"):
		return
	var mode_id: String = str(tree.get_meta("vs_mode", "")).strip_edges()
	if mode_id.is_empty():
		return
	var metadata: Dictionary = {
		"event_id": _runtime_event_id(tree, mode_id, reason),
		"winner_id": winner_id,
		"reason": reason,
		"contest_id": str(tree.get_meta("contest_id", "")).strip_edges(),
		"contest_scope": str(tree.get_meta("contest_scope", "")).strip_edges().to_upper(),
		"entry_usd": maxi(0, int(tree.get_meta("vs_price_usd", 0)))
	}
	var is_sync_pvp: bool = bool(tree.get_meta("vs_sync_start", false))
	var free_roll: bool = bool(tree.get_meta("vs_free_roll", false))
	if is_sync_pvp:
		var local_owner_id: int = _resolve_local_pvp_owner_id(tree)
		if local_owner_id <= 0:
			return
		var money_tier: int = 0 if free_roll else _money_tier_from_entry_usd(int(metadata.get("entry_usd", 0)))
		intent_record_pvp_completion(
			mode_id,
			not free_roll,
			money_tier,
			winner_id > 0 and winner_id == local_owner_id,
			metadata
		)
		return
	var normalized_mode: String = _normalize_async_mode(mode_id)
	if normalized_mode.is_empty():
		return
	if normalized_mode == "STAGE_RACE" and not _is_final_stage_round(tree):
		return
	intent_record_async_completion(
		normalized_mode,
		_resolve_async_map_count(tree),
		not free_roll,
		metadata
	)

func _runtime_event_id(tree: SceneTree, mode_id: String, reason: String) -> String:
	var nonce_key: String = "honey_runtime_nonce"
	var nonce_scene_key: String = "honey_runtime_nonce_scene_id"
	var nonce: String = str(tree.get_meta(nonce_key, "")).strip_edges()
	var scene_id: int = 0
	if tree.current_scene != null:
		scene_id = int(tree.current_scene.get_instance_id())
	var nonce_scene_id: int = int(tree.get_meta(nonce_scene_key, -1))
	if nonce.is_empty() or nonce_scene_id != scene_id:
		nonce = "h_%d_%d" % [int(round(Time.get_unix_time_from_system() * 1000.0)), scene_id]
		tree.set_meta(nonce_key, nonce)
		tree.set_meta(nonce_scene_key, scene_id)
	var round_index: int = maxi(0, int(tree.get_meta("vs_stage_current_index", 0)))
	return "%s:%s:%s:%d" % [nonce, mode_id.strip_edges().to_upper(), reason.strip_edges().to_lower(), round_index]

func _resolve_local_pvp_owner_id(tree: SceneTree) -> int:
	var runtime: Node = get_node_or_null("/root/VsPvpRuntime")
	if runtime != null and runtime.has_method("is_active") and bool(runtime.call("is_active")):
		if runtime.has_method("get_local_seat"):
			return clampi(int(runtime.call("get_local_seat")), 1, 4)
	var local_uid: String = ""
	var local_profile_any: Variant = tree.get_meta("vs_local_profile", {})
	if typeof(local_profile_any) == TYPE_DICTIONARY:
		local_uid = str((local_profile_any as Dictionary).get("uid", "")).strip_edges()
	if local_uid.is_empty():
		var profile_manager: Node = _profile_manager()
		if profile_manager != null and profile_manager.has_method("get_user_id"):
			local_uid = str(profile_manager.call("get_user_id")).strip_edges()
	var roster_any: Variant = tree.get_meta("vs_assigned_players", [])
	if typeof(roster_any) == TYPE_ARRAY:
		for entry_any in roster_any as Array:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			if str(entry.get("uid", "")).strip_edges() != local_uid:
				continue
			return clampi(int(entry.get("seat", 0)), 1, 4)
	var role: String = str(tree.get_meta("vs_handshake_role", "host")).strip_edges().to_lower()
	return 2 if role == "guest" else 1

func _resolve_async_map_count(tree: SceneTree) -> int:
	var stage_paths_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_paths_any) == TYPE_ARRAY:
		var stage_paths: Array = stage_paths_any as Array
		if not stage_paths.is_empty():
			return maxi(1, stage_paths.size())
	var map_ids_any: Variant = tree.get_meta("map_ids", [])
	if typeof(map_ids_any) == TYPE_ARRAY:
		var map_ids: Array = map_ids_any as Array
		if not map_ids.is_empty():
			return maxi(1, map_ids.size())
	return 1

func _is_final_stage_round(tree: SceneTree) -> bool:
	var stage_paths_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_paths_any) != TYPE_ARRAY:
		return true
	var stage_paths: Array = stage_paths_any as Array
	if stage_paths.size() <= 1:
		return true
	var current_index: int = clampi(int(tree.get_meta("vs_stage_current_index", 0)), 0, stage_paths.size() - 1)
	return current_index + 1 >= stage_paths.size()

func _money_tier_from_entry_usd(entry_usd: int) -> int:
	var safe_usd: int = maxi(0, entry_usd)
	if safe_usd <= 3:
		return 1
	if safe_usd <= 10:
		return 2
	return 3

func _load_state() -> void:
	_total_honey_tenths_awarded = 0
	_community_honey_tenths = 0
	_pending_profile_honey_tenths = 0
	_awarded_event_ids.clear()
	_awarded_event_order.clear()
	_weekly_cycle_key = ""
	_weekly_progress.clear()
	_weekly_claimed.clear()
	_recent_events.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return
	if typeof(parser.data) != TYPE_DICTIONARY:
		return
	var raw: Dictionary = parser.data as Dictionary
	_save_schema_version = maxi(1, int(raw.get("schema_version", SAVE_SCHEMA_VERSION)))
	_total_honey_tenths_awarded = maxi(0, int(raw.get("total_honey_tenths_awarded", 0)))
	_community_honey_tenths = maxi(0, int(raw.get("community_honey_tenths", _total_honey_tenths_awarded)))
	_pending_profile_honey_tenths = maxi(0, int(raw.get("pending_profile_honey_tenths", 0)))
	_weekly_cycle_key = str(raw.get("weekly_cycle_key", "")).strip_edges()
	var awarded_ids_any: Variant = raw.get("awarded_event_ids", {})
	if typeof(awarded_ids_any) == TYPE_DICTIONARY:
		_awarded_event_ids = (awarded_ids_any as Dictionary).duplicate(true)
	var awarded_order_any: Variant = raw.get("awarded_event_order", [])
	if typeof(awarded_order_any) == TYPE_ARRAY:
		for event_id_any in awarded_order_any as Array:
			var event_id: String = str(event_id_any).strip_edges()
			if event_id.is_empty():
				continue
			_awarded_event_order.append(event_id)
	var weekly_progress_any: Variant = raw.get("weekly_progress", {})
	if typeof(weekly_progress_any) == TYPE_DICTIONARY:
		_weekly_progress = (weekly_progress_any as Dictionary).duplicate(true)
	var weekly_claimed_any: Variant = raw.get("weekly_claimed", {})
	if typeof(weekly_claimed_any) == TYPE_DICTIONARY:
		_weekly_claimed = (weekly_claimed_any as Dictionary).duplicate(true)
	var recent_events_any: Variant = raw.get("recent_events", [])
	if typeof(recent_events_any) == TYPE_ARRAY:
		for event_any in recent_events_any as Array:
			if typeof(event_any) != TYPE_DICTIONARY:
				continue
			_recent_events.append((event_any as Dictionary).duplicate(true))

func _save_state() -> void:
	var payload: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"total_honey_tenths_awarded": _total_honey_tenths_awarded,
		"community_honey_tenths": _community_honey_tenths,
		"pending_profile_honey_tenths": _pending_profile_honey_tenths,
		"awarded_event_ids": _awarded_event_ids.duplicate(true),
		"awarded_event_order": _awarded_event_order.duplicate(),
		"weekly_cycle_key": _weekly_cycle_key,
		"weekly_progress": _weekly_progress.duplicate(true),
		"weekly_claimed": _weekly_claimed.duplicate(true),
		"recent_events": _recent_events.duplicate(true)
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))

func _emit_changed() -> void:
	honey_progression_changed.emit(get_snapshot())
