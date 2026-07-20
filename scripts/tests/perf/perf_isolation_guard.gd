class_name PerfIsolationGuard
extends RefCounted

const DeterministicHash := preload("res://scripts/tests/perf/perf_deterministic_hash.gd")

const PROJECT_SETTING_KEYS: Array[String] = [
	"swarmfront/arena/polish_comparison_mode",
	"swarmfront/arena/premium_polish_enabled",
	"swarmfront/arena/tower_visual_scale"
]
const OPS_SIGNAL_NAMES: Array[StringName] = [
	&"state_changed",
	&"ops_state_changed",
	&"lanes_changed",
	&"lane_intent_changed",
	&"hud_changed"
]
const SHARED_RUNTIME_AUTOLOADS: Array[String] = ["AppLifecycle", "VsHandshake", "VsPvpRuntime"]
const PROTECTED_AUTOLOADS: Array[String] = [
	"ProfileManager",
	"ContestState",
	"RankState",
	"HoneyProgressionState",
	"HiveClanState",
	"BattlePassState",
	"BattlePassRuntimeAwards",
	"AchievementService",
	"CrucibleState",
	"AnalyticsClient",
	"JukeboxRuntime"
]
const PROTECTED_SAVE_PATHS: Array[String] = [
	"user://profile.cfg",
	"user://contest_entries.json",
	"user://contest_leaderboards_v1.json",
	"user://rank_state.json",
	"user://honey_progression_state.json",
	"user://hive_clan_state.json",
	"user://battle_pass_state.json",
	"user://crucible_state.json",
	"user://analytics_queue_v1.jsonl",
	"user://analytics_state_v1.json"
]


static func capture(tree: SceneTree, ops_state: Node) -> Dictionary:
	var snapshot: Dictionary = {
		"project_settings": _capture_project_settings(),
		"audio_buses": _capture_audio_buses(),
		"engine": {
			"time_scale": float(Engine.time_scale),
			"physics_ticks_per_second": int(Engine.physics_ticks_per_second),
			"max_fps": int(Engine.max_fps)
		},
		"rendering_default_clear_color": RenderingServer.get_default_clear_color(),
		"tree_metadata": _capture_tree_metadata(tree),
		"ops_properties": _capture_script_properties(ops_state),
		"ops_rng_states": _capture_rng_states(ops_state),
		"shared_runtime_properties": _capture_autoload_script_states(tree, SHARED_RUNTIME_AUTOLOADS),
		"protected_state": _capture_protected_state(tree),
		"tree_topology": _tree_topology(tree, ops_state)
	}
	snapshot["protected_state_hash"] = DeterministicHash.hash_variant(snapshot.get("protected_state", {}))
	snapshot["before_hash"] = _fingerprint_hash(snapshot)
	return snapshot


static func restore(snapshot: Dictionary, tree: SceneTree, ops_state: Node) -> Dictionary:
	var restore_errors: Array[String] = []
	_restore_project_settings(snapshot.get("project_settings", {}) as Dictionary)
	_restore_audio_buses(snapshot.get("audio_buses", {}) as Dictionary)
	_restore_tree_metadata(tree, snapshot.get("tree_metadata", {}) as Dictionary)
	var engine_state: Dictionary = snapshot.get("engine", {}) as Dictionary
	Engine.time_scale = float(engine_state.get("time_scale", Engine.time_scale))
	Engine.physics_ticks_per_second = int(engine_state.get("physics_ticks_per_second", Engine.physics_ticks_per_second))
	Engine.max_fps = int(engine_state.get("max_fps", Engine.max_fps))
	var clear_color_any: Variant = snapshot.get("rendering_default_clear_color", RenderingServer.get_default_clear_color())
	if clear_color_any is Color:
		RenderingServer.set_default_clear_color(clear_color_any as Color)
	if ops_state == null:
		restore_errors.append("ops_state_missing_during_restore")
	else:
		_restore_script_properties(ops_state, snapshot.get("ops_properties", {}) as Dictionary)
		_restore_rng_states(ops_state, snapshot.get("ops_rng_states", {}) as Dictionary)
	_restore_autoload_script_states(tree, snapshot.get("shared_runtime_properties", {}) as Dictionary)
	var verification: Dictionary = verify(snapshot, tree, ops_state)
	for error_any in restore_errors:
		(verification["mismatches"] as Array).append(str(error_any))
	verification["pass"] = (verification.get("mismatches", []) as Array).is_empty()
	return verification


