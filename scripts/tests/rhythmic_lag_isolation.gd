extends SceneTree

const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const ARENA_POLISH_LAYER := preload("res://scripts/renderers/arena_polish_layer.gd")

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const DEFAULT_MAP := "res://maps/_future/centerstrike/MAP_centerstrike__SBASE__2p.json"
const DEFAULT_OUTPUT_PATH := "res://debug_reports/rhythmic_lag_isolation_latest.json"
const DEFAULT_DURATION_SEC: float = 30.0
const HITCH_THRESHOLD_MS: float = 24.0
const SIM_TICK_INTERVAL_SEC: float = 0.1
const FRAME_TARGET_SEC: float = 1.0 / 60.0

class SyntheticFloorOverlayProbe:
	extends Node2D

	var resolution: int = 128
	var update_interval_sec: float = 1.0
	var _accum: float = 0.0
	var _phase: int = 0
	var _sprite: Sprite2D = null
	var _texture: ImageTexture = null

	func configure(config: Dictionary) -> void:
		resolution = maxi(16, int(config.get("resolution", resolution)))
		update_interval_sec = maxf(0.0, float(config.get("update_interval_sec", update_interval_sec)))

	func _ready() -> void:
		_sprite = Sprite2D.new()
		_sprite.name = "SyntheticFloorOverlaySprite"
		add_child(_sprite)
		_rebuild_texture()
		set_process(true)

	func _process(delta: float) -> void:
		_accum += maxf(0.0, delta)
		if update_interval_sec > 0.0 and _accum < update_interval_sec:
			return
		_accum = 0.0
		_rebuild_texture()

	func _rebuild_texture() -> void:
		_phase += 1
		var image := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
		for y in range(resolution):
			for x in range(resolution):
				var v := float((x * 17 + y * 31 + _phase * 13) % 255) / 255.0
				image.set_pixel(x, y, Color(v, 1.0 - v, 0.25 + (0.35 * v), 0.45))
		_texture = ImageTexture.create_from_image(image)
		if _sprite != null:
			_sprite.texture = _texture
			_sprite.centered = false
			_sprite.z_index = -12

var OpsState: Node = null
var _audio_mute_snapshot: Dictionary = {}

func _init() -> void:
	call_deferred("_run_entry")

func _run_entry() -> void:
	OpsState = root.get_node_or_null("/root/OpsState")
	if OpsState == null:
		push_error("rhythmic_lag_isolation: OpsState autoload is not available")
		quit(2)
		return
	var args: Dictionary = _parse_args()
	var report: Dictionary = await _run_matrix(args)
	_write_json(str(args.get("output", DEFAULT_OUTPUT_PATH)), report)
	print(_table_text(report))
	quit(0)

func _run_matrix(args: Dictionary) -> Dictionary:
	var duration_sec := maxf(0.1, float(args.get("duration_sec", DEFAULT_DURATION_SEC)))
	var map_path := str(args.get("map", DEFAULT_MAP))
	var variants: Array = _variant_definitions()
	var filter := str(args.get("variant", "")).strip_edges()
	var group_filter := str(args.get("group", "baseline")).strip_edges()
	if not group_filter.is_empty() and group_filter != "all":
		var grouped: Array = []
		for variant_group_any in variants:
			var variant_group: Dictionary = variant_group_any as Dictionary
			var variant_id := str(variant_group.get("id", ""))
			var variant_group_name := str(variant_group.get("group", "baseline"))
			if variant_group_name == group_filter:
				grouped.append(variant_group)
			elif group_filter in ["runtime_layers", "presentation_layers"] and variant_id == "A_full_game":
				grouped.append(variant_group)
			elif group_filter == "sim_layers" and variant_id in ["A_full_game", "B_sim_only"]:
				grouped.append(variant_group)
			elif group_filter == "floor_budget" and variant_id in ["A_full_game", "D_presentation_only"]:
				grouped.append(variant_group)
		variants = grouped
	if not filter.is_empty():
		var filtered: Array = []
		for variant_any in variants:
			var variant: Dictionary = variant_any as Dictionary
			if str(variant.get("id", "")) == filter:
				filtered.append(variant)
		variants = filtered
	var reports: Array = []
	for variant_any in variants:
		var variant: Dictionary = variant_any as Dictionary
		reports.append(await _run_variant(variant, map_path, duration_sec))
	var comparison: Dictionary = _comparison_for_reports(reports)
	return {
		"report_type": "sf_rhythmic_lag_isolation",
		"generated_at_unix": Time.get_unix_time_from_system(),
		"duration_sec": duration_sec,
		"hitch_threshold_ms": HITCH_THRESHOLD_MS,
		"map_path": map_path,
		"git": _git_metadata(),
		"godot": Engine.get_version_info(),
		"machine": _machine_metadata(),
		"variants": reports,
		"comparison": comparison
	}

