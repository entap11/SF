extends SceneTree

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontDeletionTest-"):
		push_error("Run only with an isolated SwarmfrontDeletionTest-* custom user directory.")
		quit(2)
		return
	await process_frame
	var runtime := root.get_node("AccountDeletionRuntime")
	var panel_scene := load("res://scenes/ui/settings/profile_settings_panel.tscn") as PackedScene
	var panel := panel_scene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	var delete_button := panel.get_node_or_null("SettingsScroll/VBox/AccountDeletionSection/DeleteAccountButton") as Button
	_expect(delete_button != null and delete_button.visible, "Account tab exposes Delete Account")
	_expect(delete_button.custom_minimum_size.y >= 88.0, "Delete button meets mobile touch size")
	delete_button.pressed.emit()
	await process_frame
	_expect(paused, "confirmation pauses gameplay")
	_expect(not FileAccess.file_exists("user://account_deletion_receipt.json"), "opening confirmation does not submit a request")
	runtime.call("_on_cancel")
	await process_frame
	_expect(not paused, "Cancel restores game state")
	_expect(not FileAccess.file_exists("user://account_deletion_receipt.json"), "Cancel does not write deletion intent")
	panel.call("_set_active_category", "support")
	_expect(not panel.get_node("SettingsScroll/VBox/AccountDeletionSection").visible, "Account controls stay in Account")
	var support := panel.get_node_or_null("SettingsScroll/VBox/SupportSection/AccountDeletionHelpButton") as Button
	_expect(support != null and support.is_visible_in_tree(), "Support exposes a deletion shortcut")
	support.pressed.emit()
	await process_frame
	await runtime.call("_on_confirm")
	_expect(not FileAccess.file_exists("user://account_deletion_receipt.json"), "unverified device cannot submit deletion")
	runtime.call("_on_cancel")
	var profile := FileAccess.open("user://profile.cfg", FileAccess.WRITE)
	profile.store_string("deletion-test-personal-data")
	profile.close()
	var unrelated := FileAccess.open("user://unrelated-test.txt", FileAccess.WRITE)
	unrelated.store_string("preserve")
	unrelated.close()
	DirAccess.make_dir_recursive_absolute("user://matches/nested")
	var match_file := FileAccess.open("user://matches/nested/private.json", FileAccess.WRITE)
	match_file.store_string("{}")
	match_file.close()
	var failures: Array = runtime.call("_clear_local_files") as Array
	_expect(failures.is_empty(), "local cleanup succeeds")
	_expect(not FileAccess.file_exists("user://profile.cfg"), "profile is removed")
	_expect(not DirAccess.dir_exists_absolute("user://matches"), "nested match records are removed")
	_expect(FileAccess.file_exists("user://unrelated-test.txt"), "cleanup is limited to account-owned paths")
	# A malformed/mismatched server reply must never erase a local account.
	runtime.call("open_deletion")
	profile = FileAccess.open("user://profile.cfg", FileAccess.WRITE)
	profile.store_string("receipt-validation-fixture")
	profile.close()
	runtime.set("_receipt", {"request_id": "ui-delete-test", "receipt_token": "A".repeat(43),
		"signature": "test-proof", "stage": "submitting"})
	_expect(bool(runtime.call("_save_receipt")), "receipt is persisted before confirmation")
	runtime.call("_accept_receipt", {"application_id": "swarmfront", "request_id": "wrong-request", "status": "completed"})
	_expect(FileAccess.file_exists("user://profile.cfg"), "wrong receipt cannot erase local data")
	runtime.call("_accept_receipt", {"application_id": "swarmfront", "request_id": "ui-delete-test", "status": "unexpected"})
	_expect(FileAccess.file_exists("user://profile.cfg"), "unknown status cannot erase local data")
	runtime.call("_accept_receipt", {"application_id": "entap", "request_id": "ui-delete-test", "status": "pending"})
	_expect(FileAccess.file_exists("user://profile.cfg"), "another application's receipt cannot erase local data")
	runtime.call("_accept_receipt", {"application_id": "swarmfront", "request_id": "ui-delete-test", "status": "pending"})
	_expect(not FileAccess.file_exists("user://profile.cfg"), "accepted receipt signs out and cleans local account")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://account_deletion_receipt.json")) as Dictionary
	_expect(str(saved.get("stage", "")) == "accepted" and str(saved.get("status", "")) == "pending", "pending is not reported as complete")
	_expect(not saved.has("signature") and saved.has("receipt_token"), "private status receipt survives while device proof is discarded")
	DirAccess.remove_absolute("user://account_deletion_receipt.json")
	print("ACCOUNT_DELETION_UI_SMOKE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
