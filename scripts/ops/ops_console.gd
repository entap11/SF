extends Control

signal contest_payout_approval_requested(report: Dictionary, approver_id: String)

const DEFAULT_MONEY_DENOMINATIONS: Array[int] = [1, 2, 3, 5, 10, 15, 20, 50, 100]
const DEFAULT_HOUSE_RAKE_BPS: int = 1000
const BASIS_POINTS_DENOMINATOR: int = 10000
const PAYOUT_REPORT_EXPORT_PATH: String = "user://ops_payout_summary_export.csv"

@onready var contest_list: ItemList = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestList
@onready var contest_setup_select: OptionButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestSetupSelect
@onready var contest_id: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestId
@onready var contest_name: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestName
@onready var contest_mode: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMode
@onready var contest_start: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestStart
@onready var contest_end: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestEnd
@onready var contest_entry_type_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestEntryTypeLabel
@onready var contest_entry_type: OptionButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestEntryType
@onready var contest_ante_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestAnteLabel
@onready var contest_ante: SpinBox = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestAnte
@onready var contest_map_count: OptionButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMapCount
@onready var contest_prize_pool_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPrizePoolLabel
@onready var contest_prize_pool: SpinBox = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPrizePool
@onready var contest_winner_count_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestWinnerCountLabel
@onready var contest_winner_count: OptionButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestWinnerCount
@onready var contest_payout_rows: VBoxContainer = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPayoutRows
@onready var contest_payout_summary: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPayoutSummary
@onready var contest_rewards_json_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestRewardsJsonLabel
@onready var contest_rewards_json: TextEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestRewardsJson
@onready var contest_map_pool: ItemList = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMapPool
@onready var contest_published: CheckButton = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPublished
@onready var contest_new: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestButtons/ContestNew
@onready var contest_save: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestButtons/ContestSave
@onready var contest_delete: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestButtons/ContestDelete
@onready var contest_status: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestStatus
@onready var contest_approval_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalLabel
@onready var contest_refresh_payout_reports: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestRefreshPayoutReports
@onready var contest_approval_summary: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalSummary
@onready var contest_approval_rows: VBoxContainer = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalRows
@onready var contest_approver_label: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApproverLabel
@onready var contest_approver_input: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApproverInput
@onready var contest_approve_payouts: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovePayouts
@onready var contest_approval_backend_status: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestApprovalBackendStatus
@onready var payout_report_contest_filter: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportContestFilter
@onready var payout_report_account_filter: LineEdit = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportAccountFilter
@onready var payout_report_refresh: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportRefresh
@onready var payout_report_export: Button = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportFilters/PayoutReportExport
@onready var payout_report_summary: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportSummary
@onready var payout_report_rows: VBoxContainer = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportRows
@onready var payout_report_status: Label = $RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/PayoutReportStatus

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
var _current_payout_approval_report: Dictionary = {}
var _current_payout_summary: Dictionary = {}