func _run_variant(variant: Dictionary, map_path: String, duration_sec: float) -> Dictionary:
	seed(int(variant.get("seed", 6101)))
	SFLog.force_enable(false)
	var setup: Dictionary = await _setup_scene(map_path)
	if not bool(setup.get("ok", false)):
		return _variant_error(variant, str(setup.get("reason", "setup_failed")))
	var scene_root: Node = setup.get("scene_root", null) as Node
	var arena: Node = setup.get("arena", null) as Node
	var sim_runner: Node = _arena_sim_runner(arena)
	var state: GameState = OpsState.require_state()
	var flags: Dictionary = (variant.get("flags", {}) as Dictionary).duplicate(true)
	_prepare_match_for_isolation()
	_apply_initial_lane_pressure(arena, state, int(variant.get("initial_lanes", 8)), int(variant.get("initial_swarms", 2)))
	_apply_kill_switches(scene_root, arena, flags)
	var cost_center_profile := bool(variant.get("cost_center_profile", false))
	var unit_system: Object = sim_runner.get("unit_system")
	if cost_center_profile:
		if state.has_method("set_lane_flow_profile_enabled"):
			state.call("set_lane_flow_profile_enabled", true, true)
		if unit_system != null and unit_system.has_method("set_unit_flow_profile_enabled"):
			unit_system.call("set_unit_flow_profile_enabled", true, true)
		if OpsState != null and OpsState.has_method("set_intent_profile_enabled"):
			OpsState.call("set_intent_profile_enabled", true, true)
	var manual_sim_enabled := bool(variant.get("sim_advances", true))
	var presentation_only := bool(variant.get("presentation_only", false))
	var frame_samples: Array = []
	var hitches: Array = []
	var command_log: Array = []
	var command_profile: Dictionary = {"totals": {}, "events": []}
	var command_cache_enabled := not bool(variant.get("disable_command_cache", false))
	var command_cache: Dictionary = _build_command_cache(state, command_profile if cost_center_profile else {}) if command_cache_enabled else {}
	var tick_index := 0
	var sim_accumulator := 0.0
	var started_usec := Time.get_ticks_usec()
	var last_frame_usec := started_usec
	var last_physics_frames := Engine.get_physics_frames()
	var frame_index := 0
	while float(Time.get_ticks_usec() - started_usec) / 1000000.0 < duration_sec:
		frame_index += 1
		var update_start_usec := Time.get_ticks_usec()
		var sim_tick_ms := 0.0
		var sim_ticks_this_frame := 0
		if manual_sim_enabled and not presentation_only:
			sim_accumulator += FRAME_TARGET_SEC
			while sim_accumulator + 0.000001 >= SIM_TICK_INTERVAL_SEC:
				sim_accumulator -= SIM_TICK_INTERVAL_SEC
				tick_index += 1
				var issued: Array = _issue_scripted_commands(arena, state, flags, tick_index, command_cache, command_profile if cost_center_profile else {})
				if not issued.is_empty():
					command_log.append({"tick": tick_index, "commands": issued})
				var t0 := Time.get_ticks_usec()
				_tick_systems(arena, sim_runner, state, flags, SIM_TICK_INTERVAL_SEC)
				sim_tick_ms += float(Time.get_ticks_usec() - t0) / 1000.0
				sim_ticks_this_frame += 1
		var update_ms := float(Time.get_ticks_usec() - update_start_usec) / 1000.0
		await process_frame
		var now_usec := Time.get_ticks_usec()
		var delta_ms := float(now_usec - last_frame_usec) / 1000.0
		last_frame_usec = now_usec
		var physics_frames := Engine.get_physics_frames()
		var physics_delta := physics_frames - last_physics_frames
		last_physics_frames = physics_frames
		var sample: Dictionary = _frame_sample(
			frame_index,
			delta_ms,
			physics_delta,
			sim_tick_ms,
			sim_ticks_this_frame,
			update_ms,
			maxf(0.0, delta_ms - update_ms),
			tick_index,
			float(now_usec - started_usec) / 1000000.0,
			flags
		)
		frame_samples.append(sample)
		if delta_ms > HITCH_THRESHOLD_MS:
			var hitch: Dictionary = sample.duplicate(true)
			hitch["flags"] = flags.duplicate(true)
			hitches.append(hitch)
			print("RHYTHMIC_HITCH %s" % JSON.stringify({
				"variant": str(variant.get("id", "")),
				"frame": frame_index,
				"delta_ms": snappedf(delta_ms, 0.001),
				"tick": tick_index,
				"wall_time_sec": snappedf(float(hitch.get("wall_time_sec", 0.0)), 0.001),
				"flags": flags
			}))
	var metrics: Dictionary = _frame_metrics(_frame_deltas(frame_samples))
	var lane_flow_profile: Dictionary = {}
	var unit_flow_profile: Dictionary = {}
	var ops_intent_profile: Dictionary = {}
	if cost_center_profile:
		if state.has_method("get_lane_flow_profile_report"):
			lane_flow_profile = state.call("get_lane_flow_profile_report") as Dictionary
		if unit_system != null and unit_system.has_method("get_unit_flow_profile_report"):
			unit_flow_profile = unit_system.call("get_unit_flow_profile_report") as Dictionary
		if OpsState != null and OpsState.has_method("get_intent_profile_report"):
			ops_intent_profile = OpsState.call("get_intent_profile_report") as Dictionary
		if state.has_method("set_lane_flow_profile_enabled"):
			state.call("set_lane_flow_profile_enabled", false, false)
		if unit_system != null and unit_system.has_method("set_unit_flow_profile_enabled"):
			unit_system.call("set_unit_flow_profile_enabled", false, false)
		if OpsState != null and OpsState.has_method("set_intent_profile_enabled"):
			OpsState.call("set_intent_profile_enabled", false, false)
	var report := {
		"variant_id": str(variant.get("id", "")),
		"label": str(variant.get("label", "")),
		"seed": int(variant.get("seed", 6101)),
		"duration_sec": duration_sec,
		"flags": flags,
		"sim_advances": manual_sim_enabled,
		"presentation_only": presentation_only,
		"command_cache": _command_cache_report(command_cache, command_cache_enabled),
		"frame_count": frame_samples.size(),
		"tick_count": tick_index,
		"scripted_command_count": _scripted_command_count(command_log),
		"scripted_commands": command_log,
		"average_frame_ms": metrics.get("average_frame_ms", 0.0),
		"p95_frame_ms": metrics.get("p95_frame_ms", 0.0),
		"p99_frame_ms": metrics.get("p99_frame_ms", 0.0),
		"max_frame_ms": metrics.get("max_frame_ms", 0.0),
		"hitch_count": hitches.size(),
		"hitches": hitches,
		"worst_frames": _worst_frames(frame_samples, 12),
		"rhythmic_hitch": _rhythmic_hitch_summary(hitches),
		"frame_samples": frame_samples
	}
	if cost_center_profile:
		report["lane_flow_profile"] = lane_flow_profile
		report["unit_flow_profile"] = unit_flow_profile
		report["command_profile"] = _cost_profile_report(command_profile)
		report["ops_intent_profile"] = ops_intent_profile
	if OpsState != null and OpsState.has_method("set_intent_cost_switches"):
		OpsState.call("set_intent_cost_switches", true, true, true)
	_restore_audio()
	SFLog.force_enable(false)
	_teardown_node(scene_root)
	await process_frame
	return report