static func release_fixture_state(snapshot: Dictionary, ops_state: Node) -> Dictionary:
	if ops_state == null:
		return {"released": false, "reason": "ops_state_missing"}
	var original_properties: Dictionary = snapshot.get("ops_properties", {}) as Dictionary
	var original_state: Variant = original_properties.get("state")
	var fixture_state: Variant = ops_state.get("state")
	if fixture_state == null or fixture_state == original_state:
		return {"released": false, "reason": "no_discarded_fixture_state"}
	var unit_system: Variant = fixture_state.get("unit_system") if fixture_state is Object else null
	if unit_system is Object:
		(unit_system as Object).set("_match_telemetry_collector", null)
		(unit_system as Object).set("state", null)
	if fixture_state is Object:
		(fixture_state as Object).set("unit_system", null)
		(fixture_state as Object).set("selection", null)
	ops_state.set("state", null)
	return {
		"released": true,
		"fixture_state_instance_id": int((fixture_state as Object).get_instance_id()) if fixture_state is Object else 0,
		"unit_system_cycle_broken": unit_system is Object
	}


static func verify(snapshot: Dictionary, tree: SceneTree, ops_state: Node) -> Dictionary:
	var after_snapshot: Dictionary = {
		"project_settings": _capture_project_settings(),
		"audio_buses": _capture_audio_buses(),
		"engine": {
			"time_scale": float(Engine.time_scale),
			"physics_ticks_per_second": int(Engine.physics_ticks_per_second),
			"max_fps": int(Engine.max_fps)
		},
		"rendering_default_clear_color": RenderingServer.get_default_clear_color(),
		"tree_metadata": _capture_tree_metadata(tree),
		"ops_properties": _capture_script_properties(ops_state),
		"ops_rng_states": _capture_rng_states(ops_state),
		"shared_runtime_properties": _capture_autoload_script_states(tree, SHARED_RUNTIME_AUTOLOADS),
		"protected_state": _capture_protected_state(tree),
		"tree_topology": _tree_topology(tree, ops_state)
	}
	var before_hash: String = str(snapshot.get("before_hash", _fingerprint_hash(snapshot)))
	var after_hash: String = _fingerprint_hash(after_snapshot)
	var mismatches: Array[String] = []
	if after_hash != before_hash:
		mismatches.append("global_state_fingerprint_mismatch")
	var before_topology: Dictionary = snapshot.get("tree_topology", {}) as Dictionary
	var after_topology: Dictionary = after_snapshot.get("tree_topology", {}) as Dictionary
	if before_topology != after_topology:
		mismatches.append("tree_or_signal_topology_mismatch")
	return {
		"pass": mismatches.is_empty(),
		"before_hash": before_hash,
		"after_hash": after_hash,
		"before_protected_state_hash": str(snapshot.get("protected_state_hash", "")),
		"after_protected_state_hash": DeterministicHash.hash_variant(after_snapshot.get("protected_state", {})),
		"before_protected_state": (snapshot.get("protected_state", {}) as Dictionary).duplicate(true),
		"after_protected_state": (after_snapshot.get("protected_state", {}) as Dictionary).duplicate(true),
		"mismatches": mismatches,
		"before_topology": before_topology.duplicate(true),
		"after_topology": after_topology.duplicate(true)
	}


static func _capture_audio_buses() -> Dictionary:
	var buses: Array = []
	for bus_index in range(AudioServer.get_bus_count()):
		var effects_enabled: Array[bool] = []
		for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
			effects_enabled.append(AudioServer.is_bus_effect_enabled(bus_index, effect_index))
		buses.append({
			"name": AudioServer.get_bus_name(bus_index),
			"volume_db": AudioServer.get_bus_volume_db(bus_index),
			"mute": AudioServer.is_bus_mute(bus_index),
			"solo": AudioServer.is_bus_solo(bus_index),
			"bypass_effects": AudioServer.is_bus_bypassing_effects(bus_index),
			"effects_enabled": effects_enabled
		})
	return {"bus_count": buses.size(), "buses": buses}


