class_name BuffCatalog
extends RefCounted

const BUFFS_PATH := "res://data/buffs/buffs_v1.json"
const BUFFS_SCHEMA := "swarmfront.buffs.v1"

static var _loaded := false
static var _load_ok := false
static var _by_id: Dictionary = {}
static var _by_category: Dictionary = {}
static var _by_tier: Dictionary = {}
static var _stacking_default := "refresh"

static func _ensure_loaded() -> bool:
	if _loaded:
		return _load_ok
	_loaded = true
	var file: FileAccess = FileAccess.open(BUFFS_PATH, FileAccess.READ)
	if file == null:
		push_error("BUFF_CATALOG: failed to open %s" % BUFFS_PATH)
		return false
	var text: String = file.get_as_text()
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("BUFF_CATALOG: JSON root is not a Dictionary")
		return false
	var root: Dictionary = json.data
	if str(root.get("_schema", "")) != BUFFS_SCHEMA:
		push_error("BUFF_CATALOG: invalid schema %s" % str(root.get("_schema", "")))
		return false
	_stacking_default = str(root.get("stacking_default", "refresh"))
	var buffs: Array = root.get("buffs", [])
	_by_id.clear()
	_by_category.clear()
	_by_tier.clear()
	for buff_v in buffs:
		if typeof(buff_v) != TYPE_DICTIONARY:
			continue
		var buff: Dictionary = buff_v
		var buff_id: String = str(buff.get("id", ""))
		if buff_id == "":
			continue
		_by_id[buff_id] = buff
		var category: String = str(buff.get("category", "unknown"))
		if not _by_category.has(category):
			_by_category[category] = []
		_by_category[category].append(buff)
		var tier: String = str(buff.get("tier", "unknown"))
		if not _by_tier.has(tier):
			_by_tier[tier] = []
		_by_tier[tier].append(buff)
	_load_ok = true
	return true

static func get_buff(buff_id: String) -> Dictionary:
	if not _ensure_loaded():
		return {}
	return _by_id.get(buff_id, {})

static func list_by_category(category: String) -> Array:
	if not _ensure_loaded():
		return []
	return _by_category.get(category, [])

static func list_by_tier(tier: String) -> Array:
	if not _ensure_loaded():
		return []
	return _by_tier.get(tier, [])

static func stacking_default() -> String:
	_ensure_loaded()
	return _stacking_default