func _variant_definitions() -> Array:
	var full_flags := _default_flags()
	var sim_only := _default_flags()
	sim_only["fog_visuals"] = false
	sim_only["territory_visuals"] = false
	sim_only["combat_visuals"] = false
	sim_only["debug_hud_logging"] = false
	sim_only["debug_warning_emission"] = false
	sim_only["audio"] = false
	sim_only["floating_text_vfx"] = false
	sim_only["path_previews_orders_overlay"] = false
	sim_only["sim_only_visual_mode"] = true
	var sim_only_bots_off := sim_only.duplicate(true)
	sim_only_bots_off["bots"] = false
	var presentation := _default_flags()
	presentation["bots"] = false
	presentation["fog_sim"] = false
	presentation["territory_sim"] = false
	presentation["hash_checks_desync_checks"] = false
	presentation["network_command_resend_snapshot_emit"] = false
	presentation["debug_hud_logging"] = false
	presentation["debug_warning_emission"] = false
	presentation["audio"] = false
	var full_bots_off := full_flags.duplicate(true)
	full_bots_off["bots"] = false
	var full_hash_network_off := full_flags.duplicate(true)
	full_hash_network_off["hash_checks_desync_checks"] = false
	full_hash_network_off["network_command_resend_snapshot_emit"] = false
	var full_audio_off := full_flags.duplicate(true)
	full_audio_off["audio"] = false
	var full_debug_off := full_flags.duplicate(true)
	full_debug_off["debug_hud_logging"] = false
	full_debug_off["debug_warning_emission"] = false
	var full_log_emission_off := full_flags.duplicate(true)
	full_log_emission_off["debug_warning_emission"] = false
	var full_intent_telemetry_off := full_log_emission_off.duplicate(true)
	full_intent_telemetry_off["intent_telemetry"] = false
	var full_intent_action_events_off := full_log_emission_off.duplicate(true)
	full_intent_action_events_off["intent_action_events"] = false
	var full_intent_snapshots_off := full_log_emission_off.duplicate(true)
	full_intent_snapshots_off["intent_pre_apply_snapshots"] = false
	var full_intent_overhead_off := full_log_emission_off.duplicate(true)
	full_intent_overhead_off["intent_telemetry"] = false
	full_intent_overhead_off["intent_action_events"] = false
	full_intent_overhead_off["intent_pre_apply_snapshots"] = false
	var full_fog_visuals_off := full_flags.duplicate(true)
	full_fog_visuals_off["fog_visuals"] = false
	var full_territory_visuals_off := full_flags.duplicate(true)
	full_territory_visuals_off["territory_visuals"] = false
	var full_combat_visuals_off := full_flags.duplicate(true)
	full_combat_visuals_off["combat_visuals"] = false
	var full_vfx_off := full_flags.duplicate(true)
	full_vfx_off["floating_text_vfx"] = false
	var full_previews_off := full_flags.duplicate(true)
	full_previews_off["path_previews_orders_overlay"] = false
	var sim_lane_flow_off := sim_only.duplicate(true)
	sim_lane_flow_off["lane_flow"] = false
	var sim_edge_cache_off := sim_only.duplicate(true)
	sim_edge_cache_off["edge_cache"] = false
	var sim_units_off := sim_only.duplicate(true)
	sim_units_off["unit_system"] = false
	sim_units_off["swarm_system"] = false
	var sim_towers_off := sim_only.duplicate(true)
	sim_towers_off["tower_system"] = false
	sim_towers_off["structure_control"] = false
	var sim_barracks_off := sim_only.duplicate(true)
	sim_barracks_off["barracks_system"] = false
	var sim_only_log_emission_on := sim_only.duplicate(true)
	sim_only_log_emission_on["debug_warning_emission"] = true
	var presentation_floor_off := presentation.duplicate(true)
	presentation_floor_off["territory_visuals"] = false
	var floor_overlay_static := presentation.duplicate(true)
	floor_overlay_static["synthetic_floor_overlay"] = true
	floor_overlay_static["synthetic_floor_overlay_resolution"] = 128
	floor_overlay_static["synthetic_floor_overlay_interval_sec"] = 999.0
	var floor_overlay_250ms := floor_overlay_static.duplicate(true)
	floor_overlay_250ms["synthetic_floor_overlay_interval_sec"] = 0.25
	var floor_overlay_frame := floor_overlay_static.duplicate(true)
	floor_overlay_frame["synthetic_floor_overlay_resolution"] = 256
	floor_overlay_frame["synthetic_floor_overlay_interval_sec"] = 0.0
	return [
		{"id": "A_full_game", "label": "A. full game", "group": "baseline", "flags": full_flags, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "B_sim_only", "label": "B. sim-only visual mode", "group": "baseline", "flags": sim_only, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "C_sim_only_bots_off", "label": "C. sim-only + bots off", "group": "baseline", "flags": sim_only_bots_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "D_presentation_only", "label": "D. presentation only, sim paused", "group": "baseline", "flags": presentation, "sim_advances": false, "presentation_only": true, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "E_full_bots_off", "label": "E. full game, bots off", "group": "runtime_layers", "flags": full_bots_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "F_full_hash_network_off", "label": "F. full game, hash/network off", "group": "runtime_layers", "flags": full_hash_network_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "G_full_audio_off", "label": "G. full game, audio off", "group": "runtime_layers", "flags": full_audio_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "H_full_debug_off", "label": "H. full game, debug/HUD logging off", "group": "runtime_layers", "flags": full_debug_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "I_sim_lane_flow_off", "label": "I. sim-only, lane flow off", "group": "sim_layers", "flags": sim_lane_flow_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "J_sim_edge_cache_off", "label": "J. sim-only, edge cache off", "group": "sim_layers", "flags": sim_edge_cache_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "K_sim_units_off", "label": "K. sim-only, units/swarms off", "group": "sim_layers", "flags": sim_units_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "L_sim_towers_off", "label": "L. sim-only, towers/control off", "group": "sim_layers", "flags": sim_towers_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "M_sim_barracks_off", "label": "M. sim-only, barracks off", "group": "sim_layers", "flags": sim_barracks_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "N_full_fog_visuals_off", "label": "N. full game, fog visuals off", "group": "presentation_layers", "flags": full_fog_visuals_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "O_full_territory_visuals_off", "label": "O. full game, territory visuals off", "group": "presentation_layers", "flags": full_territory_visuals_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "P_full_combat_visuals_off", "label": "P. full game, combat visuals off", "group": "presentation_layers", "flags": full_combat_visuals_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "Q_full_vfx_off", "label": "Q. full game, VFX/floating text off", "group": "presentation_layers", "flags": full_vfx_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "R_full_previews_off", "label": "R. full game, previews/orders off", "group": "presentation_layers", "flags": full_previews_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "S_presentation_floor_off", "label": "S. presentation only, floor off", "group": "floor_budget", "flags": presentation_floor_off, "sim_advances": false, "presentation_only": true, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "T_floor_overlay_static", "label": "T. synthetic floor overlay static", "group": "floor_budget", "flags": floor_overlay_static, "sim_advances": false, "presentation_only": true, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "U_floor_overlay_250ms", "label": "U. synthetic floor overlay 250ms", "group": "floor_budget", "flags": floor_overlay_250ms, "sim_advances": false, "presentation_only": true, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "V_floor_overlay_frame", "label": "V. synthetic floor overlay every frame", "group": "floor_budget", "flags": floor_overlay_frame, "sim_advances": false, "presentation_only": true, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2},
		{"id": "W_full_cost_centers", "label": "W. full game, cost centers", "group": "cost_centers", "flags": full_flags, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2, "cost_center_profile": true},
		{"id": "X_sim_only_cost_centers", "label": "X. sim-only, cost centers", "group": "cost_centers", "flags": sim_only, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2, "cost_center_profile": true},
		{"id": "Y_full_cost_centers_logs_off", "label": "Y. full game, cost centers, log emission off", "group": "cost_centers", "flags": full_log_emission_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2, "cost_center_profile": true},
		{"id": "Z_sim_only_cost_centers_logs_on", "label": "Z. sim-only, cost centers, log emission on", "group": "cost_centers", "flags": sim_only_log_emission_on, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2, "cost_center_profile": true},
		{"id": "AA_full_intent_telemetry_off", "label": "AA. full game, intent telemetry off", "group": "cost_centers", "flags": full_intent_telemetry_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2, "cost_center_profile": true},
		{"id": "AB_full_intent_action_events_off", "label": "AB. full game, intent action events off", "group": "cost_centers", "flags": full_intent_action_events_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2, "cost_center_profile": true},
		{"id": "AC_full_intent_snapshots_off", "label": "AC. full game, intent snapshots off", "group": "cost_centers", "flags": full_intent_snapshots_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2, "cost_center_profile": true},
		{"id": "AD_full_intent_overhead_off", "label": "AD. full game, intent overhead off", "group": "cost_centers", "flags": full_intent_overhead_off, "sim_advances": true, "presentation_only": false, "seed": 6101, "initial_lanes": 8, "initial_swarms": 2, "cost_center_profile": true}
	]

func _default_flags() -> Dictionary:
	return {
		"bots": true,
		"lane_flow": true,
		"edge_cache": true,
		"swarm_system": true,
		"unit_system": true,
		"structure_control": true,
		"tower_system": true,
		"barracks_system": true,
		"fog_sim": true,
		"fog_visuals": true,
		"territory_sim": true,
		"territory_visuals": true,
		"combat_visuals": true,
		"debug_hud_logging": true,
		"debug_warning_emission": true,
		"intent_telemetry": true,
		"intent_action_events": true,
		"intent_pre_apply_snapshots": true,
		"hash_checks_desync_checks": true,
		"network_command_resend_snapshot_emit": true,
		"audio": true,
		"floating_text_vfx": true,
		"path_previews_orders_overlay": true,
		"sim_only_visual_mode": false,
		"synthetic_floor_overlay": false,
		"synthetic_floor_overlay_resolution": 0,
		"synthetic_floor_overlay_interval_sec": 0.0
	}

