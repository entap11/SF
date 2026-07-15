extends SceneTree

const BuffDefinitions := preload("res://scripts/state/buff_definitions.gd")
const BuffCatalog := preload("res://scripts/state/buff_catalog.gd")

var _failed: bool = false

func _init() -> void:
	var ids: PackedStringArray = BuffDefinitions.list_all_ids()
	_expect(ids.size() == 12, "catalog has exactly twelve active mechanics")
	_expect(not ids.has("STEAL_LANE"), "Steal Lane is absent from active definitions")
	_expect(ids.has(BuffDefinitions.HIVE_GLOBAL_SHOCK_IMMUNITY), "Global Shock Immunity is active")
	_expect(BuffDefinitions.target_type_for(BuffDefinitions.HIVE_SUPERCHARGE_QUEUE) == BuffDefinitions.TARGET_LANE, "Supercharge targets a lane")
	_expect(BuffDefinitions.duration_seconds_for(BuffDefinitions.HIVE_SUPERCHARGE_QUEUE, "classic") == 5.0, "classic Supercharge lasts five seconds")
	_expect(BuffDefinitions.duration_seconds_for(BuffDefinitions.HIVE_SUPERCHARGE_QUEUE, "premium") == 7.0, "premium Supercharge lasts seven seconds")
	_expect(BuffDefinitions.duration_seconds_for(BuffDefinitions.HIVE_SUPERCHARGE_QUEUE, "elite") == 9.0, "elite Supercharge lasts nine seconds")
	_expect(float(BuffDefinitions.effect_payload_for(BuffDefinitions.UNIT_SWARM_DAMAGE).get("swarm_combat_damage_mult", 0.0)) == 2.0, "Swarm Damage is exactly two times")
	var retired: Dictionary = BuffCatalog.get_buff("buff_steal_lane_classic")
	_expect(not retired.is_empty() and bool(retired.get("retired", false)), "legacy Steal Lane inventory has a tombstone")
	_expect(not BuffCatalog.is_selectable("buff_steal_lane_classic"), "legacy Steal Lane cannot be selected")
	_expect(not (BuffCatalog.list_all() as Array).any(func(entry: Dictionary) -> bool: return str(entry.get("canonical_id", "")) == "STEAL_LANE"), "retired Steal Lane is not listed")
	if _failed:
		quit(1)
		return
	print("BUFF_MECHANICS_CONTRACT_SMOKE: PASS")
	quit(0)

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_MECHANICS_CONTRACT_SMOKE: %s" % label)
