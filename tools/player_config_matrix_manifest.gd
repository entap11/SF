extends RefCounted

const TOPOLOGY_1V1 := "1v1"
const TOPOLOGY_2V2 := "2v2"
const TOPOLOGY_3P_FFA := "3p_ffa"
const TOPOLOGY_4P_FFA := "4p_ffa"

const CONTRACT_1V1 := "1V1"
const CONTRACT_2V2 := "2V2"
const CONTRACT_3P_FFA := "3P_FFA"
const CONTRACT_4P_FFA := "4P_FFA"

const RULE_STAGE_RACE := "STAGE_RACE"
const RULE_CAPTURE_FLAG := "CAPTURE_FLAG"
const RULE_HIDDEN_CAPTURE_FLAG := "HIDDEN_CAPTURE_FLAG"
const RULE_TIMED_RACE := "TIMED_RACE"
const RULE_MISS_N_OUT := "MISS_N_OUT"

const EXPECT_VALID := "valid"
const EXPECT_INVALID := "invalid"

const ENTRY_FREE := "free"
const ENTRY_PAID_1 := "paid_1"

const MAP_QUADFIGHT_1P := "res://maps/_future/quadfight/MAP_quadfight__SBASE__1p.json"
const MAP_QUADFIGHT_2P := "res://maps/_future/quadfight/MAP_quadfight__SBASE__2p.json"
const MAP_QUADFIGHT_4P := "res://maps/_future/quadfight/MAP_quadfight__SBASE__4p.json"
const MAP_DELTA_3P := "res://maps/delta/MAP_delta__SBASE__3p.json"
const MAP_HIDDEN_CTF_1P := "res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json"

static func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for topology_entry in _topology_entries():
		for rules_mode in _rules_modes():
			out.append(_valid_row(topology_entry, rules_mode, ENTRY_FREE))
	out.append(_valid_row(_topology_entries()[0], RULE_STAGE_RACE, ENTRY_PAID_1))
	out.append(_valid_row(_topology_entries()[1], RULE_CAPTURE_FLAG, ENTRY_PAID_1))
	out.append(_valid_row(_topology_entries()[2], RULE_TIMED_RACE, ENTRY_PAID_1))
	out.append(_valid_row(_topology_entries()[3], RULE_HIDDEN_CAPTURE_FLAG, ENTRY_PAID_1))
	out.append_array(_invalid_rows())
	return out

static func row_by_id(config_id: String) -> Dictionary:
	for row in rows():
		if str(row.get("config_id", "")) == config_id:
			return row
	return {}

static func topology_entries() -> Array[Dictionary]:
	return _topology_entries()

static func rules_modes() -> Array[String]:
	return _rules_modes()

static func required_variant_for_contract_mode(contract_mode: String) -> String:
	match _normalize_contract_mode(contract_mode):
		CONTRACT_1V1:
			return "1p"
		CONTRACT_2V2:
			return "2p"
		CONTRACT_3P_FFA:
			return "3p"
		CONTRACT_4P_FFA:
			return "4p"
		_:
			return ""

static func required_players_for_topology(topology: String) -> int:
	match topology:
		TOPOLOGY_1V1:
			return 2
		TOPOLOGY_2V2:
			return 4
		TOPOLOGY_3P_FFA:
			return 3
		TOPOLOGY_4P_FFA:
			return 4
		_:
			return 0

static func expected_team_layout(topology: String) -> Array[int]:
	match topology:
		TOPOLOGY_1V1:
			return [1, 2]
		TOPOLOGY_2V2:
			return [1, 2, 1, 2]
		TOPOLOGY_3P_FFA:
			return [1, 2, 3]
		TOPOLOGY_4P_FFA:
			return [1, 2, 3, 4]
		_:
			return []

static func is_ctf_rules_mode(rules_mode: String) -> bool:
	return rules_mode == RULE_CAPTURE_FLAG or rules_mode == RULE_HIDDEN_CAPTURE_FLAG

static func is_hidden_ctf_rules_mode(rules_mode: String) -> bool:
	return rules_mode == RULE_HIDDEN_CAPTURE_FLAG