func _setup_scene(map_path: String) -> Dictionary:
	var scene_res: Resource = load(MAIN_SCENE_PATH)
	if scene_res == null or not (scene_res is PackedScene):
		return {"ok": false, "reason": "main_scene_load_failed"}
	var scene_root: Node = (scene_res as PackedScene).instantiate()
	if scene_root == null:
		return {"ok": false, "reason": "main_scene_instantiate_failed"}
	if "start_in_menu" in scene_root:
		scene_root.set("start_in_menu", false)
	if "enable_dev_map_loader" in scene_root:
		scene_root.set("enable_dev_map_loader", false)
	if "show_dev_map_loader_in_game" in scene_root:
		scene_root.set("show_dev_map_loader_in_game", false)
	root.add_child(scene_root)
	await process_frame
	await process_frame
	var arena: Node = _find_arena(scene_root)
	if arena == null:
		_teardown_node(scene_root)
		return {"ok": false, "reason": "arena_missing"}
	var load_result: Dictionary = MAP_LOADER.load_map(map_path)
	if not bool(load_result.get("ok", false)):
		_teardown_node(scene_root)
		return {"ok": false, "reason": "map_load_failed:%s" % str(load_result.get("err", load_result.get("error", "unknown")))}
	MAP_APPLIER.apply_map(arena as Node2D, load_result.get("data", {}) as Dictionary)
	await process_frame
	await process_frame
	var sim_runner: Node = _arena_sim_runner(arena)
	if sim_runner != null:
		if sim_runner.has_method("bind_state"):
			sim_runner.call("bind_state", OpsState.require_state())
		if sim_runner.has_method("set_running"):
			sim_runner.call("set_running", false, "rhythmic_lag_manual_tick")
		sim_runner.set_process(false)
		sim_runner.set_physics_process(false)
	await process_frame
	await process_frame
	return {"ok": true, "scene_root": scene_root, "arena": arena}

func _prepare_match_for_isolation() -> void:
	OpsState.sim_mutate("RhythmicLagIsolation.prepare_match", func() -> void:
		OpsState.match_phase = OpsState.MatchPhase.RUNNING
		OpsState.input_locked = false
		OpsState.input_locked_reason = ""
		OpsState.match_clock_started = false
		OpsState.match_clock_running = false
		OpsState.match_clock_paused = false
		OpsState.match_over = false
		OpsState.winner_id = 0
		OpsState.outcome = GameState.GameOutcome.NONE
	)

func _apply_initial_lane_pressure(arena: Node, state: GameState, initial_lanes: int, initial_swarms: int) -> void:
	var pairs: Array = _candidate_attack_pairs(state)
	var issued := 0
	for pair_any in pairs:
		if issued >= initial_lanes:
			break
		var pair: Dictionary = pair_any as Dictionary
		var result: Dictionary = OpsState.apply_lane_intent(int(pair.get("src", -1)), int(pair.get("dst", -1)), "attack")
		if bool(result.get("ok", false)):
			issued += 1
	for i in range(initial_swarms):
		_issue_swarm_on_active_lane(state, i)
	if arena != null and arena.has_method("mark_render_dirty"):
		arena.call("mark_render_dirty", "rhythmic_lag_initial_pressure")

