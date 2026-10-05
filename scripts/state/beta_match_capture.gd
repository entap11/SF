extends Node

const Record := preload("res://scripts/state/beta_capture_record.gd")
const BackendPolicy := preload("res://scripts/state/test_backend_policy.gd")
const Feedback := preload("res://scripts/state/beta_feedback_record.gd")
const FeedbackPanel := preload("res://scripts/ui/beta_feedback_panel.gd")
const ROOT := "user://beta_captures"
const PREFS := "user://beta_capture_sharing.json"
const MAX_QUEUE_BYTES := 256 * 1024 * 1024
const MAX_QUEUE_FILES := 1000
var _collector: RefCounted
var _context: Dictionary = {}
var _writer: Thread
var _http: HTTPRequest
var _sharing := "undecided"
var _stopped := false
var _dialog: ConfirmationDialog
var _next_upload_ms := 0
var _retry_ms := 5000
var _last_attempt_path := ""
var last_error := ""
var _feedback_panel: Variant = null
var _feedback_ready_ms := 0

func _ready() -> void:
	if not enabled():
		return
	if FileAccess.file_exists(PREFS):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS))
		if value is Dictionary:
			_sharing = str(value.get("sharing", "undecided"))
	var timer := Timer.new()
	timer.wait_time = 15.0
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()
	var feedback_timer := Timer.new()
	feedback_timer.wait_time = 2.0
	feedback_timer.timeout.connect(_check_feedback_prompt)
	add_child(feedback_timer)
	feedback_timer.start()

func enabled() -> bool:
	return not _stopped and not FileAccess.file_exists("user://account_deletion_receipt.json") and (OS.has_feature("beta_capture") or (OS.is_debug_build() and OS.get_cmdline_user_args().has("--beta-capture"))) and not BackendPolicy.performance_harness_active()

func begin(collector: RefCounted, metadata: Dictionary) -> void:
	if not enabled():
		return
	skip_feedback()
	finish("abandoned")
	if _http != null:
		_http.cancel_request()
		_http.queue_free()
		_http = null
	_flush_writer()
	var queue := queue_status()
	if int(queue.files) >= MAX_QUEUE_FILES or int(queue.bytes) >= MAX_QUEUE_BYTES:
		last_error = "Beta recording storage is full. Connect to upload saved games."
		return
	_collector = collector
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/beta_capture_build.json"))
	var build: Dictionary = manifest if manifest is Dictionary else {}
	var owner := str(ProfileManager.get_user_id())
	metadata = metadata.duplicate(true)
	if BotEvaluationSession.is_active() and str(metadata.get("map_path", "")).is_empty():
		var map_path := str(BotEvaluationSession.descriptor().get("map_path", ""))
		metadata["map_path"] = map_path
		metadata["map_sha256"] = FileAccess.get_sha256(map_path) if FileAccess.file_exists(map_path) else ""
	if metadata.get("shared_match_key", "") == "".sha256_text():
		metadata["shared_match_key"] = ""
	_context = {
		"capture_id": Crypto.new().generate_random_bytes(16).hex_encode(),
		"owner_key": owner.sha256_text(), "build": str(build.get("build", "development")),
		"source_sha256": str(build.get("source_sha256", "")),
		"engine": "%d.%d.%d" % [Engine.get_version_info().major, Engine.get_version_info().minor, Engine.get_version_info().patch], "platform": OS.get_name(),
		"status": "interrupted", "sim_ms": 0, "winner_seat": 0, "metadata": metadata.duplicate(true)
	}
	checkpoint()

func checkpoint() -> void:
	if not enabled() or _collector == null or (_writer != null and _writer.is_alive()):
		return
	_save("interrupted", 0, false)

func finish(status: String, winner: int = 0) -> void:
	if _collector == null:
		return
	if enabled():
		_save(status, winner, true)
	_collector = null
	_context.clear()

func _save(status: String, winner: int, wait_previous: bool) -> void:
	if wait_previous:
		_flush_writer()
	elif _writer != null:
		_flush_writer()
	_context.metadata["end_reason"] = str(OpsState.match_end_reason) if status == "completed" else status
	_context["status"] = status
	_context["winner_seat"] = maxi(0, winner)
	_context["sim_ms"] = maxi(0, int(OpsState.match_elapsed_ms))
	var ads := get_node_or_null("/root/AdManager")
	if ads != null:
		_context.metadata["ad_diagnostics"] = ads.call("get_diagnostics_snapshot")
	var snapshot: Dictionary = _collector.call("beta_capture_snapshot", _context)
	var path := ROOT.path_join(str(_context.owner_key)).path_join(str(_context.capture_id) + ".json.gz")
	_writer = Thread.new()
	if _writer.start(Record.write_atomic.bind(snapshot, path)) != OK:
		_writer = null
		last_error = "Beta recording could not be saved."
	elif status == "completed" and int(_context.metadata.get("local_seat", 0)) > 0:
		offer_feedback(_context)

