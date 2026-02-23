extends Control

@onready var contest_list: ItemList = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestList
@onready var contest_id: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestId
@onready var contest_name: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestName
@onready var contest_mode: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMode
@onready var contest_start: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestStart
@onready var contest_end: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestEnd
@onready var contest_entry_type: OptionButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestEntryType
@onready var contest_ante: SpinBox = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestAnte
@onready var contest_map_pool: ItemList = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMapPool
@onready var contest_published: CheckButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPublished
@onready var contest_new: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestButtons/ContestNew
@onready var contest_save: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestButtons/ContestSave
@onready var contest_delete: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestButtons/ContestDelete
@onready var contest_status: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestStatus

@onready var map_list: ItemList = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapList
@onready var map_id: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapId
@onready var map_name: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapName
@onready var map_scene_path: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapScenePath
@onready var map_preview: TextureRect = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapPreview
@onready var map_preview_path: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapPreviewPath
@onready var map_in_pool: CheckButton = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapInPool
@onready var map_load_test: Button = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapLoadTest
@onready var map_status: Label = $RootPanel/RootVBox/Tabs/Maps/MapsHBox/MapForm/MapStatus
@onready var contest_state: Node = get_node_or_null("/root/ContestState")

var _current_contest_id: String = ""
var _current_map_id: String = ""

func _ready() -> void:
	contest_entry_type.clear()
	contest_entry_type.add_item("WEEKLY")
	contest_entry_type.add_item("MONTHLY")
	contest_entry_type.add_item("YEARLY")
	contest_entry_type.add_item("DAILY")
	contest_entry_type.add_item("EVENT")
	contest_map_pool.select_mode = ItemList.SELECT_MULTI
	contest_list.item_selected.connect(_on_contest_selected)
	contest_new.pressed.connect(_on_contest_new)
	contest_save.pressed.connect(_on_contest_save)
	contest_delete.pressed.connect(_on_contest_delete)
	map_list.item_selected.connect(_on_map_selected)
	map_in_pool.toggled.connect(_on_map_in_pool_toggled)
	map_load_test.pressed.connect(_on_map_load_test)
	map_preview.expand = true
	map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_status.text = ""
	contest_status.text = ""

func refresh() -> void:
	_load_contests()
	_load_maps()

func _load_contests() -> void:
	contest_list.clear()
	OpsState.load_contests()
	var ids: PackedStringArray = OpsState.get_contest_ids()
	if ids.is_empty():
		contest_list.add_item("No contests yet")
		contest_list.set_item_selectable(0, false)
		_clear_contest_form()
		return
	for id in ids:
		var contest: ContestDef = OpsState.contests.get(id)
		var label: String = id
		if contest != null and contest.published:
			label = "%s (published)" % id
		var idx: int = contest_list.add_item(label)
		contest_list.set_item_metadata(idx, id)
	_clear_contest_form()

func _load_maps() -> void:
	map_list.clear()
	OpsState.load_maps()
	var ids: PackedStringArray = OpsState.get_map_ids()
	contest_map_pool.clear()
	if ids.is_empty():
		map_list.add_item("No maps found")
		map_list.set_item_selectable(0, false)
		contest_map_pool.add_item("No maps found")
		contest_map_pool.set_item_selectable(0, false)
		_clear_map_form()
		return
	for id in ids:
		var map_def: MapDef = OpsState.maps.get(id)
		var label: String = id
		if map_def != null and not map_def.display_name.is_empty():
			label = "%s (%s)" % [id, map_def.display_name]
		var idx: int = map_list.add_item(label)
		map_list.set_item_metadata(idx, id)
		var pool_idx: int = contest_map_pool.add_item(id)
		contest_map_pool.set_item_metadata(pool_idx, id)
	_clear_map_form()

func _on_contest_selected(index: int) -> void:
	var contest_id_meta: Variant = contest_list.get_item_metadata(index)
	if contest_id_meta == null:
		return
	var contest_id_str: String = str(contest_id_meta)
	var contest: ContestDef = OpsState.contests.get(contest_id_str)
	if contest == null:
		return
	_current_contest_id = contest.id
	contest_id.text = contest.id
	contest_name.text = contest.name
	contest_mode.text = contest.mode
	contest_start.text = str(contest.start_ts)
	contest_end.text = str(contest.end_ts)
	_set_scope_selection(contest.scope)
	contest_ante.value = contest.price
	contest_published.button_pressed = contest.published
	_set_contest_map_pool_selection(contest.map_ids)
	contest_status.text = "Loaded %s" % contest.id