func _apply_kill_switches(scene_root: Node, arena: Node, flags: Dictionary) -> void:
	var log_emission_enabled := bool(flags.get("debug_warning_emission", flags.get("debug_hud_logging", true)))
	SFLog.force_enable(log_emission_enabled)
	SFLog.set_quiet_mode(not log_emission_enabled)
	if OpsState != null and OpsState.has_method("set_intent_cost_switches"):
		OpsState.call(
			"set_intent_cost_switches",
			bool(flags.get("intent_telemetry", true)),
			bool(flags.get("intent_action_events", true)),
			bool(flags.get("intent_pre_apply_snapshots", true))
		)
	ARENA_POLISH_LAYER.apply_comparison_mode("baseline")
	if not bool(flags.get("audio", true)):
		_mute_audio()
		_disable_nodes_by_class(scene_root, ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"])
	if not bool(flags.get("debug_hud_logging", true)):
		_set_canvas_or_control_visible(scene_root, "UI", false)
		_set_canvas_or_control_visible(scene_root, "HUDCanvasLayer", false)
		_hide_nodes_named(scene_root, ["Debug", "Label", "Hud", "HUD", "Overlay"])
	if bool(flags.get("sim_only_visual_mode", false)):
		_apply_sim_only_visuals(arena)
	if not bool(flags.get("combat_visuals", true)):
		_hide_paths(arena, ["PoolsRoot/UnitRenderer", "MapRoot/UnitRenderer", "MapRoot/TowerRenderer"])
	if not bool(flags.get("territory_visuals", true)):
		_hide_paths(arena, ["MapRoot/FloorRenderer", "MapRoot/ArenaPolishLayer"])
		var influence: Object = arena.get("floor_influence_system") if arena != null and "floor_influence_system" in arena else null
		if influence != null:
			if influence.has_method("set_process"):
				influence.call("set_process", false)
			if influence.has_method("set_debug_enabled"):
				influence.call("set_debug_enabled", false)
	if not bool(flags.get("fog_visuals", true)):
		_hide_nodes_named(scene_root, ["Fog", "fog"])
	if not bool(flags.get("floating_text_vfx", true)):
		_hide_nodes_named(scene_root, ["Vfx", "VFX", "Impact", "Floating", "Popup", "Text"])
		_disable_nodes_named(scene_root, ["Vfx", "VFX", "Impact", "Floating", "Popup"])
	if not bool(flags.get("path_previews_orders_overlay", true)):
		_hide_nodes_named(scene_root, ["Preview", "preview", "Order", "order", "Selection", "Drag"])
	if not bool(flags.get("network_command_resend_snapshot_emit", true)):
		var runtime: Node = root.get_node_or_null("/root/VsPvpRuntime")
		if runtime != null:
			runtime.set_process(false)
			runtime.set_physics_process(false)
	if bool(flags.get("synthetic_floor_overlay", false)):
		_install_synthetic_floor_overlay(arena, {
			"resolution": int(flags.get("synthetic_floor_overlay_resolution", 128)),
			"update_interval_sec": float(flags.get("synthetic_floor_overlay_interval_sec", 1.0))
		})

func _apply_sim_only_visuals(arena: Node) -> void:
	if arena == null:
		return
	_hide_paths(arena, [
		"PoolsRoot/UnitRenderer",
		"MapRoot/UnitRenderer",
		"MapRoot/FloorRenderer",
		"MapRoot/TowerRenderer",
		"MapRoot/BarracksRenderer",
		"MapRoot/ArenaPolishLayer",
		"WallRenderer"
	])
	var lane_renderer: CanvasItem = arena.get_node_or_null("MapRoot/LaneRenderer") as CanvasItem
	if lane_renderer != null:
		lane_renderer.visible = true
	var hive_renderer: CanvasItem = arena.get_node_or_null("MapRoot/HiveRenderer") as CanvasItem
	if hive_renderer != null:
		hive_renderer.visible = true

func _tick_systems(arena: Node, sim_runner: Node, state: GameState, flags: Dictionary, dt: float) -> void:
	if state == null or sim_runner == null:
		return
	var dt_ms: int = int(round(dt * 1000.0))
	OpsState.tick_match_clock(state, dt_ms)
	state.tick_unintended_power(float(dt_ms))
	if bool(flags.get("bots", true)):
		var bot: Object = sim_runner.get("bot_system")
		if bot != null and bot.has_method("tick"):
			bot.call("tick", dt)
	if bool(flags.get("lane_flow", true)):
		state.tick_lane_flow(dt * 1000.0)
		var lane_system: Object = sim_runner.get("lane_system")
		if lane_system != null and lane_system.has_method("tick_lane_fronts"):
			lane_system.call("tick_lane_fronts", dt)
	if bool(flags.get("edge_cache", true)):
		var edge_cache: Object = sim_runner.get("edge_cache_system")
		if edge_cache != null and edge_cache.has_method("rebuild_edge_cache"):
			edge_cache.call("rebuild_edge_cache", OpsState)
	var unit_system: Object = sim_runner.get("unit_system")
	var swarm_system: Object = sim_runner.get("swarm_system")
	if bool(flags.get("swarm_system", true)) and swarm_system != null and swarm_system.has_method("tick"):
		swarm_system.call("tick", dt, unit_system)
	if bool(flags.get("unit_system", true)) and unit_system != null and unit_system.has_method("tick"):
		unit_system.call("tick", dt)
		if bool(flags.get("combat_visuals", true)) and unit_system.has_method("tick_render_units"):
			unit_system.call("tick_render_units", dt)
	if bool(flags.get("territory_sim", true)) and bool(flags.get("structure_control", true)):
		var structure_control: Object = sim_runner.get("structure_control_system")
		if structure_control != null and structure_control.has_method("tick"):
			structure_control.call("tick", dt)
	if bool(flags.get("tower_system", true)):
		var tower_system: Object = sim_runner.get("tower_system")
		if tower_system != null and tower_system.has_method("tick"):
			tower_system.call("tick", dt, unit_system)
	if bool(flags.get("barracks_system", true)):
		var barracks_system: Object = sim_runner.get("barracks_system")
		if barracks_system != null and barracks_system.has_method("tick"):
			barracks_system.call("tick", dt)
	if bool(flags.get("hash_checks_desync_checks", true)) and OpsState.has_method("get_contract_state_hash"):
		OpsState.call("get_contract_state_hash")
	if bool(flags.get("network_command_resend_snapshot_emit", true)):
		var runtime: Node = root.get_node_or_null("/root/VsPvpRuntime")
		if runtime != null and runtime.has_method("get_debug_snapshot"):
			runtime.call("get_debug_snapshot")
	if arena != null and arena.has_method("mark_render_dirty"):
		arena.call("mark_render_dirty", "rhythmic_lag_tick")

func _issue_scripted_commands(arena: Node, state: GameState, flags: Dictionary, tick: int, command_cache: Dictionary = {}, cost_profile: Dictionary = {}) -> Array:
	var issued: Array = []
	if tick % 5 != 0:
		return issued
	var total_start_usec := Time.get_ticks_usec()
	var gather_start_usec := Time.get_ticks_usec()
	var pairs: Array = command_cache.get("attack_pairs", []) as Array
	if pairs.is_empty():
		pairs = _candidate_attack_pairs(state, cost_profile)
		command_cache["fallback_gathers"] = int(command_cache.get("fallback_gathers", 0)) + 1
	else:
		command_cache["cache_hits"] = int(command_cache.get("cache_hits", 0)) + 1
	_cost_profile_add_stage(cost_profile, "command_gather_candidate_pairs", gather_start_usec)
	var burst := 2
	var intent_start_usec := Time.get_ticks_usec()
	for i in range(mini(burst, pairs.size())):
		var pair: Dictionary = pairs[(tick + i) % pairs.size()] as Dictionary
		var result: Dictionary = OpsState.apply_lane_intent(int(pair.get("src", -1)), int(pair.get("dst", -1)), "attack")
		if bool(result.get("ok", false)):
			issued.append({"type": "attack", "src": pair.get("src", -1), "dst": pair.get("dst", -1)})
	_cost_profile_add_stage(cost_profile, "command_apply_lane_intent", intent_start_usec, mini(burst, pairs.size()))
	if bool(flags.get("combat_visuals", true)):
		var swarm_start_usec := Time.get_ticks_usec()
		var swarm_report: Dictionary = _issue_swarm_on_active_lane(state, tick)
		if bool(swarm_report.get("ok", false)):
			issued.append(swarm_report)
		_cost_profile_add_stage(cost_profile, "command_issue_swarm", swarm_start_usec)
	if arena != null and arena.has_method("mark_render_dirty") and not issued.is_empty():
		var dirty_start_usec := Time.get_ticks_usec()
		arena.call("mark_render_dirty", "rhythmic_lag_scripted")
		_cost_profile_add_stage(cost_profile, "command_mark_render_dirty", dirty_start_usec)
	var total_ms := _cost_profile_add_stage(cost_profile, "command_issue_total", total_start_usec)
	_cost_profile_add_event(cost_profile, {
		"tick": tick,
		"ms": snappedf(total_ms, 0.001),
		"issued_count": issued.size(),
		"candidate_count": pairs.size()
	})
	return issued

func _build_command_cache(state: GameState, cost_profile: Dictionary = {}) -> Dictionary:
	var total_start_usec := Time.get_ticks_usec()
	var pairs_start_usec := Time.get_ticks_usec()
	var pairs: Array = _candidate_attack_pairs(state, cost_profile)
	_cost_profile_add_stage(cost_profile, "command_cache_build_attack_pairs", pairs_start_usec)
	_cost_profile_add_stage(cost_profile, "command_cache_build_total", total_start_usec)
	_cost_profile_add_event(cost_profile, {
		"kind": "command_cache_build",
		"ms": snappedf(float(Time.get_ticks_usec() - total_start_usec) / 1000.0, 0.001),
		"candidate_count": pairs.size()
	})
	return {
		"enabled": true,
		"attack_pairs": pairs,
		"candidate_count": pairs.size(),
		"cache_hits": 0,
		"fallback_gathers": 0
	}

func _command_cache_report(command_cache: Dictionary, enabled: bool) -> Dictionary:
	if not enabled:
		return {"enabled": false, "candidate_count": 0, "cache_hits": 0, "fallback_gathers": 0}
	return {
		"enabled": true,
		"candidate_count": int(command_cache.get("candidate_count", 0)),
		"cache_hits": int(command_cache.get("cache_hits", 0)),
		"fallback_gathers": int(command_cache.get("fallback_gathers", 0))
	}

func _frame_sample(
	frame_index: int,
	delta_ms: float,
	physics_tick_count: int,
	sim_tick_ms: float,
	sim_ticks_this_frame: int,
	update_ms: float,
	render_update_ms: float,
	tick_index: int,
	wall_time_sec: float,
	flags: Dictionary
) -> Dictionary:
	return {
		"frame_index": frame_index,
		"delta_ms": snappedf(delta_ms, 0.001),
		"physics_tick_count": physics_tick_count,
		"sim_tick_ms": snappedf(sim_tick_ms, 0.001),
		"sim_ticks_this_frame": sim_ticks_this_frame,
		"update_ms": snappedf(update_ms, 0.001),
		"render_update_ms_est": snappedf(render_update_ms, 0.001),
		"draw_count": _monitor_value("RENDER_TOTAL_DRAW_CALLS_IN_FRAME"),
		"render_objects": _monitor_value("RENDER_TOTAL_OBJECTS_IN_FRAME"),
		"render_primitives": _monitor_value("RENDER_TOTAL_PRIMITIVES_IN_FRAME"),
		"object_count": _monitor_value("OBJECT_COUNT"),
		"resource_count": _monitor_value("OBJECT_RESOURCE_COUNT"),
		"static_memory_bytes": _monitor_value("MEMORY_STATIC"),
		"tick": tick_index,
		"wall_time_sec": snappedf(wall_time_sec, 0.001),
		"enabled_flags_key": _enabled_flags_key(flags)
	}

func _monitor_value(name: String) -> float:
	if not Performance.has_method("get_monitor"):
		return 0.0
	var constant_name := "MONITOR_%s" % name
	if Performance.has_method("get_monitor"):
		match name:
			"RENDER_TOTAL_DRAW_CALLS_IN_FRAME":
				return float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			"RENDER_TOTAL_OBJECTS_IN_FRAME":
				return float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			"RENDER_TOTAL_PRIMITIVES_IN_FRAME":
				return float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			"OBJECT_COUNT":
				return float(Performance.get_monitor(Performance.OBJECT_COUNT))
			"OBJECT_RESOURCE_COUNT":
				return float(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
			"MEMORY_STATIC":
				return float(Performance.get_monitor(Performance.MEMORY_STATIC))
	return 0.0

func _comparison_for_reports(reports: Array) -> Dictionary:
	var baseline: Dictionary = {}
	for report_any in reports:
		var report: Dictionary = report_any as Dictionary
		if str(report.get("variant_id", "")) == "A_full_game":
			baseline = report
			break
	var rows: Array = []
	var best_reduction: Dictionary = {}
	for report_any in reports:
		var report: Dictionary = report_any as Dictionary
		var row := {
			"variant_id": report.get("variant_id", ""),
			"label": report.get("label", ""),
			"hitch_count": int(report.get("hitch_count", 0)),
			"p99_frame_ms": float(report.get("p99_frame_ms", 0.0)),
			"max_frame_ms": float(report.get("max_frame_ms", 0.0)),
			"hitch_delta_vs_full": 0,
			"p99_delta_vs_full_ms": 0.0,
			"changed_flags": _changed_flags(_default_flags(), report.get("flags", {}) as Dictionary)
		}
		if not baseline.is_empty() and str(report.get("variant_id", "")) != "A_full_game":
			row["hitch_delta_vs_full"] = int(report.get("hitch_count", 0)) - int(baseline.get("hitch_count", 0))
			row["p99_delta_vs_full_ms"] = snappedf(float(report.get("p99_frame_ms", 0.0)) - float(baseline.get("p99_frame_ms", 0.0)), 0.001)
			if best_reduction.is_empty() or int(row.get("hitch_delta_vs_full", 0)) < int(best_reduction.get("hitch_delta_vs_full", 999999)):
				best_reduction = row.duplicate(true)
		rows.append(row)
	return {
		"rows": rows,
		"most_reduced_variant": best_reduction,
		"interpretation": _comparison_interpretation(rows)
	}

func _comparison_interpretation(rows: Array) -> String:
	if rows.size() <= 1:
		return "Only one variant was run; compare against A_full_game for isolation."
	var zero_hitch_labels: Array[String] = []
	for row_any in rows:
		var row: Dictionary = row_any as Dictionary
		if int(row.get("hitch_count", 0)) == 0:
			zero_hitch_labels.append(str(row.get("label", row.get("variant_id", ""))))
	if not zero_hitch_labels.is_empty():
		return "%s removed hitches in this run. Inspect changed_flags for the likely subsystem set." % ", ".join(zero_hitch_labels)
	var best: Dictionary = {}
	for row_any in rows:
		var row: Dictionary = row_any as Dictionary
		if str(row.get("variant_id", "")) == "A_full_game":
			continue
		if best.is_empty() or int(row.get("hitch_delta_vs_full", 0)) < int(best.get("hitch_delta_vs_full", 999999)):
			best = row
	if best.is_empty():
		return "No reduction result available."
	var delta := int(best.get("hitch_delta_vs_full", 0))
	if delta < 0:
		return "%s reduced hitches by %d versus full game. Inspect changed_flags for the likely subsystem set." % [str(best.get("label", "")), abs(delta)]
	if delta == 0:
		return "No variant removed hitches; compare p99/max and hitch periods for subsystem correlation."
	return "Isolation variants increased hitches; rhythmic source may be outside toggled subsystems or setup-sensitive."

func _table_text(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("RHYTHMIC LAG ISOLATION")
	lines.append("variant | hitches | p99 ms | max ms | vs full | changed flags")
	var comparison: Dictionary = report.get("comparison", {}) as Dictionary
	for row_any in comparison.get("rows", []) as Array:
		var row: Dictionary = row_any as Dictionary
		lines.append("%s | %d | %.3f | %.3f | %+d | %s" % [
			str(row.get("label", row.get("variant_id", ""))),
			int(row.get("hitch_count", 0)),
			float(row.get("p99_frame_ms", 0.0)),
			float(row.get("max_frame_ms", 0.0)),
			int(row.get("hitch_delta_vs_full", 0)),
			", ".join(row.get("changed_flags", []) as Array)
		])
	lines.append(str(comparison.get("interpretation", "")))
	for variant_any in report.get("variants", []) as Array:
		var variant: Dictionary = variant_any as Dictionary
		if not variant.has("lane_flow_profile") and not variant.has("unit_flow_profile"):
			continue
		lines.append("")
		lines.append("COST CENTER TIMING: %s" % str(variant.get("label", variant.get("variant_id", ""))))
		_append_profile_lines(lines, "Command Issue", variant.get("command_profile", {}) as Dictionary)
		_append_profile_lines(lines, "Ops Intent", variant.get("ops_intent_profile", {}) as Dictionary)
		_append_profile_lines(lines, "Lane Flow", variant.get("lane_flow_profile", {}) as Dictionary)
		_append_profile_lines(lines, "Unit Flow", variant.get("unit_flow_profile", {}) as Dictionary)
	return "\n".join(lines)

func _append_profile_lines(lines: Array[String], title: String, profile: Dictionary) -> void:
	var stages: Array = profile.get("stages", []) as Array
	if stages.is_empty():
		return
	lines.append("%s" % title)
	lines.append("stage | total ms | calls | avg ms | max ms")
	for i in range(mini(10, stages.size())):
		var stage: Dictionary = stages[i] as Dictionary
		lines.append("%s | %.3f | %d | %.3f | %.3f" % [
			str(stage.get("name", "")),
			float(stage.get("total_ms", 0.0)),
			int(stage.get("calls", 0)),
			float(stage.get("average_ms", 0.0)),
			float(stage.get("max_ms", 0.0))
		])

func _variant_error(variant: Dictionary, reason: String) -> Dictionary:
	return {
		"variant_id": str(variant.get("id", "")),
		"label": str(variant.get("label", "")),
		"flags": (variant.get("flags", {}) as Dictionary).duplicate(true),
		"frame_count": 0,
		"tick_count": 0,
		"average_frame_ms": 0.0,
		"p95_frame_ms": 0.0,
		"p99_frame_ms": 0.0,
		"max_frame_ms": 0.0,
		"hitch_count": 0,
		"hitches": [],
		"worst_frames": [],
		"frame_samples": [],
		"error": reason
	}

func _candidate_attack_pairs(state: GameState, cost_profile: Dictionary = {}) -> Array:
	var total_start_usec := Time.get_ticks_usec()
	var pairs: Array = []
	if state == null:
		return pairs
	var source_scan_start_usec := Time.get_ticks_usec()
	var source_count := 0
	var destination_count := 0
	var can_connect_calls := 0
	for src_any in state.hives:
		var src: HiveData = src_any as HiveData
		if src == null or int(src.owner_id) <= 0:
			continue
		source_count += 1
		for dst_any in state.hives:
			var destination_start_usec := Time.get_ticks_usec()
			var dst: HiveData = dst_any as HiveData
			if dst == null or int(dst.id) == int(src.id):
				_cost_profile_add_stage(cost_profile, "candidate_destination_filter", destination_start_usec)
				continue
			destination_count += 1
			_cost_profile_add_stage(cost_profile, "candidate_destination_filter", destination_start_usec)
			var can_connect_start_usec := Time.get_ticks_usec()
			can_connect_calls += 1
			if not state.can_connect(int(src.id), int(dst.id)):
				_cost_profile_add_stage(cost_profile, "candidate_state_can_connect", can_connect_start_usec)
				continue
			_cost_profile_add_stage(cost_profile, "candidate_state_can_connect", can_connect_start_usec)
			var append_start_usec := Time.get_ticks_usec()
			pairs.append({"src": int(src.id), "dst": int(dst.id), "dist2": _grid_distance_squared(src.grid_pos, dst.grid_pos)})
			_cost_profile_add_stage(cost_profile, "candidate_append_pair", append_start_usec)
	_cost_profile_add_stage(cost_profile, "candidate_source_enumeration", source_scan_start_usec, source_count)
	var sort_start_usec := Time.get_ticks_usec()
	pairs.sort_custom(Callable(self, "_sort_candidate_pair_by_distance"))
	_cost_profile_add_stage(cost_profile, "candidate_sort_pairs", sort_start_usec)
	_cost_profile_add_stage(cost_profile, "candidate_total", total_start_usec)
	_cost_profile_add_event(cost_profile, {
		"kind": "candidate_attack_pairs",
		"ms": snappedf(float(Time.get_ticks_usec() - total_start_usec) / 1000.0, 0.001),
		"sources": source_count,
		"destinations": destination_count,
		"can_connect_calls": can_connect_calls,
		"pairs": pairs.size()
	})
	return pairs

func _issue_swarm_on_active_lane(state: GameState, salt: int) -> Dictionary:
	if state == null:
		return {"ok": false, "type": "swarm"}
	var candidates: Array = []
	for lane_any in state.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		if bool(lane.send_a):
			candidates.append({"src": int(lane.a_id), "dst": int(lane.b_id)})
		if bool(lane.send_b):
			candidates.append({"src": int(lane.b_id), "dst": int(lane.a_id)})
	if candidates.is_empty():
		return {"ok": false, "type": "swarm"}
	var pair: Dictionary = candidates[abs(salt) % candidates.size()] as Dictionary
	var result: Dictionary = OpsState.apply_lane_intent(int(pair.get("src", -1)), int(pair.get("dst", -1)), "swarm")
	return {"ok": bool(result.get("ok", false)), "type": "swarm", "src": pair.get("src", -1), "dst": pair.get("dst", -1)}

func _frame_metrics(values: Array) -> Dictionary:
	return {
		"average_frame_ms": _avg(values),
		"p95_frame_ms": _percentile(values, 0.95),
		"p99_frame_ms": _percentile(values, 0.99),
		"max_frame_ms": _max(values)
	}

func _cost_profile_add_stage(profile: Dictionary, stage_name: String, start_usec: int, calls: int = 1) -> float:
	if profile.is_empty():
		return 0.0
	var ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
	var totals: Dictionary = profile.get("totals", {}) as Dictionary
	var total: Dictionary = totals.get(stage_name, {"ms": 0.0, "calls": 0, "max_ms": 0.0}) as Dictionary
	total["ms"] = float(total.get("ms", 0.0)) + ms
	total["calls"] = int(total.get("calls", 0)) + calls
	total["max_ms"] = maxf(float(total.get("max_ms", 0.0)), ms)
	totals[stage_name] = total
	profile["totals"] = totals
	return ms

func _cost_profile_add_event(profile: Dictionary, event: Dictionary) -> void:
	if profile.is_empty():
		return
	var events: Array = profile.get("events", []) as Array
	events.append(event)
	if events.size() > 2048:
		events.pop_front()
	profile["events"] = events

func _cost_profile_report(profile: Dictionary) -> Dictionary:
	var stages: Array = []
	var totals: Dictionary = profile.get("totals", {}) as Dictionary
	for stage_name in totals.keys():
		var total: Dictionary = totals.get(stage_name, {}) as Dictionary
		var calls := int(total.get("calls", 0))
		var ms := float(total.get("ms", 0.0))
		stages.append({
			"name": str(stage_name),
			"total_ms": snappedf(ms, 0.001),
			"calls": calls,
			"average_ms": snappedf(ms / maxf(1.0, float(calls)), 0.001),
			"max_ms": snappedf(float(total.get("max_ms", 0.0)), 0.001)
		})
	stages.sort_custom(Callable(self, "_sort_profile_stage_by_total_ms_desc"))
	var events: Array = profile.get("events", []) as Array
	var worst_events := events.duplicate(true)
	worst_events.sort_custom(Callable(self, "_sort_profile_event_by_ms_desc"))
	return {
		"event_count": events.size(),
		"stages": stages,
		"worst_events": worst_events.slice(0, mini(12, worst_events.size()))
	}

func _frame_deltas(samples: Array) -> Array:
	var out: Array = []
	for sample_any in samples:
		var sample: Dictionary = sample_any as Dictionary
		out.append(float(sample.get("delta_ms", 0.0)))
	return out

func _worst_frames(samples: Array, limit: int) -> Array:
	var out: Array = samples.duplicate(true)
	out.sort_custom(Callable(self, "_sort_frame_sample_by_delta_ms_desc"))
	return out.slice(0, mini(limit, out.size()))

func _sort_candidate_pair_by_distance(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("dist2", 0)) < int(b.get("dist2", 0))

func _sort_profile_stage_by_total_ms_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("total_ms", 0.0)) > float(b.get("total_ms", 0.0))

func _sort_profile_event_by_ms_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("ms", 0.0)) > float(b.get("ms", 0.0))

func _sort_frame_sample_by_delta_ms_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("delta_ms", 0.0)) > float(b.get("delta_ms", 0.0))