func _flush_writer() -> void:
	if _writer == null:
		return
	var result: Variant = _writer.wait_to_finish()
	_writer = null
	if result is Dictionary and not bool(result.get("ok", false)):
		last_error = str(result.get("error", "capture_save_failed"))

func _tick() -> void:
	if not enabled():
		return
	if _collector != null:
		checkpoint()
		return
	if OpsState.is_match_running():
		return
	if _writer != null:
		if _writer.is_alive():
			return
		_flush_writer()
	if _sharing == "undecided" and not BackendPolicy.automated_test_process():
		show_sharing_choice()
	if _sharing == "allowed" and Time.get_ticks_msec() >= _next_upload_ms:
		_upload_next()

func queue_status() -> Dictionary:
	var paths := pending_paths()
	var size := 0
	for path in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			size += file.get_length()
	return {"files": paths.size(), "bytes": size, "sharing": _sharing, "error": last_error}

func pending_paths() -> Array[String]:
	var paths: Array[String] = []
	if not DirAccess.dir_exists_absolute(ROOT):
		return paths
	for owner in DirAccess.get_directories_at(ROOT):
		for name in DirAccess.get_files_at(ROOT.path_join(owner)):
			if name.ends_with(".json.gz") or name.ends_with(".feedback.json"):
				paths.append(ROOT.path_join(owner).path_join(name))
	paths.sort()
	return paths

func _upload_next() -> void:
	if not enabled() or _sharing != "allowed" or _http != null or _collector != null or OpsState.is_match_running():
		return
	var identity := get_node_or_null("/root/PlayerIdentityRuntime")
	if identity == null or not bool(identity.call("is_authenticated")):
		return
	var owner_key := str(identity.call("debug_snapshot").get("player_id", "")).sha256_text()
	var path := ""
	var eligible: Array[String] = []
	for candidate in pending_paths():
		if candidate.get_base_dir().get_file() == owner_key:
			# A feedback receipt must never replace the immutable game receipt.
			if candidate.ends_with(".feedback.json") and FileAccess.file_exists(candidate.trim_suffix(".feedback.json") + ".json.gz"):
				continue
			eligible.append(candidate)
	for candidate in eligible:
		if candidate > _last_attempt_path:
			path = candidate
			break
	if path.is_empty() and not eligible.is_empty():
		path = eligible[0]
	if path.is_empty():
		return
	var endpoint := str(ProjectSettings.get_setting("swarmfront/identity/backend_url", "")).trim_suffix("/") + "/beta-captures"
	var is_feedback := path.ends_with(".feedback.json")
	if is_feedback:
		endpoint += "/" + path.get_file().trim_suffix(".feedback.json") + "/feedback"
	if not endpoint.begins_with("https://") and not (OS.is_debug_build() and BackendPolicy.is_loopback_url(endpoint)):
		return
	if not BackendPolicy.request_allowed(endpoint):
		return
	_last_attempt_path = path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var body := file.get_buffer(file.get_length())
	var digest := FileAccess.get_sha256(path)
	_http = HTTPRequest.new()
	_http.timeout = 25.0
	_http.max_redirects = 0
	_http.body_size_limit = 16384
	add_child(_http)
	_http.request_completed.connect(_uploaded.bind(path, digest), CONNECT_ONE_SHOT)
	var content_type := "application/json" if is_feedback else "application/gzip"
	var headers := PackedStringArray(["Content-Type: " + content_type, "X-Capture-SHA256: " + digest, "Authorization: Bearer " + str(identity.call("access_token"))])
	if _http.request_raw(endpoint, headers, HTTPClient.METHOD_POST, body) != OK:
		_uploaded(-1, 0, PackedStringArray(), PackedByteArray(), path, digest)

func _uploaded(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, path: String, digest: String) -> void:
	if _http != null:
		_http.queue_free()
		_http = null
	var response: Variant = JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else {}
	var accepted := false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and response is Dictionary:
		accepted = Feedback.acknowledge(path, response, digest) if path.ends_with(".feedback.json") else Record.acknowledge(path, response, digest)
	if accepted:
		_retry_ms = 5000
		last_error = ""
	else:
		_retry_ms = mini(_retry_ms * 2, 300000)
		last_error = "Beta upload pending (%d). Saved games will retry." % code
	_next_upload_ms = Time.get_ticks_msec() + _retry_ms