static func _restore_audio_buses(snapshot: Dictionary) -> void:
	for bus_any in snapshot.get("buses", []) as Array:
		if typeof(bus_any) != TYPE_DICTIONARY:
			continue
		var bus: Dictionary = bus_any as Dictionary
		var bus_index: int = AudioServer.get_bus_index(str(bus.get("name", "")))
		if bus_index < 0:
			continue
		AudioServer.set_bus_volume_db(bus_index, float(bus.get("volume_db", 0.0)))
		AudioServer.set_bus_mute(bus_index, bool(bus.get("mute", false)))
		AudioServer.set_bus_solo(bus_index, bool(bus.get("solo", false)))
		AudioServer.set_bus_bypass_effects(bus_index, bool(bus.get("bypass_effects", false)))
		var effects_enabled: Array = bus.get("effects_enabled", []) as Array
		for effect_index in range(mini(effects_enabled.size(), AudioServer.get_bus_effect_count(bus_index))):
			AudioServer.set_bus_effect_enabled(bus_index, effect_index, bool(effects_enabled[effect_index]))


static func _capture_tree_metadata(tree: SceneTree) -> Dictionary:
	var out: Dictionary = {}
	if tree == null:
		return out
	for key_any in tree.get_meta_list():
		out[str(key_any)] = _copy_variant(tree.get_meta(str(key_any)))
	return out


static func _restore_tree_metadata(tree: SceneTree, snapshot: Dictionary) -> void:
	if tree == null:
		return
	for key_any in tree.get_meta_list():
		var key: String = str(key_any)
		if not snapshot.has(key):
			tree.remove_meta(key)
	for key_any in snapshot.keys():
		tree.set_meta(str(key_any), _copy_variant(snapshot.get(key_any)))