func _rhythmic_hitch_summary(hitches: Array) -> Dictionary:
	if hitches.size() < 2:
		return {"hitch_count": hitches.size(), "period_frames_avg": 0.0, "period_ms_avg": 0.0, "uniformity_cv": 0.0}
	var frame_periods: Array = []
	var time_periods: Array = []
	for i in range(1, hitches.size()):
		var prev: Dictionary = hitches[i - 1] as Dictionary
		var cur: Dictionary = hitches[i] as Dictionary
		frame_periods.append(float(cur.get("frame_index", 0)) - float(prev.get("frame_index", 0)))
		time_periods.append((float(cur.get("wall_time_sec", 0.0)) - float(prev.get("wall_time_sec", 0.0))) * 1000.0)
	return {
		"hitch_count": hitches.size(),
		"period_frames_avg": _avg(frame_periods),
		"period_ms_avg": _avg(time_periods),
		"uniformity_cv": _coefficient_of_variation(time_periods)
	}

func _changed_flags(base: Dictionary, current: Dictionary) -> Array:
	var out: Array = []
	var keys: Array = current.keys()
	keys.sort()
	for key_any in keys:
		var key := str(key_any)
		if base.has(key) and base[key] == current[key]:
			continue
		out.append("%s=%s" % [key, str(current[key])])
	return out