func set_sharing(allowed: bool) -> void:
	_sharing = "allowed" if allowed else "local"
	var file := FileAccess.open(PREFS + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Sharing preference could not be saved."
		_sharing = "undecided"
		return
	file.store_string(JSON.stringify({"sharing": _sharing}))
	file.close()
	if DirAccess.rename_absolute(PREFS + ".tmp", PREFS) != OK:
		_sharing = "undecided"
	if not allowed and _http != null:
		_http.cancel_request()
		_http.queue_free()
		_http = null

func show_sharing_choice() -> void:
	if _dialog != null or _feedback_panel != null or not enabled() or OpsState.is_match_running():
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Help improve Swarmfront"
	_dialog.dialog_text = "Share recordings of your beta games?\n\nMoves, board samples, results and bot versions help us improve the game for different skill levels. Recordings are linked to your tester account. Names, chat and payment details are excluded.\n\nGames save offline and upload between matches. You can change this choice in Support."
	_dialog.get_label().add_theme_font_size_override("font_size", 24)
	_dialog.get_ok_button().add_theme_font_size_override("font_size", 24)
	_dialog.get_cancel_button().add_theme_font_size_override("font_size", 24)
	_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog.ok_button_text = "Share beta games"
	_dialog.cancel_button_text = "Keep on this device"
	_dialog.confirmed.connect(func() -> void: set_sharing(true); _close_dialog())
	_dialog.canceled.connect(func() -> void: set_sharing(false); _close_dialog())
	add_child(_dialog)
	_dialog.popup_centered(Vector2i(800, 500))

func _close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null

func stop_for_account_deletion() -> void:
	_stopped = true
	_collector = null
	_context.clear()
	_flush_writer()
	if _http != null:
		_http.cancel_request()
		_http.queue_free()
		_http = null
	_close_dialog()
	_close_feedback_panel()

func offer_feedback(context: Dictionary) -> void:
	if not enabled():
		return
	var prompt := {"capture_id": str(context.capture_id), "owner_key": str(context.owner_key)}
	if not Feedback.write_json(Feedback.PROMPT_PATH, prompt):
		last_error = "Feedback prompt could not be saved."
	_feedback_ready_ms = Time.get_ticks_msec() + 2000

func _check_feedback_prompt() -> void:
	if not BackendPolicy.automated_test_process() and Time.get_ticks_msec() >= _feedback_ready_ms:
		show_feedback_prompt()

func show_feedback_prompt() -> void:
	if not enabled() or _collector != null or OpsState.is_match_running() or _dialog != null or _feedback_panel != null:
		return
	var pending := Feedback.read_json(Feedback.PROMPT_PATH)
	var owner_key := str(ProfileManager.get_user_id()).sha256_text()
	if pending.is_empty() or pending.get("owner_key") != owner_key:
		return
	var preferences := Feedback.read_json(Feedback.EXPERIENCE_PATH)
	_feedback_panel = FeedbackPanel.new()
	_feedback_panel.configure(str(preferences.get(owner_key, "unknown")), pending.get("draft", {}))
	_feedback_panel.submitted.connect(submit_feedback)
	_feedback_panel.skipped.connect(skip_feedback)
	_feedback_panel.answers_changed.connect(save_feedback_draft)
	add_child(_feedback_panel)

func save_feedback_draft(answers: Dictionary) -> void:
	var prompt := Feedback.read_json(Feedback.PROMPT_PATH)
	if not enabled() or prompt.is_empty() or prompt.get("owner_key") != str(ProfileManager.get_user_id()).sha256_text():
		return
	for key in answers:
		if not Feedback.VALUES.has(key) or answers[key] not in Feedback.VALUES[key]:
			return
	prompt["draft"] = answers.duplicate()
	if not Feedback.write_json(Feedback.PROMPT_PATH, prompt):
		last_error = "Feedback draft could not be saved."

func submit_feedback(answers: Dictionary) -> bool:
	if not enabled() or _collector != null or OpsState.is_match_running() or not Feedback.valid_answers(answers):
		return false
	var prompt := Feedback.read_json(Feedback.PROMPT_PATH)
	var owner_key := str(ProfileManager.get_user_id()).sha256_text()
	if prompt.is_empty() or prompt.get("owner_key") != owner_key:
		return false
	var payload := {"schema_version": 1, "capture_id": str(prompt.capture_id), "owner_key": owner_key, "answers": answers.duplicate()}
	var path := ROOT.path_join(owner_key).path_join(str(prompt.capture_id) + ".feedback.json")
	if FileAccess.file_exists(path):
		if Feedback.read_json(path) == payload:
			skip_feedback()
			return true
		return false
	var queue := queue_status()
	if int(queue.files) >= MAX_QUEUE_FILES or int(queue.bytes) >= MAX_QUEUE_BYTES or not Feedback.write_json(path, payload):
		last_error = "Feedback could not be saved. Try again or skip."
		if _feedback_panel != null:
			_feedback_panel.show_error(last_error)
		return false
	var preferences := Feedback.read_json(Feedback.EXPERIENCE_PATH)
	preferences[owner_key] = answers.experience
	Feedback.write_json(Feedback.EXPERIENCE_PATH, preferences)
	skip_feedback()
	return true

func skip_feedback() -> void:
	if FileAccess.file_exists(Feedback.PROMPT_PATH):
		DirAccess.remove_absolute(Feedback.PROMPT_PATH)
	_close_feedback_panel()

func _close_feedback_panel() -> void:
	if _feedback_panel != null:
		_feedback_panel.queue_free()
		_feedback_panel = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		checkpoint()
		_flush_writer()

func _exit_tree() -> void:
	finish("interrupted")
	_flush_writer()
