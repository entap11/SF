class_name CosmeticThemeDB
extends RefCounted

const THEME_BASE: String = "base"
const THEME_UPGRADED: String = "upgraded"
const THEME_UPGRADED_DYNAMIC: String = "upgraded_dynamic"
const THEME_UPGRADED_BOIL: String = "upgraded_boil"

const BASE_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/power_bar_unfilled.png"
const UPGRADED_TEXTURE_PATH: String = "res://assets/ui/powerbar/power_bar_4p_upgraded.png"
const DYNAMIC_SHADER_PATH: String = "res://assets/shaders/power_bar_theme_dynamic.gdshader"
const BOIL_SHADER_PATH: String = "res://assets/shaders/power_bar_theme_boil.gdshader"

static var _powerbar_themes: Dictionary = {
	THEME_BASE: {
		"texture": BASE_TEXTURE_PATH,
		"shader": "",
		"animated": false
	},
	THEME_UPGRADED: {
		"texture": UPGRADED_TEXTURE_PATH,
		"shader": "",
		"animated": false
	},
	THEME_UPGRADED_DYNAMIC: {
		"texture": UPGRADED_TEXTURE_PATH,
		"shader": DYNAMIC_SHADER_PATH,
		"animated": true
	},
	THEME_UPGRADED_BOIL: {
		"texture": UPGRADED_TEXTURE_PATH,
		"shader": BOIL_SHADER_PATH,
		"animated": true
	}
}
static var _texture_cache: Dictionary = {}

static func normalize_powerbar_theme(theme_id: String) -> String:
	var clean: String = theme_id.strip_edges().to_lower()
	match clean:
		"", THEME_BASE:
			return THEME_BASE
		"upgraded_static", THEME_UPGRADED:
			return THEME_UPGRADED
		THEME_UPGRADED_DYNAMIC:
			return THEME_UPGRADED_DYNAMIC
		THEME_UPGRADED_BOIL:
			return THEME_UPGRADED_BOIL
		_:
			return THEME_BASE

static func get_powerbar_texture(theme_id: String) -> Texture2D:
	var clean_theme: String = normalize_powerbar_theme(theme_id)
	var def: Dictionary = _powerbar_themes.get(clean_theme, _powerbar_themes[THEME_BASE]) as Dictionary
	var path: String = str(def.get("texture", BASE_TEXTURE_PATH))
	var texture: Texture2D = _load_texture(path)
	if texture != null:
		return texture
	if clean_theme == THEME_BASE:
		return null
	return _load_texture(BASE_TEXTURE_PATH)

static func get_powerbar_shader(theme_id: String) -> Shader:
	var clean_theme: String = normalize_powerbar_theme(theme_id)
	var def: Dictionary = _powerbar_themes.get(clean_theme, _powerbar_themes[THEME_BASE]) as Dictionary
	var path: String = str(def.get("shader", ""))
	if path == "":
		return null
	var resource: Variant = load(path)
	if resource is Shader:
		return resource as Shader
	return null

static func is_powerbar_animated(theme_id: String) -> bool:
	var clean_theme: String = normalize_powerbar_theme(theme_id)
	var def: Dictionary = _powerbar_themes.get(clean_theme, _powerbar_themes[THEME_BASE]) as Dictionary
	return bool(def.get("animated", false))

static func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache.get(path) as Texture2D
	var texture: Texture2D = null
	if FileAccess.file_exists(path + ".import"):
		var imported: Variant = load(path)
		if imported is Texture2D:
			texture = imported as Texture2D
	if texture == null and FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	if texture != null:
		_texture_cache[path] = texture
	return texture
