extends SceneTree

func _init() -> void:
	var state := GameState.new()
	state.init_core_defaults()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 10, "Hive"),
		HiveData.new(2, Vector2i(3, 0), 2, 10, "Hive"),
		HiveData.new(3, Vector2i(6, 0), 0, 10, "Hive")
	]
	state.rebuild_indexes()

	state.mark_hive_attacked_for_passive_suppression(1)
	state._apply_passive_tick(1, 1)
	_assert_eq(int(state.hives[0].power), 10, "attacked hive should not gain passive power")
	_assert_eq(int(state.hives[1].power), 11, "idle owned hive should still gain passive power")
	_assert_eq(int(state.hives[2].power), 10, "NPC hive should not gain passive power")

	state.passive_power_block_until_ms_by_hive[1] = Time.get_ticks_msec() + 1
	var before_until: int = int(state.passive_power_block_until_ms_by_hive.get(1, 0))
	state.mark_hive_attacked_for_passive_suppression(1)
	var after_until: int = int(state.passive_power_block_until_ms_by_hive.get(1, 0))
	_assert_true(after_until > before_until, "new attack should refresh passive suppression timer")

	if _failed:
		quit(1)
		return
	print("PASSIVE_ATTACK_SUPPRESSION_SMOKE: PASS")
	quit(0)

var _failed: bool = false

func _assert_eq(actual: int, expected: int, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("%s expected=%d actual=%d" % [message, expected, actual])

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error(message)
