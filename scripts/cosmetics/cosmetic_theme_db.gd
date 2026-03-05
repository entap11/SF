class_name CosmeticThemeDB
extends RefCounted

const THEME_BASE: String = "base"
const THEME_UPGRADED: String = "upgraded"
const THEME_UPGRADED_DYNAMIC: String = "upgraded_dynamic"
const THEME_UPGRADED_BOIL: String = "upgraded_boil"

const BASE_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/power_bar_unfilled.png"
const UPGRADED_TEXTURE_PATH: String = "res://assets/ui/powerbar/power_bar_4p_upgraded.png"
const UPGRADED_2P_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/2p_powerbar_float.png"
const UPGRADED_3P_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/3p_powerbar_dynamic.png"
const DYNAMIC_SHADER_PATH: String = "res://assets/shaders/power_bar_theme_dynamic.gdshader"
const BOIL_SHADER_PATH: String = "res://assets/shaders/power_bar_theme_boil.gdshader"

static var _powerbar_themes: Dictionary = {
	THEME_BASE: {
		"texture": BASE_TEXTURE_PATH,
		"textures_by_player_count": {},
		"shader": "",
		"animated": false
	},
	THEME_UPGRADED: {
		"texture": UPGRADED_TEXTURE_PATH,
		"textures_by_player_count": {2: UPGRADED_2P_TEXTURE_PATH, 3: UPGRADED_3P_TEXTURE_PATH},
		"shader": "",
		"animated": false
	},
	THEME_UPGRADED_DYNAMIC: {
		"texture": UPGRADED_TEXTURE_PATH,
		"textures_by_player_count": {2: UPGRADED_2P_TEXTURE_PATH, 3: UPGRADED_3P_TEXTURE_PATH},
		"shader": DYNAMIC_SHADER_PATH,
		"animated": true
	},
	THEME_UPGRADED_BOIL: {
		"texture": UPGRADED_TEXTURE_PATH,
		"textures_by_player_count": {2: UPGRADED_2P_TEXTURE_PATH, 3: UPGRADED_3P_TEXTURE_PATH},
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

static func get_powerbar_texture(theme_id: String, player_count: int = 0) -> Texture2D:
	var clean_theme: String = normalize_powerbar_theme(theme_id)
	var def: Dictionary = _powerbar_themes.get(clean_theme, _powerbar_themes[THEME_BASE]) as Dictionary
	var path: String = _resolve_texture_path(def, player_count)
	var texture: Texture2D = _load_texture(path)
	if texture != null:
		return texture
	if clean_theme == THEME_BASE:
		return null
	return _load_texture(_resolve_texture_path(_powerbar_themes[THEME_BASE] as Dictionary, player_count))

static func _resolve_texture_path(def: Dictionary, player_count: int) -> String:
	var default_path: String = str(def.get("texture", BASE_TEXTURE_PATH))
	var by_count: Dictionary = def.get("textures_by_player_count", {}) as Dictionary
	if by_count.is_empty():
		return default_path
	var count: int = clampi(player_count, 2, 4)
	if by_count.has(count):
		var count_path: String = str(by_count.get(count, ""))
		if not count_path.is_empty():
			return count_path
	return default_path

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
