extends SceneTree

const ProfileManagerScript = preload("res://scripts/profile/profile_manager.gd")
const BattlePassRewards = preload("res://scripts/state/battle_pass_rewards.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")
const BuffState = preload("res://scripts/state/buff_state.gd")

const PREMIUM_BUFF: String = "buff_unit_speed_premium"
const STARTER_HIVE: String = "buff_hive_faster_production_classic"
const STARTER_TOWER: String = "buff_tower_fire_rate_classic"
const TEST_USER_ID: String = "018f2b2c-1234-7abc-8def-123456789abc"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.cfg"))

	var profile: Node = ProfileManagerScript.new()
	profile.name = "BuffInventoryTestProfile"
	get_root().add_child(profile)
	await process_frame
	profile.call("smoke_force_identity_state", TEST_USER_ID, "ABC 123", "BuffSmoke", true, true)

	var original_inventory: Dictionary = profile.call("get_buff_inventory_snapshot") as Dictionary
	var original_revision: String = str(profile.call("get_buff_inventory_revision"))
	_assert_true(not (original_inventory.get("vs", []) as Array).has(PREMIUM_BUFF), "premium buff starts unowned")
	var original_loadout: Array = profile.call("get_buff_loadout_ids_for_mode", "vs") as Array
	var rejected: bool = bool(profile.call("set_buff_loadout_ids_for_mode", "vs", [PREMIUM_BUFF, STARTER_HIVE, STARTER_TOWER]))
	_assert_true(not rejected, "unowned buff cannot be equipped")
	_assert_true((profile.call("get_buff_loadout_ids_for_mode", "vs") as Array) == original_loadout, "rejected equip does not mutate loadout")
	_assert_true((profile.call("get_buff_inventory_snapshot") as Dictionary) == original_inventory, "rejected equip does not fabricate ownership")

	var rewards := BattlePassRewards.new()
	var reward_result: Dictionary = rewards.grant_reward({
		"reward_type": "buff",
		"buff_id": PREMIUM_BUFF,
		"quantity": 3
	}, {}, {}, profile)
	_assert_ok(reward_result, "battle pass buff grant")
	_assert_true(not (reward_result.get("inventory", {}) as Dictionary).has("buffs"), "battle pass has no second buff ledger")
	_assert_true(bool(profile.call("owns_buff", PREMIUM_BUFF, "vs", 1)), "grant reaches VS inventory")
	_assert_true(int(profile.call("get_owned_buff_quantity", PREMIUM_BUFF, "vs")) == 3, "reward quantity reaches shared inventory")
	_assert_true(int(profile.call("get_owned_buff_quantity", PREMIUM_BUFF, "async")) == 3, "mode views share one inventory quantity")
	_assert_true(str(profile.call("get_buff_inventory_revision")) != original_revision, "inventory revision changes after a committed grant")

	var vs_loadout: Array = [PREMIUM_BUFF, STARTER_HIVE, STARTER_TOWER]
	var async_loadout: Array = [PREMIUM_BUFF, STARTER_HIVE, STARTER_TOWER]
	_assert_true(bool(profile.call("set_buff_loadout_ids_for_mode", "vs", vs_loadout)), "owned VS buff equips")
	_assert_true(bool(profile.call("set_buff_loadout_ids_for_mode", "async", async_loadout)), "owned Async buff equips")
	_assert_true(
		not bool(profile.call("set_buff_loadout_ids_for_mode", "async", [PREMIUM_BUFF, PREMIUM_BUFF, STARTER_TOWER])),
		"stacked inventory does not create duplicate Async loadout slots"
	)

	profile.free()
	var reloaded: Node = ProfileManagerScript.new()
	reloaded.name = "BuffInventoryReloadedProfile"
	get_root().add_child(reloaded)
	await process_frame
	_assert_true((reloaded.call("get_buff_loadout_ids_for_mode", "vs") as Array) == vs_loadout, "VS loadout survives restart")
	_assert_true((reloaded.call("get_buff_loadout_ids_for_mode", "async") as Array) == async_loadout, "Async loadout survives restart")
	_assert_true(int(reloaded.call("get_owned_buff_quantity", PREMIUM_BUFF, "async")) == 3, "inventory quantity survives restart")

	var legacy_inventory: Dictionary = {"buffs": {PREMIUM_BUFF: {"owned": true}}}
	var before_migration_quantity: int = int(reloaded.call("get_owned_buff_quantity", PREMIUM_BUFF, "async"))
	rewards.migrate_legacy_buff_inventory(legacy_inventory, reloaded)
	_assert_true(int(reloaded.call("get_owned_buff_quantity", PREMIUM_BUFF, "async")) == before_migration_quantity, "legacy migration is idempotent")

	var runtime_entries: Array = []
	for buff_id_any in reloaded.call("get_buff_loadout_ids_for_mode", "vs") as Array:
		var buff_id: String = str(buff_id_any)
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		runtime_entries.append({"id": buff_id, "tier": str(buff.get("tier", "classic"))})
	var runtime := BuffState.new()
	runtime_entries[0]["uses"] = 2
	runtime_entries[0]["uses_total"] = 2
	_assert_ok(runtime.configure_loadout(runtime_entries), "runtime loadout configuration")
	runtime.update(1000)
	_assert_true(runtime.activate_slot(0, 1000, {"owner_id": 1, "hive_id": 1}), "equipped premium buff activates")
	var active_unit: Variant = runtime.get_active_unit_buff()
	_assert_true(typeof(active_unit) == TYPE_DICTIONARY, "runtime reports active buff")
	_assert_true(str((active_unit as Dictionary).get("tier", "")) == "premium", "runtime preserves premium tier")
	_assert_true(int((runtime.slots[0] as Dictionary).get("uses_remaining", 0)) == 1, "Async first activation leaves one contest use")
	runtime.update(20000)
	_assert_true(runtime.activate_slot(0, 20000, {"owner_id": 1, "hive_id": 1}), "Async second contest use activates")
	_assert_true(int((runtime.slots[0] as Dictionary).get("uses_remaining", -1)) == 0, "second activation exhausts contest allowance")
	_assert_true(not runtime.can_activate_slot(0), "exhausted Async buff cannot activate again")

	var consume_result: Dictionary = reloaded.call("consume_buff", PREMIUM_BUFF, 1, "smoke_activation") as Dictionary
	_assert_ok(consume_result, "shared inventory consumption")
	_assert_true(int(reloaded.call("get_owned_buff_quantity", PREMIUM_BUFF, "vs")) == 2, "consumption decrements VS view")
	_assert_true(int(reloaded.call("get_owned_buff_quantity", PREMIUM_BUFF, "async")) == 2, "consumption decrements Async view")

	print("BUFF_INVENTORY_WIRING_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [label, str(result)])

func _assert_true(condition: bool, label: String) -> void:
	if condition:
		return
	_fail(label)

func _fail(message: String) -> void:
	push_error("BUFF_INVENTORY_WIRING_SMOKE: %s" % message)
	quit(1)