func _ready() -> void:
	contest_entry_type.clear()
	contest_entry_type.add_item("WEEKLY")
	contest_entry_type.add_item("MONTHLY")
	contest_entry_type.add_item("YEARLY")
	contest_entry_type.add_item("DAILY")
	contest_entry_type.add_item("EVENT")
	_configure_contest_setup_selector()
	contest_map_count.clear()
	contest_map_count.add_item("3 maps")
	contest_map_count.set_item_metadata(0, 3)
	contest_map_count.add_item("5 maps")
	contest_map_count.set_item_metadata(1, 5)
	contest_map_count.select(1)
	_configure_winner_count_selector()
	contest_setup_select.item_selected.connect(_on_contest_setup_selected)
	contest_map_pool.select_mode = ItemList.SELECT_MULTI
	contest_list.item_selected.connect(_on_contest_selected)
	contest_new.pressed.connect(_on_contest_new)
	contest_save.pressed.connect(_on_contest_save)
	contest_delete.pressed.connect(_on_contest_delete)
	contest_refresh_payout_reports.pressed.connect(_on_refresh_payout_reports_pressed)
	contest_approve_payouts.pressed.connect(_on_approve_payouts_pressed)
	payout_report_refresh.pressed.connect(_on_refresh_payout_summary_pressed)
	payout_report_export.pressed.connect(_on_export_payout_summary_pressed)
	map_list.item_selected.connect(_on_map_selected)
	map_in_pool.toggled.connect(_on_map_in_pool_toggled)
	map_load_test.pressed.connect(_on_map_load_test)
	map_preview.expand = true
	map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_status.text = ""
	contest_status.text = ""
	contest_approval_backend_status.text = ""
	payout_report_status.text = ""
	_rebuild_payout_rows(1)
	_refresh_payment_controls()
	clear_payout_approval_report()
	clear_payout_summary()

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
	_set_contest_setup_selection(contest.scope, contest.currency, contest.price)
	_set_map_count_selection(contest.map_ids.size())
	contest_prize_pool.value = float(maxi(0, contest.prize_pool_cents)) / 100.0
	var cash_schedule: Array[Dictionary] = contest.get_cash_payout_schedule() if contest.has_method("get_cash_payout_schedule") else contest.prize_rewards
	_set_winner_count_selection(maxi(1, _infer_winner_count(cash_schedule)))
	_rebuild_payout_rows(_selected_winner_count(), cash_schedule)
	contest_published.button_pressed = contest.published
	_set_contest_map_pool_selection(contest.map_ids)
	_refresh_payment_controls()
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
	var selected_scope: String = _selected_scope()
	var selected_price: int = maxi(0, int(contest_ante.value))
	parts["scope"] = selected_scope
	parts["price"] = selected_price
	parts["currency"] = "FREE" if selected_price <= 0 else str(parts.get("currency", "USD")).strip_edges().to_upper()
	var normalized_id: String = _build_contest_id(parts)
	if not normalized_id.is_empty():
		contest.id = normalized_id
	contest.name = contest_name.text.strip_edges()
	contest.mode = contest_mode.text.strip_edges()
	contest.scope = selected_scope
	contest.currency = str(parts.get("currency", contest.currency))
	contest.price = selected_price
	contest.time_slice = str(parts.get("time", contest.time_slice))
	contest.status = "OPEN"
	contest.start_ts = int(contest_start.text)
	contest.end_ts = int(contest_end.text)
	contest.published = contest_published.button_pressed
	var selected_maps: PackedStringArray = _collect_selected_map_pool()
	var target_map_count: int = _selected_map_count()
	if selected_maps.size() < target_map_count:
		contest_status.text = "Select at least %d maps for this contest" % target_map_count
		return
	contest.map_ids = _trim_map_ids_to_count(selected_maps, target_map_count)
	contest.house_rake_bps = DEFAULT_HOUSE_RAKE_BPS
	if selected_price > 0:
		contest.prize_pool_cents = int(round(float(contest_prize_pool.value) * 100.0))
		contest.set_cash_payout_schedule(_collect_payout_schedule_from_rows())
		var payout_bps: int = contest.get_cash_payout_total_bps()
		if payout_bps + contest.get_house_rake_bps() != BASIS_POINTS_DENOMINATOR:
			contest_status.text = "Money payout percentages plus house rake must equal 100%."
			return
	else:
		contest.prize_pool_cents = 0
		contest.prize_rewards = []
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
	clear_payout_approval_report()
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
	_set_contest_setup_selection("WEEKLY", "FREE", 0)
	_apply_contest_setup_id("WEEKLY", "FREE", 0)
	contest_map_count.select(1)
	contest_prize_pool.value = 0
	_set_winner_count_selection(1)
	_rebuild_payout_rows(1)
	contest_published.button_pressed = false
	contest_map_pool.deselect_all()
	_refresh_payment_controls()
	clear_payout_approval_report()

func show_payout_approval_report(report: Dictionary) -> void:
	_current_payout_approval_report = report.duplicate(true)
	_refresh_payout_approval_report()

func clear_payout_approval_report() -> void:
	_current_payout_approval_report.clear()
	_refresh_payout_approval_report()

func get_current_payout_approval_report() -> Dictionary:
	return _current_payout_approval_report.duplicate(true)

func get_current_payout_summary() -> Dictionary:
	return _current_payout_summary.duplicate(true)

