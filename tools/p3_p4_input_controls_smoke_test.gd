extends SceneTree

const InputEventUtils := preload("res://scripts/systems/input_helpers/input_event_utils.gd")
const ArenaInputBridgeUtils := preload("res://scripts/arena_helpers/input_bridge_utils.gd")

var _failed: bool = false
var _active_player_id: int = 1

func _initialize() -> void:
	var bridge := ArenaInputBridgeUtils.new()
	_expect_eq(InputEventUtils.player_id_for_dev_pointer_button(MOUSE_BUTTON_LEFT), 1, "left mouse should map to P1")
	_expect_eq(InputEventUtils.player_id_for_dev_pointer_button(MOUSE_BUTTON_RIGHT), 2, "right mouse should map to P2")
	_expect_eq(InputEventUtils.player_id_for_dev_pointer_button(MOUSE_BUTTON_MIDDLE), 3, "middle mouse should map to P3")
	_expect_eq(InputEventUtils.player_id_for_dev_pointer_button(8), 4, "side mouse button 1 should map to P4")
	_expect_eq(InputEventUtils.player_id_for_dev_pointer_button(9), 4, "side mouse button 2 should map to P4")
	_expect_true(InputEventUtils.is_player_pointer_button(MOUSE_BUTTON_MIDDLE), "input system should accept P3 pointer button")
	_expect_true(InputEventUtils.is_player_pointer_button(8), "input system should accept P4 pointer button")
	_expect_eq(bridge.player_id_for_dev_pointer_button(MOUSE_BUTTON_LEFT), 1, "arena bridge left mouse should map to P1")
	_expect_eq(bridge.player_id_for_dev_pointer_button(MOUSE_BUTTON_RIGHT), 2, "arena bridge right mouse should map to P2")
	_expect_eq(bridge.player_id_for_dev_pointer_button(MOUSE_BUTTON_MIDDLE), 3, "arena bridge middle mouse should map to P3")
	_expect_eq(bridge.player_id_for_dev_pointer_button(8), 4, "arena bridge side mouse should map to P4")
	_active_player_id = 3
	_expect_eq(InputEventUtils.player_id_from_button(MOUSE_BUTTON_LEFT, self, -1), 3, "left mouse should follow active P3")
	_active_player_id = 4
	_expect_eq(InputEventUtils.player_id_from_button(MOUSE_BUTTON_LEFT, self, -1), 4, "left mouse should follow active P4")
	if not _failed:
		print("P3_P4_INPUT_CONTROLS_SMOKE: PASS")
	quit(1 if _failed else 0)

func get_active_player_id() -> int:
	return _active_player_id

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("P3_P4_INPUT_CONTROLS_SMOKE: %s" % message)

func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("P3_P4_INPUT_CONTROLS_SMOKE: %s actual=%s expected=%s" % [message, str(actual), str(expected)])
