extends SceneTree

const MIN_CANVAS_Z_INDEX: int = -4096
const MAX_CANVAS_Z_INDEX: int = 4095
const SCAN_ROOTS: Array[String] = ["res://scripts", "res://scenes"]

var _failed: bool = false
var _regex := RegEx.new()

func _initialize() -> void:
	await process_frame
	var err: Error = _regex.compile("z_index\\s*=\\s*(-?\\d+)")
	if err != OK:
		_fail("could not compile z-index scanner regex")
		quit(1)
		return
	for root in SCAN_ROOTS:
		_scan_dir(root)
	if not _failed:
		print("CANVAS_Z_INDEX_BOUNDS_SMOKE: PASS")
	quit(1 if _failed else 0)

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_fail("could not open %s" % path)
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var child_path := "%s/%s" % [path, name]
		if dir.current_is_dir():
			_scan_dir(child_path)
		elif name.ends_with(".gd") or name.ends_with(".tscn"):
			_scan_file(child_path)
	dir.list_dir_end()

func _scan_file(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return
	var matches := _regex.search_all(source)
	for match_result in matches:
		var value := int(match_result.get_string(1))
		if value < MIN_CANVAS_Z_INDEX or value > MAX_CANVAS_Z_INDEX:
			_fail("%s has z_index=%d outside [%d, %d]" % [path, value, MIN_CANVAS_Z_INDEX, MAX_CANVAS_Z_INDEX])

func _fail(message: String) -> void:
	_failed = true
	push_error("CANVAS_Z_INDEX_BOUNDS_SMOKE: %s" % message)