func request_pending_payout_reports(filters: Dictionary = {}) -> Dictionary:
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("list_async_contest_payout_reports"):
		_set_approval_backend_status("Payout backend unavailable.")
		return {"ok": false, "err": "backend_unavailable"}
	var clean_filters: Dictionary = filters.duplicate(true)
	if not clean_filters.has("status") and not clean_filters.has("approval_status"):
		clean_filters["status"] = "pending_approval"
	if not clean_filters.has("sort_desc"):
		clean_filters["sort_desc"] = true
	if not clean_filters.has("limit"):
		clean_filters["limit"] = 1
	var result: Dictionary = backend.call("list_async_contest_payout_reports", clean_filters) as Dictionary
	if not bool(result.get("ok", false)):
		_set_approval_backend_status("Payout report fetch failed: %s" % _result_error(result))
		return result
	var reports: Array = result.get("reports", []) as Array
	if reports.is_empty():
		clear_payout_approval_report()
		_set_approval_backend_status("No pending payout reports.")
		return result
	var report_any: Variant = reports[0]
	if typeof(report_any) != TYPE_DICTIONARY:
		clear_payout_approval_report()
		_set_approval_backend_status("Payout report fetch returned invalid data.")
		return {"ok": false, "err": "invalid_report_payload"}
	show_payout_approval_report(report_any as Dictionary)
	_set_approval_backend_status("Loaded pending payout report %s." % str((report_any as Dictionary).get("report_id", "")))
	return result

func request_payout_summary(filters: Dictionary = {}) -> Dictionary:
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("get_money_payout_summary"):
		_set_payout_report_status("Payout summary backend unavailable.")
		return {"ok": false, "err": "backend_unavailable"}
	var clean_filters: Dictionary = filters.duplicate(true)
	if not clean_filters.has("limit"):
		clean_filters["limit"] = 25
	var result: Dictionary = backend.call("get_money_payout_summary", clean_filters) as Dictionary
	if not bool(result.get("ok", false)):
		if str(result.get("err", result.get("code", ""))).strip_edges() == "transport_not_configured":
			_set_payout_report_status("Payout summary backend unavailable.")
			return result
		_set_payout_report_status("Payout summary fetch failed: %s" % _result_error(result))
		return result
	show_payout_summary(result)
	_set_payout_report_status("Payout report refreshed.")
	return result

func show_payout_summary(summary: Dictionary) -> void:
	_current_payout_summary = summary.duplicate(true)
	_refresh_payout_summary_report()

func clear_payout_summary() -> void:
	_current_payout_summary.clear()
	_refresh_payout_summary_report()

func _refresh_payout_summary_report() -> void:
	if payout_report_rows != null:
		for child in payout_report_rows.get_children():
			child.queue_free()
	var has_summary: bool = bool(_current_payout_summary.get("ok", false))
	if payout_report_summary != null:
		if has_summary:
			payout_report_summary.text = "Paid %s | Rake %s | Gross %s | Payout tx %d | Contests %d | Pending approvals %d" % [
				_format_cents(maxi(0, int(_current_payout_summary.get("paid_out_cents", 0)))),
				_format_cents(maxi(0, int(_current_payout_summary.get("house_rake_cents", 0)))),
				_format_cents(maxi(0, int(_current_payout_summary.get("gross_closed_cents", 0)))),
				maxi(0, int(_current_payout_summary.get("payout_transaction_count", 0))),
				maxi(0, int(_current_payout_summary.get("contest_count", 0))),
				maxi(0, int(_current_payout_summary.get("pending_approval_reports", 0)))
			]
		else:
			payout_report_summary.text = "No payout summary loaded."
	if not has_summary or payout_report_rows == null:
		return
	var contests: Array = _current_payout_summary.get("contests", []) as Array
	if contests.is_empty():
		var empty: Label = Label.new()
		empty.text = "No posted contest payouts match the current filters."
		payout_report_rows.add_child(empty)
		return
	payout_report_rows.add_child(_build_payout_summary_header_row())
	for contest_any in contests:
		if typeof(contest_any) != TYPE_DICTIONARY:
			continue
		payout_report_rows.add_child(_build_payout_summary_contest_row(contest_any as Dictionary))

func _build_payout_summary_header_row() -> Control:
	return _build_payout_summary_row({
		"contest_id": "Contest",
		"paid_out_label": "Paid out",
		"house_rake_label": "Rake",
		"total_take_label": "Gross",
		"payout_count_label": "Winners",
		"last_paid_utc": "Last paid"
	}, true)

func _build_payout_summary_contest_row(contest: Dictionary) -> Control:
	return _build_payout_summary_row({
		"contest_id": str(contest.get("contest_id", "")),
		"paid_out_label": _format_cents(maxi(0, int(contest.get("paid_out_cents", 0)))),
		"house_rake_label": _format_cents(maxi(0, int(contest.get("house_rake_cents", 0)))),
		"total_take_label": _format_cents(maxi(0, int(contest.get("total_take_cents", 0)))),
		"payout_count_label": str(maxi(0, int(contest.get("payout_count", 0)))),
		"last_paid_utc": str(contest.get("last_paid_utc", ""))
	}, false)