func _set_contest_map_pool_selection(map_ids: PackedStringArray) -> void:
	contest_map_pool.deselect_all()
	for i in range(contest_map_pool.item_count):
		var map_id: String = str(contest_map_pool.get_item_metadata(i))
		if map_ids.has(map_id):
			contest_map_pool.select(i, true)

func _on_contest_new() -> void:
	_current_contest_id = ""
	_clear_contest_form()
	contest_status.text = "New contest"

func _on_contest_save() -> void:
	var contest: ContestDef = ContestDef.new()
	contest.id = contest_id.text.strip_edges()
	var parts: Dictionary = _parse_contest_id(contest.id)
	if parts.is_empty():
		contest_status.text = "Invalid contest ID format"
		return
	var normalized_id: String = _normalize_contest_id(contest.id)
	if not normalized_id.is_empty():
		contest.id = normalized_id
	contest.name = contest_name.text.strip_edges()
	contest.mode = contest_mode.text.strip_edges()
	contest.scope = str(parts.get("scope", contest.scope))
	contest.currency = str(parts.get("currency", contest.currency))
	contest.price = int(parts.get("price", contest.price))
	contest.time_slice = str(parts.get("time", contest.time_slice))
	contest.status = "OPEN"
	contest.start_ts = int(contest_start.text)
	contest.end_ts = int(contest_end.text)
	contest.published = contest_published.button_pressed
	contest.map_ids = _collect_selected_map_pool()
	if contest.id.is_empty():
		contest_status.text = "Contest ID required"
		return
	OpsState.save_contest(contest)
	_current_contest_id = contest.id
	contest_status.text = "Saved %s" % contest.id
	contest_id.text = contest.id
	_load_contests()

func _on_contest_delete() -> void:
	if _current_contest_id.is_empty():
		contest_status.text = "Select a contest first"
		return
	OpsState.delete_contest(_current_contest_id)
	contest_status.text = "Deleted %s" % _current_contest_id
	_current_contest_id = ""
	_load_contests()

func _collect_selected_map_pool() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for idx in contest_map_pool.get_selected_items():
		var map_id: String = str(contest_map_pool.get_item_metadata(idx))
		if not map_id.is_empty():
			ids.append(map_id)
	return ids

func _clear_contest_form() -> void:
	contest_id.text = ""
	contest_name.text = ""
	contest_mode.text = "TIME_PUZZLE"
	contest_start.text = "0"
	contest_end.text = "0"
	contest_entry_type.select(0)
	contest_ante.value = 0
	contest_published.button_pressed = false
	contest_map_pool.deselect_all()

func _on_map_selected(index: int) -> void:
	var map_id_meta: Variant = map_list.get_item_metadata(index)
	if map_id_meta == null:
		return
	var map_id_str: String = str(map_id_meta)
	var map_def: MapDef = OpsState.maps.get(map_id_str)
	if map_def == null:
		return
	_current_map_id = map_def.id
	map_id.text = map_def.id
	map_name.text = map_def.display_name
	map_scene_path.text = map_def.map_scene_path
	map_preview_path.text = map_def.preview_path
	map_in_pool.button_pressed = map_def.in_pool
	if not map_def.preview_path.is_empty() and ResourceLoader.exists(map_def.preview_path):
		map_preview.texture = load(map_def.preview_path)
	else:
		map_preview.texture = null
	map_status.text = "Loaded %s" % map_def.id

func _on_map_in_pool_toggled(pressed: bool) -> void:
	if _current_map_id.is_empty():
		return
	var map_def: MapDef = OpsState.maps.get(_current_map_id)
	if map_def == null:
		return
	map_def.in_pool = pressed
	OpsState.save_map(map_def)
	map_status.text = "Saved %s" % map_def.id

func _on_map_load_test() -> void:
	if _current_map_id.is_empty():
		map_status.text = "Select a map first"
		return
	OpsState.request_map_test(_current_map_id)
	map_status.text = "Load requested: %s" % _current_map_id

func _clear_map_form() -> void:
	_current_map_id = ""
	map_id.text = ""
	map_name.text = ""
	map_scene_path.text = ""
	map_preview_path.text = ""
	map_in_pool.button_pressed = false
	map_preview.texture = null

func _set_scope_selection(scope: String) -> void:
	var scope_upper: String = scope.to_upper()
	for i in range(contest_entry_type.item_count):
		if contest_entry_type.get_item_text(i) == scope_upper:
			contest_entry_type.select(i)
			return
	contest_entry_type.select(0)

func _parse_contest_id(contest_id_str: String) -> Dictionary:
	if contest_state != null:
		return contest_state.parse_contest_id(contest_id_str)
	return {}

func _normalize_contest_id(contest_id_str: String) -> String:
	if contest_state != null:
		return contest_state.normalize_contest_id(contest_id_str)
	return contest_id_str