static func smoke_routes() -> Array[Dictionary]:
	return [
		{
			"route_id": "matrix_topology_boot",
			"script": "tools/player_config_matrix_topology_boot_runner.gd",
			"coverage": ["topology", "prematch", "boot", "manifest"]
		},
		{
			"route_id": "human_pvp_1v1_boot",
			"script": "tools/human_pvp_boot_smoke_test.gd",
			"coverage": ["1v1", "human_pvp", "boot"]
		},
		{
			"route_id": "prematch_2v2_boot",
			"script": "tools/prematch_orientation_2v2_card_smoke_test.gd",
			"coverage": ["2v2", "prematch", "boot"]
		},
		{
			"route_id": "prematch_3p_boot",
			"script": "tools/prematch_orientation_3p_card_smoke_test.gd",
			"coverage": ["3p_ffa", "prematch", "boot"]
		},
		{
			"route_id": "prematch_4p_boot",
			"script": "tools/prematch_orientation_4p_card_smoke_test.gd",
			"coverage": ["4p_ffa", "prematch", "boot"]
		},
		{
			"route_id": "capture_flag_logic",
			"script": "tools/capture_flag_smoke_test.gd",
			"coverage": ["capture_flag", "hidden_capture_flag", "logic"]
		},
		{
			"route_id": "matrix_mode_runtime",
			"script": "tools/player_config_matrix_mode_runtime_runner.gd",
			"coverage": ["stage_race", "timed_race", "miss_n_out", "capture_flag", "hidden_capture_flag", "mode_runtime", "manifest"]
		},
		{
			"route_id": "hidden_ctf_map_rules",
			"script": "tools/hidden_ctf_map_rules_smoke_test.gd",
			"coverage": ["hidden_capture_flag", "map_rules"]
		},
		{
			"route_id": "map_mode_contract",
			"script": "tools/map_mode_contract_smoke_test.gd",
			"coverage": ["contract", "map_mode"]
		},
		{
			"route_id": "pvp_1v1_map_contract",
			"script": "tools/pvp_1v1_map_contract_smoke_test.gd",
			"coverage": ["contract", "candidate_maps"]
		}
	]

static func _valid_row(topology_entry: Dictionary, rules_mode: String, entry_type: String) -> Dictionary:
	var topology: String = str(topology_entry.get("topology", ""))
	var contract_mode: String = str(topology_entry.get("contract_mode", ""))
	var map_path: String = str(topology_entry.get("map_path", ""))
	var config_id := "%s__%s__%s" % [topology, rules_mode.to_lower(), entry_type]
	var ctf_options: Dictionary = _default_ctf_options(rules_mode)
	return {
		"config_id": config_id,
		"tiers": _tiers_for(rules_mode, entry_type),
		"topology": topology,
		"contract_mode": contract_mode,
		"rules_mode": rules_mode,
		"source_map_path": map_path,
		"resolved_map_path": map_path,
		"entry_type": entry_type,
		"ctf_options": ctf_options,
		"expected_contract": EXPECT_VALID,
		"expected_failure_reason": "",
		"expected_runtime_assertions": _runtime_assertions_for(rules_mode),
		"existing_smoke": _existing_smoke_for(topology, rules_mode)
	}

static func _invalid_rows() -> Array[Dictionary]:
	return [
		_invalid_row("invalid_1v1_on_3p_map", TOPOLOGY_1V1, CONTRACT_1V1, RULE_STAGE_RACE, MAP_DELTA_3P, "requires_1p_map_path"),
		_invalid_row("invalid_2v2_on_3p_map", TOPOLOGY_2V2, CONTRACT_2V2, RULE_CAPTURE_FLAG, MAP_DELTA_3P, "requires_2p_map_path"),
		_invalid_row("invalid_3p_on_1p_map", TOPOLOGY_3P_FFA, CONTRACT_3P_FFA, RULE_TIMED_RACE, MAP_HIDDEN_CTF_1P, "requires_3p_map_path"),
		_invalid_row("invalid_4p_on_3p_map", TOPOLOGY_4P_FFA, CONTRACT_4P_FFA, RULE_MISS_N_OUT, MAP_DELTA_3P, "requires_4p_map_path"),
		_invalid_hidden_ctf_row()
	]

static func _invalid_row(
	config_id: String,
	topology: String,
	contract_mode: String,
	rules_mode: String,
	map_path: String,
	reason: String
) -> Dictionary:
	return {
		"config_id": config_id,
		"tiers": ["fast", "pr", "nightly"],
		"topology": topology,
		"contract_mode": contract_mode,
		"rules_mode": rules_mode,
		"source_map_path": map_path,
		"resolved_map_path": map_path,
		"entry_type": ENTRY_FREE,
		"ctf_options": _default_ctf_options(rules_mode),
		"expected_contract": EXPECT_INVALID,
		"expected_failure_reason": reason,
		"expected_runtime_assertions": [],
		"existing_smoke": []
	}

