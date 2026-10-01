class_name SelectionState
extends RefCounted

var selected_cell: Vector2i = Vector2i(-1, -1)
var selected_hive_id: int = -1
var selected_lane_id: int = -1
var active_player_id: int = 1
var tap_first_id: int = -1
var tap_first_owner_id: int = -1
var tap_dev_pid: int = -1
var drag_active: bool = false
var drag_start_hive_id: int = -1
var drag_start_owner_id: int = -1
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_current_pos: Vector2 = Vector2.ZERO
var drag_hover_hive_id: int = -1
var drag_hover_valid: bool = false
var drag_hover_reason: String = ""
var drag_moved: bool = false
var last_vibe_target_id: int = -1
var drag_dev_pid: int = -1

func clear_tap_state() -> void:
	tap_first_id = -1
	tap_first_owner_id = -1
	tap_dev_pid = -1

func set_active_player_id(pid: int) -> void:
	active_player_id = clampi(pid, 1, 4)

func clear_selection() -> void:
	selected_hive_id = -1
	selected_lane_id = -1

func reset_drag() -> void:
	drag_active = false
	drag_start_hive_id = -1
	drag_start_owner_id = -1
	drag_hover_hive_id = -1
	drag_hover_valid = false
	drag_hover_reason = ""
	drag_moved = false
	last_vibe_target_id = -1
	drag_dev_pid = -1


const CHECKPOINT_FIELDS = [
	"selected_cell",
	"selected_hive_id",
	"selected_lane_id",
	"active_player_id",
	"tap_first_id",
	"tap_first_owner_id",
	"tap_dev_pid",
]

func capture_checkpoint() -> Dictionary:
	return preload("res://scripts/persistence/checkpoint_fields.gd").capture(self, CHECKPOINT_FIELDS)

func restore_checkpoint(saved: Dictionary) -> void:
	reset_drag()
	preload("res://scripts/persistence/checkpoint_fields.gd").restore(self, CHECKPOINT_FIELDS, saved)
