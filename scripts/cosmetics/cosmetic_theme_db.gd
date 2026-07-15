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
const DEFAULT_UNIT_ITEM_ID: String = "unit_field_issue"
const DEFAULT_HIVE_ITEM_ID: String = "hive_classic"
const DEFAULT_LANE_ITEM_ID: String = "lane_classic"
const DEFAULT_FLOOR_ITEM_ID: String = "floor_standard"
const DEFAULT_VFX_ITEM_ID: String = "vfx_ion_pop"
const DEFAULT_UNIT_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/unit_v3.png"
const DEFAULT_LANE_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/lane_white_5space.png"
const DEFAULT_FLOOR_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/dark_floor.png"
const DEFAULT_VFX_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/light_projection.png"

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
static var _garage_cosmetics: Dictionary = {
	"units": {
		DEFAULT_UNIT_ITEM_ID: {
			"registry_key_template": "unit.{owner}",
			"fallback_texture": DEFAULT_UNIT_TEXTURE_PATH
		},
		"unit_broadcast_elite": {
			"registry_key_template": "unit.{owner}",
			"fallback_texture": DEFAULT_UNIT_TEXTURE_PATH
		}
	},
	"hives": {
		DEFAULT_HIVE_ITEM_ID: {
			"registry_key_template": "hive.{tier}.{owner}"
		},
		"hive_obsidian": {
			"registry_key_template": "hive.{tier}.{owner}"
		}
	},
	"lanes": {
		DEFAULT_LANE_ITEM_ID: {
			"registry_key": "lane.points",
			"fallback_texture": DEFAULT_LANE_TEXTURE_PATH
		},
		"lane_goldpulse": {
			"registry_key": "lane.points",
			"fallback_texture": DEFAULT_LANE_TEXTURE_PATH
		}
	},
	"floors": {
		DEFAULT_FLOOR_ITEM_ID: {
			"texture": DEFAULT_FLOOR_TEXTURE_PATH
		},
		"floor_circuit_forge": {
			"texture": "res://assets/sprites/sf_skin_v1/mm_back_art.png",
			"fallback_texture": DEFAULT_FLOOR_TEXTURE_PATH
		}
	},
	"vfx": {
		DEFAULT_VFX_ITEM_ID: {
			"texture": DEFAULT_VFX_TEXTURE_PATH
		},
		"vfx_breach_flash": {
			"texture": "res://assets/sprites/sf_skin_v1/buffs/tower_activated.PNG",
			"fallback_texture": DEFAULT_VFX_TEXTURE_PATH
		}
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

static func get_garage_selection(category_id: String) -> String:
	var category: String = _clean_category(category_id)
	var fallback: String = _default_garage_item_id(category)
	var profile_manager: Node = _profile_manager()
	if profile_manager != null and profile_manager.has_method("get_garage_selection"):
		var selected: String = str(profile_manager.call("get_garage_selection", category)).strip_edges()
		if selected != "":
			return selected
	return fallback

static func garage_selection_token(category_id: String) -> int:
	return hash("%s:%s" % [_clean_category(category_id), get_garage_selection(category_id)])

static func resolve_unit_sprite(owner_id: int, registry: Object) -> Dictionary:
	var owner_key: String = _owner_key(owner_id)
	var selection_id: String = get_garage_selection("units")
	var def: Dictionary = _garage_def("units", selection_id)
	var registry_key: String = _format_garage_key(str(def.get("registry_key_template", "unit.{owner}")), owner_key, "", "")
	var tex: Texture2D = null
	var tex_path: String = str(def.get("texture", ""))
	if tex_path != "":
		tex = _load_texture(tex_path)
	if tex == null and registry != null and registry.has_method("get_tex"):
		tex = registry.call("get_tex", registry_key) as Texture2D
		if registry.has_method("get_tex_path"):
			tex_path = str(registry.call("get_tex_path", registry_key))
	if tex == null:
		var fallback_path: String = str(def.get("fallback_texture", DEFAULT_UNIT_TEXTURE_PATH))
		tex = _load_texture(fallback_path)
		tex_path = fallback_path
	return {
		"selection_id": selection_id,
		"key": registry_key,
		"texture": tex,
		"path": tex_path,
		"scale": float(def.get("scale", _registry_scale(registry, registry_key, 1.0)))
	}

static func resolve_hive_sprite(owner_id: int, kind: String, power: int, registry: Object) -> Dictionary:
	var owner_key: String = _owner_key(owner_id)
	var tier_key: String = _hive_tier_key(kind, power)
	var selection_id: String = get_garage_selection("hives")
	var def: Dictionary = _garage_def("hives", selection_id)
	var registry_key: String = _format_garage_key(str(def.get("registry_key_template", "hive.{tier}.{owner}")), owner_key, tier_key, kind)
	var tex: Texture2D = null
	var tex_path: String = str(def.get("texture", ""))
	if tex_path != "":
		tex = _load_texture(tex_path)
	if tex == null and registry != null and registry.has_method("get_tex"):
		tex = registry.call("get_tex", registry_key) as Texture2D
		if registry.has_method("get_tex_path"):
			tex_path = str(registry.call("get_tex_path", registry_key))
	return {
		"selection_id": selection_id,
		"key": registry_key,
		"texture": tex,
		"path": tex_path,
		"scale": float(def.get("scale", _registry_scale(registry, registry_key, 1.0)))
	}

static func resolve_lane_texture(registry: Object) -> Dictionary:
	var selection_id: String = get_garage_selection("lanes")
	var def: Dictionary = _garage_def("lanes", selection_id)
	var registry_key: String = str(def.get("registry_key", "lane.points"))
	var tex: Texture2D = null
	var tex_path: String = str(def.get("texture", ""))
	if tex_path != "":
		tex = _load_texture(tex_path)
	if tex == null and registry != null and registry.has_method("get_tex"):
		tex = registry.call("get_tex", registry_key) as Texture2D
		if registry.has_method("get_tex_path"):
			tex_path = str(registry.call("get_tex_path", registry_key))
	if tex == null:
		var fallback_path: String = str(def.get("fallback_texture", DEFAULT_LANE_TEXTURE_PATH))
		tex = _load_texture(fallback_path)
		tex_path = fallback_path
	return {
		"selection_id": selection_id,
		"key": registry_key,
		"texture": tex,
		"path": tex_path
	}

static func get_selected_floor_texture() -> Texture2D:
	return _selected_category_texture("floors", DEFAULT_FLOOR_TEXTURE_PATH)

static func get_selected_vfx_texture() -> Texture2D:
	return _selected_category_texture("vfx", DEFAULT_VFX_TEXTURE_PATH)

static func _selected_category_texture(category_id: String, fallback_path: String) -> Texture2D:
	var category: String = _clean_category(category_id)
	var selection_id: String = get_garage_selection(category)
	var def: Dictionary = _garage_def(category, selection_id)
	var texture: Texture2D = _load_texture(str(def.get("texture", "")))
	if texture != null:
		return texture
	return _load_texture(str(def.get("fallback_texture", fallback_path)))

static func _garage_def(category_id: String, item_id: String) -> Dictionary:
	var category: String = _clean_category(category_id)
	var items: Dictionary = _garage_cosmetics.get(category, {}) as Dictionary
	if items.has(item_id):
		return (items.get(item_id, {}) as Dictionary).duplicate(true)
	var convention_path: String = _convention_texture_path(category, item_id)
	if convention_path != "" and (FileAccess.file_exists(convention_path + ".import") or FileAccess.file_exists(convention_path)):
		return {"texture": convention_path}
	var fallback_id: String = _default_garage_item_id(category)
	return (items.get(fallback_id, {}) as Dictionary).duplicate(true)

static func _convention_texture_path(category_id: String, item_id: String) -> String:
	var clean_item: String = item_id.strip_edges()
	if clean_item == "":
		return ""
	return "res://assets/sprites/sf_skin_v1/cosmetics/%s/%s.png" % [_clean_category(category_id), clean_item]

static func _default_garage_item_id(category_id: String) -> String:
	match _clean_category(category_id):
		"units":
			return DEFAULT_UNIT_ITEM_ID
		"hives":
			return DEFAULT_HIVE_ITEM_ID
		"lanes":
			return DEFAULT_LANE_ITEM_ID
		"floors":
			return DEFAULT_FLOOR_ITEM_ID
		"vfx":
			return DEFAULT_VFX_ITEM_ID
		_:
			return ""

static func _format_garage_key(template: String, owner_key: String, tier_key: String, kind_key: String) -> String:
	return template.replace("{owner}", owner_key).replace("{tier}", tier_key).replace("{kind}", kind_key)

static func _owner_key(owner_id: int) -> String:
	if owner_id <= 0:
		return "neutral"
	return "p%d" % owner_id

static func _hive_tier_key(kind: String, power: int) -> String:
	if power > 0:
		if power <= 9:
			return "small"
		if power <= 24:
			return "med"
		return "large"
	var clean_kind: String = kind.strip_edges().to_lower()
	if clean_kind == "medium":
		return "med"
	if clean_kind == "large" or clean_kind == "med":
		return clean_kind
	return "small"

static func _registry_scale(registry: Object, key: String, fallback: float) -> float:
	if registry != null and registry.has_method("get_scale"):
		return float(registry.call("get_scale", key))
	return fallback

static func _clean_category(category_id: String) -> String:
	return str(category_id).strip_edges().to_lower()

static func _profile_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/ProfileManager")
	return null

static func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
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