static func _invalid_hidden_ctf_row() -> Dictionary:
	var row: Dictionary = _invalid_row(
		"invalid_hidden_ctf_reveal_disabled",
		TOPOLOGY_1V1,
		CONTRACT_1V1,
		RULE_HIDDEN_CAPTURE_FLAG,
		MAP_HIDDEN_CTF_1P,
		"hidden_ctf_requires_reveal_on_move"
	)
	row["ctf_options"] = {
		"flag_selection_mode": "player_select",
		"player_select_pct": 100,
		"randomize_flag_hive": true,
		"flag_move_count_max": 1,
		"flag_move_reveals": false
	}
	return row

static func _topology_entries() -> Array[Dictionary]:
	return [
		{"topology": TOPOLOGY_1V1, "contract_mode": CONTRACT_1V1, "map_path": MAP_QUADFIGHT_1P},
		{"topology": TOPOLOGY_2V2, "contract_mode": CONTRACT_2V2, "map_path": MAP_QUADFIGHT_2P},
		{"topology": TOPOLOGY_3P_FFA, "contract_mode": CONTRACT_3P_FFA, "map_path": MAP_DELTA_3P},
		{"topology": TOPOLOGY_4P_FFA, "contract_mode": CONTRACT_4P_FFA, "map_path": MAP_QUADFIGHT_4P}
	]

static func _rules_modes() -> Array[String]:
	return [
		RULE_STAGE_RACE,
		RULE_CAPTURE_FLAG,
		RULE_HIDDEN_CAPTURE_FLAG,
		RULE_TIMED_RACE,
		RULE_MISS_N_OUT
	]

static func _tiers_for(rules_mode: String, entry_type: String) -> Array[String]:
	if entry_type == ENTRY_PAID_1:
		return ["pr", "nightly"]
	if rules_mode == RULE_STAGE_RACE:
		return ["fast", "pr", "nightly"]
	if rules_mode == RULE_HIDDEN_CAPTURE_FLAG:
		return ["fast", "pr", "nightly"]
	return ["pr", "nightly"]

static func _default_ctf_options(rules_mode: String) -> Dictionary:
	if rules_mode == RULE_HIDDEN_CAPTURE_FLAG:
		return {
			"flag_selection_mode": "player_select",
			"player_select_pct": 100,
			"randomize_flag_hive": true,
			"flag_move_count_max": 1,
			"flag_move_reveals": true
		}
	if rules_mode == RULE_CAPTURE_FLAG:
		return {
			"flag_selection_mode": "weighted",
			"player_select_pct": 35,
			"randomize_flag_hive": true,
			"flag_move_count_max": 1,
			"flag_move_reveals": true
		}
	return {}

static func _runtime_assertions_for(rules_mode: String) -> Array[String]:
	match rules_mode:
		RULE_STAGE_RACE:
			return ["stage_index_advances", "round_result_records"]
		RULE_TIMED_RACE:
			return ["timer_starts", "timeout_or_end_fires"]
		RULE_MISS_N_OUT:
			return ["elimination_state_changes"]
		RULE_CAPTURE_FLAG:
			return ["visible_flags_assign", "capture_emits_flag_capture"]
		RULE_HIDDEN_CAPTURE_FLAG:
			return ["own_flag_visible", "enemy_flag_hidden", "player_select_works", "move_budget_decrements"]
		_:
			return []

static func _existing_smoke_for(topology: String, rules_mode: String) -> Array[String]:
	var routes: Array[String] = []
	match topology:
		TOPOLOGY_1V1, TOPOLOGY_2V2, TOPOLOGY_3P_FFA, TOPOLOGY_4P_FFA:
			routes.append("tools/player_config_matrix_topology_boot_runner.gd")
	if rules_mode == RULE_STAGE_RACE or rules_mode == RULE_TIMED_RACE or rules_mode == RULE_MISS_N_OUT:
		routes.append("tools/player_config_matrix_mode_runtime_runner.gd")
	elif rules_mode == RULE_CAPTURE_FLAG:
		routes.append("tools/player_config_matrix_mode_runtime_runner.gd")
		routes.append("tools/capture_flag_smoke_test.gd")
	elif rules_mode == RULE_HIDDEN_CAPTURE_FLAG:
		routes.append("tools/player_config_matrix_mode_runtime_runner.gd")
		routes.append("tools/capture_flag_smoke_test.gd")
		routes.append("tools/hidden_ctf_map_rules_smoke_test.gd")
	return routes

static func _normalize_contract_mode(contract_mode: String) -> String:
	var clean: String = contract_mode.strip_edges().to_upper().replace(" ", "_").replace("-", "_")
	match clean:
		"1V1", "PVP":
			return CONTRACT_1V1
		"2V2":
			return CONTRACT_2V2
		"3P_FFA", "3P":
			return CONTRACT_3P_FFA
		"4P_FFA", "4P":
			return CONTRACT_4P_FFA
		_:
			return clean
