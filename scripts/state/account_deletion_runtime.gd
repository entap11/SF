extends Node

## Owns deletion requests and local sign-out. UI emits intent; it never edits saves.
const RECEIPT_PATH := "user://account_deletion_receipt.json"
const HELP_URL := "https://swarmfront.games/delete-account/"
const Typography := preload("res://scripts/ui/ui_typography.gd")
const BackendPolicy := preload("res://scripts/state/test_backend_policy.gd")
const CredentialFactory := preload("res://scripts/platform/secure_credential_store_factory.gd")
const LOCAL_FILES: Array[String] = [
	"profile.cfg", "player_identity_bootstrap.json", "rank_state.json", "battle_pass_state.json",
	"swarm_pass_state.json", "swarm_pass_telemetry.json", "honey_progression_state.json",
	"economy_buff_state.json", "crucible_state.json", "hive_clan_state.json", "scholastic_state.json",
	"moderation_state.json", "contest_entries.json", "contest_leaderboards_v1.json",
	"public_contest_pending_evidence_v1.json", "match_records_v1.json", "progressive_run_v1.json",
	"jukebox_leaderboard_v1.json", "player_telemetry_profiles_v1.json", "analytics_queue_v1.jsonl",
	"analytics_state_v1.json", "bot_intent_telemetry_v1.jsonl", "bot_intent_summary_v1.json",
	"vs_handshake_diagnostics.jsonl", "vs_contract_violations.jsonl"
]
const LOCAL_DIRS: Array[String] = ["matches", "exports", "pvp_runtime", "logs"]

var _receipt: Dictionary = {}
var _layer: CanvasLayer
var _message: Label
var _confirm: Button
var _cancel: Button
var _busy := false
var _was_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(RECEIPT_PATH):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECEIPT_PATH))
		if typeof(value) == TYPE_DICTIONARY:
			_receipt = value as Dictionary
		else:
			_receipt = {"stage": "receipt_unreadable"}
		if str(_receipt.get("stage", "")) == "accepted":
			_clear_local_files()
			_delete_device_key()
		call_deferred("open_deletion")

func blocks_account_use() -> bool:
	return not _receipt.is_empty() or FileAccess.file_exists(RECEIPT_PATH)

func account_deleted_on_another_device() -> void:
	_receipt = {"application_id": "swarmfront", "stage": "accepted", "status": "pending", "remote_revocation": true}
	_save_receipt()
	open_deletion()
	_accept_receipt(_receipt.duplicate(true))

func open_deletion() -> void:
	if _layer != null:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var background := ColorRect.new()
	background.color = Color(0.035, 0.045, 0.065, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 48)
	background.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 28)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "DELETE SWARMFRONT ACCOUNT"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Typography.apply_token(title, Typography.semibold_font(), "screen_title", 2.0)
	box.add_child(title)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Typography.apply_token(_message, Typography.regular_font(), "body", 2.0)
	box.add_child(_message)
	_confirm = _button(box, "Permanently Delete Account", _on_confirm)
	_confirm.add_theme_color_override("font_color", Color(1.0, 0.48, 0.43))
	_cancel = _button(box, "Cancel", _on_cancel)
	_button(box, "Deletion details and help", func() -> void: OS.shell_open(HELP_URL))
	if blocks_account_use():
		_render_receipt()
	else:
		var profile := get_node_or_null("/root/ProfileManager")
		var call_sign: String = str(profile.call("get_call_sign")) if profile != null else "this account"
		_message.text = "Delete %s?\n\nThis requests permanent deletion of your Swarmfront account and associated personal data. Your ENTaP account and access to other ENTaP apps are not affected. Progress, rankings, inventory and currency cannot be recovered after deletion. This is not an archive.\n\nYour Swarmfront access will be disabled when the server accepts the request. We aim to finish within seven days; some records may need review. Limited legal, transaction, security and backup records may be retained, with the reason and expiry disclosed in your completion details.\n\nDeleting your account does not request a refund. Manage any Google Play subscriptions separately in Google Play.\n\nContinue only if you want permanent deletion." % call_sign
	_cancel.grab_focus()

func _button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	Typography.apply_button_token(button, Typography.semibold_font(), "button", 2.0, 88.0)
	button.pressed.connect(action)
	box.add_child(button)
	return button