func _enabled_flags_key(flags: Dictionary) -> String:
	var enabled: Array[String] = []
	var keys: Array = flags.keys()
	keys.sort()
	for key_any in keys:
		var key := str(key_any)
		if bool(flags.get(key, false)):
			enabled.append(key)
	return ",".join(enabled)

func _scripted_command_count(command_log: Array) -> int:
	var count := 0
	for entry_any in command_log:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		count += (entry.get("commands", []) as Array).size()
	return count

func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value_any in values:
		total += float(value_any)
	return total / float(values.size())

func _max(values: Array) -> float:
	var out := 0.0
	for value_any in values:
		out = maxf(out, float(value_any))
	return out

func _percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var index: int = clampi(int(ceil(percentile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return float(sorted[index])

func _coefficient_of_variation(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var avg := _avg(values)
	if avg <= 0.000001:
		return 0.0
	var sum_sq := 0.0
	for value_any in values:
		var d := float(value_any) - avg
		sum_sq += d * d
	return sqrt(sum_sq / float(values.size())) / avg

func _grid_distance_squared(a: Vector2i, b: Vector2i) -> int:
	var dx := int(a.x - b.x)
	var dy := int(a.y - b.y)
	return dx * dx + dy * dy

func _find_arena(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	var direct: Node = scene_root.get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
	if direct != null:
		return direct
	return scene_root.find_child("Arena", true, false)

func _arena_sim_runner(arena: Node) -> Node:
	if arena == null:
		return null
	var direct: Node = arena.get_node_or_null("SimRunner")
	if direct != null:
		return direct
	var value: Variant = arena.get("sim_runner") if "sim_runner" in arena else null
	return value as Node

func _hide_paths(root_node: Node, paths: Array[String]) -> void:
	if root_node == null:
		return
	for path in paths:
		var node: CanvasItem = root_node.get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = false

func _install_synthetic_floor_overlay(arena: Node, config: Dictionary) -> void:
	if arena == null:
		return
	var parent: Node = arena.get_node_or_null("MapRoot")
	if parent == null:
		parent = arena
	var existing: Node = parent.get_node_or_null("SyntheticFloorOverlayProbe")
	if existing != null:
		existing.queue_free()
	var probe := SyntheticFloorOverlayProbe.new()
	probe.name = "SyntheticFloorOverlayProbe"
	probe.configure(config)
	parent.add_child(probe)

func _hide_nodes_named(root_node: Node, fragments: Array[String]) -> void:
	if root_node == null:
		return
	for node_any in root_node.find_children("*", "", true, false):
		var node: Node = node_any as Node
		if node == null:
			continue
		for fragment in fragments:
			if node.name.findn(fragment) != -1 and node is CanvasItem:
				(node as CanvasItem).visible = false
				break

func _disable_nodes_named(root_node: Node, fragments: Array[String]) -> void:
	if root_node == null:
		return
	for node_any in root_node.find_children("*", "", true, false):
		var node: Node = node_any as Node
		if node == null:
			continue
		for fragment in fragments:
			if node.name.findn(fragment) != -1:
				node.set_process(false)
				node.set_physics_process(false)
				break

func _disable_nodes_by_class(root_node: Node, class_names: Array[String]) -> void:
	if root_node == null:
		return
	for node_any in root_node.find_children("*", "", true, false):
		var node: Node = node_any as Node
		if node == null:
			continue
		if class_names.has(node.get_class()):
			node.set_process(false)
			node.set_physics_process(false)

func _set_canvas_or_control_visible(root_node: Node, node_name: String, visible: bool) -> void:
	if root_node == null:
		return
	for node_any in root_node.find_children(node_name, "", true, false):
		var node: Node = node_any as Node
		if node is CanvasItem:
			(node as CanvasItem).visible = visible

func _mute_audio() -> void:
	_audio_mute_snapshot.clear()
	var count := AudioServer.get_bus_count()
	for i in range(count):
		_audio_mute_snapshot[i] = AudioServer.is_bus_mute(i)
		AudioServer.set_bus_mute(i, true)

func _restore_audio() -> void:
	for key_any in _audio_mute_snapshot.keys():
		AudioServer.set_bus_mute(int(key_any), bool(_audio_mute_snapshot[key_any]))
	_audio_mute_snapshot.clear()

func _teardown_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()

func _parse_args() -> Dictionary:
	var out := {"duration_sec": DEFAULT_DURATION_SEC, "output": DEFAULT_OUTPUT_PATH, "map": DEFAULT_MAP, "variant": "", "group": "baseline"}
	var args := _cmdline_args()
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		if arg.begins_with("--duration="):
			out["duration_sec"] = float(arg.trim_prefix("--duration="))
		elif arg == "--duration" and i + 1 < args.size():
			i += 1
			out["duration_sec"] = float(str(args[i]))
		elif arg.begins_with("--output="):
			out["output"] = arg.trim_prefix("--output=")
		elif arg == "--output" and i + 1 < args.size():
			i += 1
			out["output"] = str(args[i])
		elif arg.begins_with("--map="):
			out["map"] = arg.trim_prefix("--map=")
		elif arg == "--map" and i + 1 < args.size():
			i += 1
			out["map"] = str(args[i])
		elif arg.begins_with("--variant="):
			out["variant"] = arg.trim_prefix("--variant=")
		elif arg == "--variant" and i + 1 < args.size():
			i += 1
			out["variant"] = str(args[i])
		elif arg.begins_with("--group="):
			out["group"] = arg.trim_prefix("--group=")
		elif arg == "--group" and i + 1 < args.size():
			i += 1
			out["group"] = str(args[i])
		i += 1
	return out

func _cmdline_args() -> PackedStringArray:
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		return user_args
	return OS.get_cmdline_args()

func _write_json(path: String, data: Dictionary) -> void:
	var dir_path := path.get_base_dir()
	if dir_path.begins_with("res://") or dir_path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("rhythmic_lag_isolation: failed to write %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))

func _git_metadata() -> Dictionary:
	return {
		"commit": _read_process(["git", "rev-parse", "--short", "HEAD"]).strip_edges(),
		"branch": _read_process(["git", "rev-parse", "--abbrev-ref", "HEAD"]).strip_edges(),
		"dirty": not _read_process(["git", "status", "--porcelain"]).strip_edges().is_empty()
	}

func _machine_metadata() -> Dictionary:
	return {
		"os": OS.get_name(),
		"processor_count": OS.get_processor_count(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"headless": DisplayServer.get_name() == "headless"
	}

func _read_process(args: Array) -> String:
	if args.is_empty():
		return ""
	var executable := str(args[0])
	var proc_args: PackedStringArray = PackedStringArray()
	for i in range(1, args.size()):
		proc_args.append(str(args[i]))
	var output: Array = []
	var rc := OS.execute(executable, proc_args, output, true, false)
	if rc != 0:
		return ""
	return "\n".join(output)
