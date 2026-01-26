extends Control
class_name MapRefViewer

const REFS_DIR := "res://art/map_refs"
const VALID_EXT := ["png", "jpg", "jpeg", "webp"]

@onready var texture_rect: TextureRect = $Panel/VBox/Texture
@onready var label: Label = $Panel/VBox/Label

var image_paths: Array[String] = []
var index := 0

func _ready() -> void:
	if not OS.is_debug_build():
		visible = false
		set_process_unhandled_input(false)
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_list()
	visible = false
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F2:
				_toggle_viewer()
			KEY_ESCAPE:
				if visible:
					visible = false
			KEY_RIGHT, KEY_DOWN, KEY_PAGEDOWN:
				if visible:
					_next_image()
			KEY_LEFT, KEY_UP, KEY_PAGEUP:
				if visible:
					_prev_image()

func _toggle_viewer() -> void:
	visible = not visible
	if visible:
		_refresh_list()

func _refresh_list() -> void:
	image_paths.clear()
	var dir := DirAccess.open(REFS_DIR)
	if dir == null:
		label.text = "No map refs folder: %s" % REFS_DIR
		texture_rect.texture = null
		return
	for file_name in dir.get_files():
		var ext := file_name.get_extension().to_lower()
		if not VALID_EXT.has(ext):
			continue
		image_paths.append("%s/%s" % [REFS_DIR, file_name])
	image_paths.sort()
	index = clamp(index, 0, max(image_paths.size() - 1, 0))
	_show_current()

func _show_current() -> void:
	if image_paths.is_empty():
		label.text = "No map refs found in %s" % REFS_DIR
		texture_rect.texture = null
		return
	var path := image_paths[index]
	var tex := load(path)
	texture_rect.texture = tex
	label.text = "%d/%d  %s" % [index + 1, image_paths.size(), path.get_file()]

func _next_image() -> void:
	if image_paths.is_empty():
		return
	index = (index + 1) % image_paths.size()
	_show_current()

func _prev_image() -> void:
	if image_paths.is_empty():
		return
	index = (index - 1 + image_paths.size()) % image_paths.size()
	_show_current()