func _on_cancel() -> void:
	if _busy:
		return
	if blocks_account_use():
		get_tree().quit()
		return
	_layer.queue_free()
	_layer = null
	get_tree().paused = _was_paused

func _on_confirm() -> void:
	if _busy:
		return
	_busy = true
	_confirm.disabled = true
	_cancel.disabled = true
	if blocks_account_use():
		await _refresh_receipt()
	else:
		await _submit_deletion()
	_busy = false
	_confirm.disabled = false
	_cancel.disabled = false

func _submit_deletion() -> void:
	var identity := get_node_or_null("/root/PlayerIdentityRuntime")
	if identity == null or not bool(identity.call("is_authenticated")):
		_message.text = "We could not verify this account on this device. No deletion request was submitted. Connect to the internet and try again, or use Deletion details and help to request deletion through Support."
		return
	_message.text = "Verifying account ownership…"
	var request_id := "delete-" + _random_token(16)
	var receipt_token := _random_token(32)
	var challenge: Dictionary = await _post("account/deletion/challenge", {
		"request_id": request_id, "receipt_token": receipt_token
	}, str(identity.call("access_token")))
	if not bool(challenge.get("ok", false)):
		_message.text = "No deletion request was accepted. Please try again or contact Support. (%s)" % str(challenge.get("err", "unavailable"))
		return
	var signed: Dictionary = identity.call("sign_account_deletion_challenge", str(challenge.get("challenge", ""))) as Dictionary
	if not bool(signed.get("ok", false)):
		_message.text = "We could not verify ownership. No deletion request was submitted. Use Deletion details and help for assistance."
		return
	_receipt = {"request_id": request_id, "receipt_token": receipt_token,
		"signature": str(signed.get("signature", "")), "stage": "submitting"}
	# Persist BEFORE sending: a lost response must not strand a revoked account.
	if not _save_receipt():
		_receipt = {}
		_message.text = "We could not save your request receipt. No deletion request was submitted. Free some storage and try again."
		return
	await _send_confirmation()

func _send_confirmation() -> void:
	var response: Dictionary = await _post("account/deletion/confirm", {
		"request_id": _receipt.get("request_id", ""), "receipt_token": _receipt.get("receipt_token", ""),
		"signature": _receipt.get("signature", ""), "confirmation": "DELETE"
	})
	if bool(response.get("ok", false)):
		_accept_receipt(response)
	elif int(response.get("http_status", 0)) in [400, 401, 410]:
		# These are definitive pre-acceptance failures. Confirm retries for accepted requests
		# return their receipt before evaluating the expired proof.
		DirAccess.remove_absolute(RECEIPT_PATH)
		_receipt = {}
		_confirm.text = "Permanently Delete Account"
		_cancel.text = "Cancel"
		_message.text = "The request was not accepted. Please try again. (%s)" % str(response.get("err", "verification_failed"))
	else:
		_render_receipt("We could not confirm whether the server accepted your request. Check status to safely retry; your account has not been recreated.")

func _refresh_receipt() -> void:
	if not _receipt.has("receipt_token"):
		_render_receipt("This device cannot read its request receipt. Contact Support for status; do not send device credentials.")
		return
	_message.text = "Checking deletion status…"
	var response: Dictionary = await _post("account/deletion/status", {
		"request_id": _receipt.get("request_id", ""), "receipt_token": _receipt.get("receipt_token", "")
	})
	if bool(response.get("ok", false)):
		_accept_receipt(response)
	elif str(response.get("err", "")) == "deletion_request_not_found" and str(_receipt.get("stage", "")) == "submitting":
		await _send_confirmation()
	else:
		_render_receipt("Status is unavailable. Your saved request receipt is safe. Please try again or contact Support.")

func _accept_receipt(response: Dictionary) -> void:
	if str(response.get("application_id", "")) != "swarmfront" \
		or not str(response.get("status", "")) in ["pending", "completed"] \
		or (not bool(_receipt.get("remote_revocation", false)) \
		and str(response.get("request_id", "")) != str(_receipt.get("request_id", ""))):
		_render_receipt("The server returned an invalid receipt. Please check status again or contact Support.")
		return
	_receipt.merge(response, true)
	_receipt["stage"] = "accepted"
	_receipt.erase("signature")
	_save_receipt()
	var identity := get_node_or_null("/root/PlayerIdentityRuntime")
	if identity != null:
		identity.call("sign_out_for_account_deletion")
	var analytics := get_node_or_null("/root/AnalyticsClient")
	if analytics != null:
		analytics.call("stop_for_account_deletion")
	# This alias belongs only to the Swarmfront app, never the ENTaP app.
	var key_removed: bool = _delete_device_key()
	var failures: Array[String] = _clear_local_files()
	_render_receipt("Some local data could not be removed. Close and reopen the game to retry cleanup." if not failures.is_empty() or not key_removed else "")

