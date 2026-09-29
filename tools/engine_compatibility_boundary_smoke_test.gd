extends SceneTree

const DeterministicHash := preload("res://scripts/tests/perf/perf_deterministic_hash.gd")

var _failed: bool = false


func _init() -> void:
	_test_canonical_integral_float_serialization()
	_test_json_numeric_hive_ids()
	if not _failed:
		print("ENGINE_COMPATIBILITY_BOUNDARY_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_canonical_integral_float_serialization() -> void:
	var parsed: Variant = JSON.parse_string(
		'{"fractional":2.5,"integral":5,"negative_zero":-0.0}'
	)
	_expect(typeof(parsed) == TYPE_DICTIONARY, "numeric fixture must parse")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var values: Dictionary = parsed as Dictionary
	_expect(typeof(values.get("integral")) == TYPE_FLOAT, "JSON integral number must exercise the float boundary")
	_expect(
		DeterministicHash.canonical_json(values)
			== '{"fractional":2.5,"integral":5,"negative_zero":0}',
		"canonical numeric text must not depend on integral-float engine formatting"
	)


func _test_json_numeric_hive_ids() -> void:
	var parsed: Variant = JSON.parse_string(
		'{"hives":['
		+ '{"id":1,"x":0,"y":0,"owner_id":1,"power":10,"kind":"Hive"},'
		+ '{"id":2.0,"x":1,"y":0,"owner_id":2,"power":10,"kind":"Hive"},'
		+ '{"id":2.5,"x":2,"y":0,"owner_id":1,"power":10,"kind":"Hive"},'
		+ '{"id":"3","x":3,"y":0,"owner_id":1,"power":10,"kind":"Hive"}'
		+ ']}'
	)
	_expect(typeof(parsed) == TYPE_DICTIONARY, "map fixture must parse")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var state := GameState.new()
	state.load_from_map_dict(parsed as Dictionary)
	_expect(state.hives.size() == 3, "integral numeric and integer-string IDs must load; fractional IDs must fail closed")
	_expect(state.find_hive_by_id(1) != null, "JSON integer-valued float ID 1 must load")
	_expect(state.find_hive_by_id(2) != null, "explicit integral float ID 2.0 must load")
	_expect(state.find_hive_by_id(3) != null, "integer-string ID 3 must load")
	_expect(state.find_hive_by_id(2).owner_id == 2, "loaded numeric ID must preserve authoritative ownership")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("ENGINE_COMPATIBILITY_BOUNDARY_SMOKE: %s" % message)
