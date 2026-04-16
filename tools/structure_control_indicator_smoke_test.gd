extends SceneTree

const Indicator := preload("res://scripts/renderers/structure_control_indicator.gd")

class IndicatorDrawer:
	extends Node2D

	var segment_count: int = 0

	func _draw() -> void:
		var structure := {
			"id": 1,
			"owner_id": 1,
			"active": true,
			"is_controlled": true,
			"control_hive_ids": [2, 11, 12]
		}
		var hives_by_id := {
			2: {"owner_id": 1, "world_pos": Vector2(80.0, 80.0)},
			11: {"owner_id": 1, "world_pos": Vector2(100.0, 28.0)},
			12: {"owner_id": 1, "world_pos": Vector2(132.0, 92.0)}
		}
		segment_count = Indicator.draw_control_collar(
			self,
			Vector2(120.0, 120.0),
			structure,
			hives_by_id,
			"tower"
		)

func _init() -> void:
	var drawer := IndicatorDrawer.new()
	root.add_child(drawer)
	drawer.queue_redraw()
	await process_frame
	await process_frame
	if drawer.segment_count != 3:
		push_error("STRUCTURE_CONTROL_INDICATOR_SMOKE: expected 3 segments, got %d" % drawer.segment_count)
		quit(1)
		return
	print("STRUCTURE_CONTROL_INDICATOR_SMOKE: PASS segments=%d" % drawer.segment_count)
	quit(0)
