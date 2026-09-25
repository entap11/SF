extends Container
## Non-overlapping five-choice clusters. Presentation only; native buttons own input.
const ROW_HEIGHT := 188.0
const GAP := 12.0
var arrangement := "2-1-2":
	set(value):
		arrangement = value
		update_minimum_size()
		queue_sort()

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _buttons() -> Array[Control]:
	var result: Array[Control] = []
	for child in get_children():
		if child is Control and child.visible and not child.is_queued_for_deletion():
			result.append(child)
	return result

func _row_counts(count: int) -> Array:
	if count == 0:
		return []
	if arrangement == "3-2":
		return [count] if count <= 3 else [3, count - 3]
	match count:
		1: return [1]
		2: return [2]
		3: return [2, 1]
		4: return [2, 2]
		_: return [2, 1, 2]

func _get_minimum_size() -> Vector2:
	var rows := _row_counts(_buttons().size()).size()
	return Vector2(0, rows * _row_height() + maxi(0, rows - 1) * GAP)

func _row_height() -> float:
	var height := 232.0 if arrangement == "3-2" else ROW_HEIGHT
	for button in _buttons():
		height = maxf(height, button.get_combined_minimum_size().y)
	return height

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var buttons := _buttons()
	var rows := _row_counts(buttons.size())
	if rows.is_empty():
		return
	# Share spare vertical space per row, keeping small and large clusters balanced.
	size_flags_stretch_ratio = float(rows.size())
	var height := maxf(_row_height(), (size.y - GAP * (rows.size() - 1)) / rows.size())
	var columns := 3 if arrangement == "3-2" else 2
	var width := (size.x - GAP * (columns - 1)) / columns
	var index := 0
	for row in range(rows.size()):
		var count := int(rows[row])
		var left := (size.x - count * width - (count - 1) * GAP) * 0.5
		for column in range(count):
			fit_child_in_rect(buttons[index], Rect2(left + column * (width + GAP), row * (height + GAP), width, height))
			index += 1