static func _capture_autoload_script_states(tree: SceneTree, names: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	if tree == null or tree.root == null:
		return out
	for autoload_name in names:
		var node: Node = tree.root.get_node_or_null(autoload_name)
		out[autoload_name] = {
			"present": node != null,
			"properties": _capture_script_properties(node)
		}
	return out


static func _restore_autoload_script_states(tree: SceneTree, snapshot: Dictionary) -> void:
	if tree == null or tree.root == null:
		return
	for autoload_name_any in snapshot.keys():
		var row: Dictionary = snapshot.get(autoload_name_any, {}) as Dictionary
		if not bool(row.get("present", false)):
			continue
		var node: Node = tree.root.get_node_or_null(str(autoload_name_any))
		if node != null:
			_restore_script_properties(node, row.get("properties", {}) as Dictionary)


static func _capture_protected_state(tree: SceneTree) -> Dictionary:
	var autoloads: Dictionary = {}
	if tree != null and tree.root != null:
		for autoload_name in PROTECTED_AUTOLOADS:
			var node: Node = tree.root.get_node_or_null(autoload_name)
			var properties: Dictionary = _capture_script_properties(node)
			autoloads[autoload_name] = {
				"present": node != null,
				"property_count": properties.size(),
				"state_hash": DeterministicHash.hash_variant(properties)
			}
	var files: Dictionary = {}
	for path in PROTECTED_SAVE_PATHS:
		files[path] = _file_fingerprint(path)
	return {"autoloads": autoloads, "save_files": files}


static func _file_fingerprint(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "modified_time": 0, "length": 0, "sha256": ""}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return {
		"exists": true,
		"modified_time": int(FileAccess.get_modified_time(path)),
		"length": int(file.get_length()) if file != null else -1,
		"sha256": FileAccess.get_sha256(path)
	}


static func _capture_project_settings() -> Dictionary:
	var out: Dictionary = {}
	for key in PROJECT_SETTING_KEYS:
		var exists: bool = ProjectSettings.has_setting(key)
		out[key] = {
			"exists": exists,
			"value": _copy_variant(ProjectSettings.get_setting(key)) if exists else null
		}
	return out


static func _restore_project_settings(snapshot: Dictionary) -> void:
	for key in PROJECT_SETTING_KEYS:
		var row: Dictionary = snapshot.get(key, {"exists": false}) as Dictionary
		if bool(row.get("exists", false)):
			ProjectSettings.set_setting(key, _copy_variant(row.get("value")))
		else:
			ProjectSettings.set_setting(key, null)


static func _capture_script_properties(target: Object) -> Dictionary:
	var out: Dictionary = {}
	if target == null:
		return out
	for property_any in target.get_property_list():
		if typeof(property_any) != TYPE_DICTIONARY:
			continue
		var property: Dictionary = property_any as Dictionary
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name: String = str(property.get("name", ""))
		if property_name.is_empty():
			continue
		out[property_name] = _copy_variant(target.get(property_name))
	return out


static func _restore_script_properties(target: Object, snapshot: Dictionary) -> void:
	if target == null:
		return
	for property_name_any in snapshot.keys():
		var property_name: String = str(property_name_any)
		target.set(property_name, _copy_variant(snapshot.get(property_name_any)))


static func _capture_rng_states(target: Object) -> Dictionary:
	var out: Dictionary = {}
	if target == null:
		return out
	for property_any in target.get_property_list():
		if typeof(property_any) != TYPE_DICTIONARY:
			continue
		var property: Dictionary = property_any as Dictionary
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name: String = str(property.get("name", ""))
		var value: Variant = target.get(property_name)
		if value is RandomNumberGenerator:
			var rng: RandomNumberGenerator = value as RandomNumberGenerator
			out[property_name] = {"seed": int(rng.seed), "state": int(rng.state)}
	return out


static func _restore_rng_states(target: Object, snapshot: Dictionary) -> void:
	if target == null:
		return
	for property_name_any in snapshot.keys():
		var rng_any: Variant = target.get(str(property_name_any))
		if not (rng_any is RandomNumberGenerator):
			continue
		var row: Dictionary = snapshot.get(property_name_any, {}) as Dictionary
		var rng: RandomNumberGenerator = rng_any as RandomNumberGenerator
		rng.seed = int(row.get("seed", rng.seed))
		rng.state = int(row.get("state", rng.state))


static func _tree_topology(tree: SceneTree, ops_state: Node) -> Dictionary:
	var root_children: Array[int] = []
	var root_child_rows: Array[String] = []
	var arena_nodes: Array[int] = []
	if tree != null and tree.root != null:
		for child in tree.root.get_children():
			var child_node: Node = child as Node
			root_children.append(int(child_node.get_instance_id()))
			var script_path: String = ""
			var script_any: Variant = child_node.get_script()
			if script_any is Script:
				script_path = str((script_any as Script).resource_path)
			root_child_rows.append("%d|%s|%s|%s" % [
				int(child_node.get_instance_id()),
				str(child_node.name),
				child_node.get_class(),
				script_path
			])
		for arena_any in tree.get_nodes_in_group("Arena"):
			if arena_any is Node:
				arena_nodes.append(int((arena_any as Node).get_instance_id()))
	root_children.sort()
	root_child_rows.sort()
	arena_nodes.sort()
	return {
		"root_child_instance_ids": root_children,
		"root_child_rows": root_child_rows,
		"arena_instance_ids": arena_nodes,
		"ops_signal_connections": _ops_signal_connections(ops_state)
	}


static func _ops_signal_connections(ops_state: Node) -> Dictionary:
	var out: Dictionary = {}
	if ops_state == null:
		return out
	for signal_name in OPS_SIGNAL_NAMES:
		if not ops_state.has_signal(signal_name):
			continue
		var rows: Array[String] = []
		for connection_any in ops_state.get_signal_connection_list(signal_name):
			if typeof(connection_any) != TYPE_DICTIONARY:
				continue
			var connection: Dictionary = connection_any as Dictionary
			rows.append("%s|%d" % [str(connection.get("callable", Callable())), int(connection.get("flags", 0))])
		rows.sort()
		out[str(signal_name)] = rows
	return out


static func _fingerprint_hash(snapshot: Dictionary) -> String:
	return DeterministicHash.hash_variant({
		"project_settings": snapshot.get("project_settings", {}),
		"audio_buses": snapshot.get("audio_buses", {}),
		"engine": snapshot.get("engine", {}),
		"rendering_default_clear_color": snapshot.get("rendering_default_clear_color"),
		"tree_metadata": snapshot.get("tree_metadata", {}),
		"ops_properties": snapshot.get("ops_properties", {}),
		"ops_rng_states": snapshot.get("ops_rng_states", {}),
		"shared_runtime_properties": snapshot.get("shared_runtime_properties", {}),
		"protected_state": snapshot.get("protected_state", {}),
		"tree_topology": snapshot.get("tree_topology", {})
	})


static func _copy_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return value.duplicate()
	return value
