class_name UIButton
extends Button

const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const SFLog := preload("res://scripts/util/sf_log.gd")

@export var bg_key_normal: String = ""
@export var bg_key_hover: String = ""
@export var bg_key_pressed: String = ""
@export var bg_key_disabled: String = ""
@export var skin_material: Material = null

func _ready() -> void:
	apply_skin()

func apply_skin() -> void:
	if bg_key_normal.is_empty():
		return
	var registry := SpriteRegistry.get_instance()
	if registry == null:
		return
	var tex: Texture2D = registry.get_tex(bg_key_normal)
	SFLog.log_once(
		"UI_BTN_SKIN_TEX:" + str(get_path()),
		"UI_BTN_SKIN_TEX",
		SFLog.Level.INFO,
		{
			"node": str(get_path()),
			"key": bg_key_normal,
			"ok_tex": tex != null,
			"tex_size": tex.get_size() if tex != null else Vector2.ZERO
		}
	)
	if tex == null:
		text = "[MISSING]"
		return
	var skin_tex := get_node_or_null("SkinTex") as TextureRect
	if skin_tex == null:
		skin_tex = TextureRect.new()
		skin_tex.name = "SkinTex"
		skin_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skin_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		skin_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skin_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		skin_tex.stretch_mode = TextureRect.STRETCH_SCALE
		skin_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(skin_tex)
	skin_tex.material = skin_material if skin_material != null else null
	skin_tex.texture = tex
	text = ""
	flat = true