func _render_receipt(extra: String = "") -> void:
	var completed: bool = str(_receipt.get("status", "")) == "completed"
	_message.text = "Swarmfront account deletion complete. Your game progress cannot be restored. Your ENTaP account is unaffected." if completed else "Swarmfront deletion requested. Swarmfront access is unavailable while the request is processed. Your ENTaP account is unaffected."
	if str(_receipt.get("stage", "")) == "submitting":
		_message.text = "Deletion request awaiting confirmation."
	_message.text += "\n\nRequest reference: %s" % str(_receipt.get("request_id", "Unavailable"))
	if _receipt.has("target_at") and not completed:
		_message.text += "\nTarget completion: %s\nThis is a target, not a completion confirmation." % str(_receipt.target_at).substr(0, 10)
	for item in _receipt.get("retained_information", []):
		if typeof(item) == TYPE_DICTIONARY:
			_message.text += "\n\nRetained: %s\nReason: %s\nUntil: %s" % [str(item.get("category", "")), str(item.get("reason", "")), str(item.get("expires_at", "")).substr(0, 10)]
	if not extra.is_empty():
		_message.text += "\n\n" + extra
	_confirm.text = "Check deletion status"
	_cancel.text = "Close game"

func _post(path: String, body: Dictionary, token: String = "") -> Dictionary:
	var base: String = str(ProjectSettings.get_setting("swarmfront/identity/backend_url", "https://swarmfront-cert-rank.onrender.com/v1")).trim_suffix("/")
	if not base.begins_with("https://") and not (OS.is_debug_build() and BackendPolicy.is_loopback_url(base)):
		return {"ok": false, "err": "secure_connection_required"}
	if not BackendPolicy.request_allowed(base):
		return {"ok": false, "err": "test_backend_blocked"}
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var error: int = http.request(base + "/" + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		http.queue_free()
		return {"ok": false, "err": "request_failed"}
	var reply: Array = await http.request_completed
	http.queue_free()
	if int(reply[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "err": "connection_unavailable"}
	var decoded: Variant = JSON.parse_string((reply[3] as PackedByteArray).get_string_from_utf8())
	if typeof(decoded) != TYPE_DICTIONARY:
		return {"ok": false, "err": "invalid_response"}
	var result: Dictionary = decoded as Dictionary
	result["http_status"] = int(reply[1])
	if int(reply[1]) < 200 or int(reply[1]) >= 300:
		result["ok"] = false
	return result

func _delete_device_key() -> bool:
	var credentials = CredentialFactory.create()
	if not bool(credentials.call("is_available")):
		return false
	var result: Dictionary = credentials.call("delete_device_key", "swarmfront.player.identity.v1") as Dictionary
	return bool(result.get("ok", false))

func _save_receipt() -> bool:
	var file := FileAccess.open(RECEIPT_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_receipt))
	file.flush()
	var result: int = file.get_error()
	file.close()
	return result == OK and DirAccess.rename_absolute(RECEIPT_PATH + ".tmp", RECEIPT_PATH) == OK

func _random_token(size: int) -> String:
	return Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(size)).replace("+", "-").replace("/", "_").replace("=", "")

func _clear_local_files() -> Array[String]:
	var failed: Array[String] = []
	for name in LOCAL_FILES:
		var path := "user://" + name
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			failed.append(path)
	for name in LOCAL_DIRS:
		_remove_directory("user://" + name, failed)
	return failed

func _remove_directory(path: String, failed: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for name in directory.get_files():
		if DirAccess.remove_absolute(path.path_join(name)) != OK:
			failed.append(path.path_join(name))
	for name in directory.get_directories():
		_remove_directory(path.path_join(name), failed)
	if DirAccess.remove_absolute(path) != OK:
		failed.append(path)