func _build_payout_summary_row(data: Dictionary, header: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var contest_label: Label = _payout_summary_cell(str(data.get("contest_id", "")), 220.0, HORIZONTAL_ALIGNMENT_LEFT, header)
	contest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(contest_label)
	row.add_child(_payout_summary_cell(str(data.get("paid_out_label", "")), 90.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	row.add_child(_payout_summary_cell(str(data.get("house_rake_label", "")), 90.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	row.add_child(_payout_summary_cell(str(data.get("total_take_label", "")), 90.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	row.add_child(_payout_summary_cell(str(data.get("payout_count_label", "")), 70.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	row.add_child(_payout_summary_cell(str(data.get("last_paid_utc", "")), 150.0, HORIZONTAL_ALIGNMENT_RIGHT, header))
	return row

func _payout_summary_cell(text: String, width: float, align: HorizontalAlignment, header: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0.0)
	label.horizontal_alignment = align
	label.clip_text = true
	if header:
		label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.36, 1.0))
	return label

func _on_refresh_payout_summary_pressed() -> void:
	request_payout_summary(_collect_payout_summary_filters())

func _on_export_payout_summary_pressed() -> void:
	var result: Dictionary = export_current_payout_summary_csv()
	if bool(result.get("ok", false)):
		_set_payout_report_status("Exported payout report: %s" % str(result.get("path", "")))
	else:
		_set_payout_report_status("Payout report export failed: %s" % _result_error(result))

func _collect_payout_summary_filters() -> Dictionary:
	var filters: Dictionary = {"limit": 25}
	var contest_filter: String = payout_report_contest_filter.text.strip_edges() if payout_report_contest_filter != null else ""
	var account_filter: String = payout_report_account_filter.text.strip_edges() if payout_report_account_filter != null else ""
	if not contest_filter.is_empty():
		filters["contest_id"] = contest_filter
	if not account_filter.is_empty():
		filters["account_id"] = account_filter
	return filters

func export_current_payout_summary_csv(path: String = PAYOUT_REPORT_EXPORT_PATH) -> Dictionary:
	if not bool(_current_payout_summary.get("ok", false)):
		return {"ok": false, "err": "missing_payout_summary"}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "err": "export_open_failed", "path": path}
	file.store_line("contest_id,paid_out_cents,house_rake_cents,total_take_cents,payout_count,last_paid_utc,transaction_ids")
	var contests: Array = _current_payout_summary.get("contests", []) as Array
	for contest_any in contests:
		if typeof(contest_any) != TYPE_DICTIONARY:
			continue
		var contest: Dictionary = contest_any as Dictionary
		var cells: PackedStringArray = PackedStringArray([
			_csv_cell(str(contest.get("contest_id", ""))),
			str(maxi(0, int(contest.get("paid_out_cents", 0)))),
			str(maxi(0, int(contest.get("house_rake_cents", 0)))),
			str(maxi(0, int(contest.get("total_take_cents", 0)))),
			str(maxi(0, int(contest.get("payout_count", 0)))),
			_csv_cell(str(contest.get("last_paid_utc", ""))),
			_csv_cell(JSON.stringify(contest.get("transaction_ids", [])))
		])
		file.store_line(",".join(cells))
	file.close()
	return {"ok": true, "path": ProjectSettings.globalize_path(path)}

func _refresh_payout_approval_report() -> void:
	var has_report: bool = bool(_current_payout_approval_report.get("ok", false))
	for node in [contest_approval_summary, contest_approval_rows, contest_approver_label, contest_approver_input, contest_approve_payouts]:
		if node == null:
			continue
		node.visible = has_report
	if contest_approval_label != null:
		contest_approval_label.visible = has_report
	if contest_approval_rows != null:
		for child in contest_approval_rows.get_children():
			child.queue_free()
	if not has_report:
		if contest_approval_summary != null:
			contest_approval_summary.text = ""
		if contest_approve_payouts != null:
			contest_approve_payouts.disabled = true
		return
	var approval_status: String = str(_current_payout_approval_report.get("approval_status", "pending_approval"))
	var players_count: int = maxi(0, int(_current_payout_approval_report.get("players_count", 0)))
	var entries_count: int = maxi(0, int(_current_payout_approval_report.get("entries_count", 0)))
	var paid_entries_count: int = maxi(0, int(_current_payout_approval_report.get("paid_entries_count", entries_count)))
	var total_take_cents: int = maxi(0, int(_current_payout_approval_report.get("total_take_cents", 0)))
	var house_rake_cents: int = maxi(0, int(_current_payout_approval_report.get("house_rake_cents", 0)))
	var player_pool_cents: int = maxi(0, int(_current_payout_approval_report.get("player_pool_cents", 0)))
	var payout_count: int = maxi(0, int(_current_payout_approval_report.get("payout_count", 0)))
	if contest_approval_summary != null:
		contest_approval_summary.text = "Report %s | %s | Players %d | Entries %d | Paid entries %d | Total %s | Rake %s | Player pool %s | Planned payouts %d" % [
			str(_current_payout_approval_report.get("report_id", "")),
			approval_status,
			players_count,
			entries_count,
			paid_entries_count,
			_format_cents(total_take_cents),
			_format_cents(house_rake_cents),
			_format_cents(player_pool_cents),
			payout_count
		]
	var planned_payouts: Array = _current_payout_approval_report.get("planned_payouts", []) as Array
	for payout_any in planned_payouts:
		if typeof(payout_any) != TYPE_DICTIONARY:
			continue
		var payout: Dictionary = payout_any as Dictionary
		contest_approval_rows.add_child(_build_approval_payout_row(payout))
	if contest_approve_payouts != null:
		contest_approve_payouts.disabled = approval_status != "pending_approval" or planned_payouts.is_empty()

func _build_approval_payout_row(payout: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var placement_label: Label = Label.new()
	placement_label.custom_minimum_size = Vector2(64.0, 0.0)
	placement_label.text = "#%d" % maxi(1, int(payout.get("placement", 0)))
	row.add_child(placement_label)
	var player_label: Label = Label.new()
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_label.text = str(payout.get("player_id", ""))
	row.add_child(player_label)
	var percent_label: Label = Label.new()
	percent_label.custom_minimum_size = Vector2(90.0, 0.0)
	percent_label.text = "%.1f%%" % (float(maxi(0, int(payout.get("payout_bps", 0)))) / 100.0)
	row.add_child(percent_label)
	var amount_label: Label = Label.new()
	amount_label.custom_minimum_size = Vector2(100.0, 0.0)
	amount_label.text = _format_cents(maxi(0, int(payout.get("amount_cents", 0))))
	row.add_child(amount_label)
	return row

func _on_approve_payouts_pressed() -> void:
	if _current_payout_approval_report.is_empty():
		contest_status.text = "No payout approval report loaded."
		return
	var approver_id: String = contest_approver_input.text.strip_edges()
	if approver_id.is_empty():
		contest_status.text = "Approver required."
		return
	contest_payout_approval_requested.emit(_current_payout_approval_report.duplicate(true), approver_id)
	var result: Dictionary = _approve_payout_report_backend(_current_payout_approval_report.duplicate(true), approver_id)
	if bool(result.get("ok", false)):
		var approved_report_any: Variant = result.get("approval_report", {})
		if typeof(approved_report_any) == TYPE_DICTIONARY:
			show_payout_approval_report(approved_report_any as Dictionary)
		else:
			_current_payout_approval_report["approval_status"] = "approved"
			_refresh_payout_approval_report()
		contest_status.text = "Payout approval posted for %s." % str(_current_payout_approval_report.get("report_id", ""))
		_set_approval_backend_status("Approval posted. Transactions: %s" % str(result.get("transaction_ids", [])))
		return
	if str(result.get("err", "")) == "backend_unavailable" or str(result.get("err", "")) == "transport_not_configured":
		contest_status.text = "Payout approval requested for %s." % str(_current_payout_approval_report.get("report_id", ""))
		_set_approval_backend_status("Backend not configured; approval intent emitted only.")
		return
	contest_status.text = "Payout approval failed: %s" % _result_error(result)
	_set_approval_backend_status(contest_status.text)

func _on_refresh_payout_reports_pressed() -> void:
	request_pending_payout_reports()

func _approve_payout_report_backend(report: Dictionary, approver_id: String) -> Dictionary:
	var backend: Node = get_node_or_null("/root/VsHandshake")
	if backend == null or not backend.has_method("approve_async_contest_payout_report"):
		return {"ok": false, "err": "backend_unavailable"}
	var report_id: String = str(report.get("report_id", "")).strip_edges()
	var key: String = "approve:%s:%s" % [report_id, approver_id]
	return backend.call("approve_async_contest_payout_report", report, approver_id, key) as Dictionary

func _set_approval_backend_status(text: String) -> void:
	if contest_approval_backend_status != null:
		contest_approval_backend_status.text = text

func _set_payout_report_status(text: String) -> void:
	if payout_report_status != null:
		payout_report_status.text = text

func _csv_cell(value: String) -> String:
	var escaped: String = value.replace("\"", "\"\"")
	if escaped.contains(",") or escaped.contains("\"") or escaped.contains("\n"):
		return "\"%s\"" % escaped
	return escaped

func _result_error(result: Dictionary) -> String:
	var err: String = str(result.get("err", result.get("code", ""))).strip_edges()
	if err.is_empty():
		err = str(result.get("message", "unknown_error")).strip_edges()
	return err if not err.is_empty() else "unknown_error"

func _format_cents(amount_cents: int) -> String:
	var safe_cents: int = maxi(0, amount_cents)
	return "$%.2f" % (float(safe_cents) / 100.0)

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

func _selected_scope() -> String:
	if contest_entry_type == null or contest_entry_type.item_count <= 0:
		return "WEEKLY"
	var selected: int = contest_entry_type.selected
	if selected < 0 or selected >= contest_entry_type.item_count:
		return "WEEKLY"
	return contest_entry_type.get_item_text(selected).strip_edges().to_upper()

func _set_map_count_selection(count: int) -> void:
	var target: int = 3 if count <= 3 else 5
	for i in range(contest_map_count.item_count):
		if int(contest_map_count.get_item_metadata(i)) == target:
			contest_map_count.select(i)
			return
	contest_map_count.select(1)

func _selected_map_count() -> int:
	if contest_map_count == null or contest_map_count.item_count <= 0:
		return 5
	var selected: int = contest_map_count.selected
	if selected < 0 or selected >= contest_map_count.item_count:
		return 5
	return clampi(int(contest_map_count.get_item_metadata(selected)), 3, 5)

func _trim_map_ids_to_count(map_ids: PackedStringArray, count: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var target: int = _nearest_supported_map_count(count)
	for map_id_any in map_ids:
		if out.size() >= target:
			break
		var map_id: String = str(map_id_any).strip_edges()
		if map_id.is_empty():
			continue
		out.append(map_id)
	return out

func _nearest_supported_map_count(count: int) -> int:
	return 3 if count <= 3 else 5

func _configure_contest_setup_selector() -> void:
	contest_setup_select.clear()
	_add_contest_setup_option("Free weekly", "WEEKLY", "FREE", 0)
	_add_contest_setup_option("Free monthly", "MONTHLY", "FREE", 0)
	for denomination in _money_denominations():
		_add_contest_setup_option("Money weekly $%d" % denomination, "WEEKLY", "USD", denomination)
	for denomination in _money_denominations():
		_add_contest_setup_option("Money monthly $%d" % denomination, "MONTHLY", "USD", denomination)
	contest_setup_select.select(0)

func _add_contest_setup_option(label: String, scope: String, currency: String, price: int) -> void:
	var idx: int = contest_setup_select.item_count
	contest_setup_select.add_item(label)
	contest_setup_select.set_item_metadata(idx, {
		"scope": scope.strip_edges().to_upper(),
		"currency": currency.strip_edges().to_upper(),
		"price": maxi(0, price)
	})

func _money_denominations() -> Array[int]:
	var found: Dictionary = {}
	if OpsState != null:
		OpsState.load_contests()
		for contest_any in OpsState.contests.values():
			var contest: ContestDef = contest_any as ContestDef
			if contest == null:
				continue
			if str(contest.currency).strip_edges().to_upper() == "USD" and int(contest.price) > 0:
				found[int(contest.price)] = true
	for denom in DEFAULT_MONEY_DENOMINATIONS:
		found[denom] = true
	var out: Array[int] = []
	for denom_any in found.keys():
		out.append(maxi(0, int(denom_any)))
	out.sort()
	return out

func _on_contest_setup_selected(index: int) -> void:
	if index < 0 or index >= contest_setup_select.item_count:
		return
	var metadata_any: Variant = contest_setup_select.get_item_metadata(index)
	if typeof(metadata_any) != TYPE_DICTIONARY:
		return
	var metadata: Dictionary = metadata_any as Dictionary
	var scope: String = str(metadata.get("scope", "WEEKLY")).strip_edges().to_upper()
	var currency: String = str(metadata.get("currency", "FREE")).strip_edges().to_upper()
	var price: int = maxi(0, int(metadata.get("price", 0)))
	_set_scope_selection(scope)
	contest_ante.value = price
	_apply_contest_setup_id(scope, currency, price)
	_refresh_payment_controls()
	_sync_rewards_json_from_payout_rows()

func _apply_contest_setup_id(scope: String, currency: String, price: int) -> void:
	var parts: Dictionary = _parse_contest_id(contest_id.text.strip_edges())
	var time_slice: String = str(parts.get("time", "")).strip_edges()
	var suffix: String = str(parts.get("suffix", "")).strip_edges()
	if time_slice.is_empty():
		time_slice = _default_time_slice(scope)
	var next_id: String = _build_contest_id({
		"scope": scope,
		"currency": currency,
		"price": price,
		"time": time_slice,
		"suffix": suffix
	})
	if not next_id.is_empty():
		contest_id.text = next_id

func _set_contest_setup_selection(scope: String, currency: String, price: int) -> void:
	var clean_scope: String = scope.strip_edges().to_upper()
	var clean_currency: String = currency.strip_edges().to_upper()
	var clean_price: int = maxi(0, price)
	for i in range(contest_setup_select.item_count):
		var metadata_any: Variant = contest_setup_select.get_item_metadata(i)
		if typeof(metadata_any) != TYPE_DICTIONARY:
			continue
		var metadata: Dictionary = metadata_any as Dictionary
		if str(metadata.get("scope", "")) == clean_scope and str(metadata.get("currency", "")) == clean_currency and int(metadata.get("price", -1)) == clean_price:
			contest_setup_select.select(i)
			return

func _default_time_slice(scope: String) -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var year: int = int(now.get("year", 2026))
	var month: int = int(now.get("month", 1))
	var day: int = int(now.get("day", 1))
	var clean_scope: String = scope.strip_edges().to_upper()
	if clean_scope == "MONTHLY":
		return "%04d-%02d" % [year, month]
	if clean_scope == "YEARLY":
		return "%04d" % year
	var rough_week: int = clampi(int(ceil(float(((month - 1) * 31) + day) / 7.0)), 1, 53)
	return "%04d-W%02d" % [year, rough_week]

func _refresh_payment_controls() -> void:
	var paid: bool = int(contest_ante.value) > 0
	for node in [contest_ante_label, contest_ante, contest_prize_pool_label, contest_prize_pool, contest_winner_count_label, contest_winner_count, contest_payout_rows, contest_payout_summary, contest_rewards_json_label, contest_rewards_json]:
		if node == null:
			continue
		node.visible = paid
	contest_entry_type_label.visible = false
	contest_entry_type.visible = false

func _configure_winner_count_selector() -> void:
	contest_winner_count.clear()
	for count in [1, 2, 3, 4, 5, 10, 20]:
		var idx: int = contest_winner_count.item_count
		contest_winner_count.add_item("Top %d" % count)
		contest_winner_count.set_item_metadata(idx, count)
	contest_winner_count.select(0)
	contest_winner_count.item_selected.connect(_on_winner_count_selected)

func _on_winner_count_selected(index: int) -> void:
	var count: int = 1
	if index >= 0 and index < contest_winner_count.item_count:
		count = maxi(1, int(contest_winner_count.get_item_metadata(index)))
	_rebuild_payout_rows(count, _collect_payout_schedule_from_rows())

func _selected_winner_count() -> int:
	if contest_winner_count == null or contest_winner_count.item_count <= 0:
		return 1
	var selected: int = contest_winner_count.selected
	if selected < 0 or selected >= contest_winner_count.item_count:
		return 1
	return maxi(1, int(contest_winner_count.get_item_metadata(selected)))

func _set_winner_count_selection(count: int) -> void:
	var target: int = clampi(count, 1, 20)
	for i in range(contest_winner_count.item_count):
		if int(contest_winner_count.get_item_metadata(i)) >= target:
			contest_winner_count.select(i)
			return
	contest_winner_count.select(contest_winner_count.item_count - 1)

func _infer_winner_count(schedule: Array[Dictionary]) -> int:
	var max_placement: int = 1
	for payout in schedule:
		max_placement = maxi(max_placement, int(payout.get("placement", 0)))
	return max_placement

func _rebuild_payout_rows(winner_count: int, schedule: Array[Dictionary] = []) -> void:
	if contest_payout_rows == null:
		return
	var bps_by_placement: Dictionary = {}
	for payout in schedule:
		bps_by_placement[maxi(1, int(payout.get("placement", 0)))] = clampi(int(payout.get("payout_bps", 0)), 0, BASIS_POINTS_DENOMINATOR)
	for child in contest_payout_rows.get_children():
		child.queue_free()
	var safe_count: int = clampi(winner_count, 1, 20)
	for placement in range(1, safe_count + 1):
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "PayoutRow%d" % placement
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label: Label = Label.new()
		label.text = "#%d payout %%" % placement
		label.custom_minimum_size = Vector2(120.0, 0.0)
		row.add_child(label)
		var amount: SpinBox = SpinBox.new()
		amount.name = "PayoutPercent%d" % placement
		amount.min_value = 0
		amount.max_value = 100
		amount.step = 0.1
		amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amount.value = float(clampi(int(bps_by_placement.get(placement, 0)), 0, BASIS_POINTS_DENOMINATOR)) / 100.0
		amount.set_meta("placement", placement)
		amount.value_changed.connect(func(_value: float) -> void:
			_sync_rewards_json_from_payout_rows()
		)
		row.add_child(amount)
		contest_payout_rows.add_child(row)
	_sync_rewards_json_from_payout_rows()

func _collect_payout_schedule_from_rows() -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	if contest_payout_rows == null:
		return schedule
	for child in contest_payout_rows.get_children():
		var row: Control = child as Control
		if row == null:
			continue
		for grandchild in row.get_children():
			var amount: SpinBox = grandchild as SpinBox
			if amount == null:
				continue
			var placement: int = maxi(1, int(amount.get_meta("placement", schedule.size() + 1)))
			schedule.append({
				"placement": placement,
				"reward_type": "cash",
				"payout_bps": clampi(int(round(float(amount.value) * 100.0)), 0, BASIS_POINTS_DENOMINATOR)
			})
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("placement", 0)) < int(b.get("placement", 0))
	)
	return schedule

func _sync_rewards_json_from_payout_rows() -> void:
	var schedule: Array[Dictionary] = _collect_payout_schedule_from_rows()
	if contest_rewards_json != null:
		contest_rewards_json.text = JSON.stringify(schedule, "\t")
	if contest_payout_summary != null:
		var total_bps: int = 0
		for payout in schedule:
			total_bps += clampi(int(payout.get("payout_bps", 0)), 0, BASIS_POINTS_DENOMINATOR)
		var rake_bps: int = DEFAULT_HOUSE_RAKE_BPS if int(contest_ante.value) > 0 else 0
		var remaining_bps: int = BASIS_POINTS_DENOMINATOR - rake_bps - total_bps
		contest_payout_summary.text = "Payout total: %.1f%% across %d winners | House %.1f%% | Remaining %.1f%%" % [
			float(total_bps) / 100.0,
			schedule.size(),
			float(rake_bps) / 100.0,
			float(remaining_bps) / 100.0
		]

func _parse_prize_rewards_json() -> Dictionary:
	var raw: String = contest_rewards_json.text.strip_edges()
	if raw.is_empty():
		return {"ok": true, "rewards": []}
	var json: JSON = JSON.new()
	var err: Error = json.parse(raw)
	if err != OK:
		return {"ok": false, "error": "Payout JSON error on line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if typeof(json.data) != TYPE_ARRAY:
		return {"ok": false, "error": "Payout JSON must be an array"}
	var rewards: Array[Dictionary] = []
	for reward_any in json.data as Array:
		if typeof(reward_any) != TYPE_DICTIONARY:
			return {"ok": false, "error": "Each payout entry must be an object"}
		rewards.append((reward_any as Dictionary).duplicate(true))
	return {"ok": true, "rewards": rewards}

func _parse_contest_id(contest_id_str: String) -> Dictionary:
	if contest_state != null:
		return contest_state.parse_contest_id(contest_id_str)
	return {}

func _build_contest_id(parts: Dictionary) -> String:
	if contest_state != null and contest_state.has_method("build_contest_id"):
		return str(contest_state.call("build_contest_id", parts))
	return _normalize_contest_id(contest_id.text)

func _normalize_contest_id(contest_id_str: String) -> String:
	if contest_state != null:
		return contest_state.normalize_contest_id(contest_id_str)
	return contest_id_str
