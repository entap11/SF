extends SceneTree

const EconomyBuffStateScript = preload("res://scripts/state/economy_buff_state.gd")

const PLAYER_ID: String = "p1"
const BUFF_CLASSIC: String = "buff_unit_speed_classic"
const BUFF_PREMIUM: String = "buff_unit_speed_premium"
const BUFF_ELITE: String = "buff_unit_speed_elite"
const BUFF_ELITE_2: String = "buff_swarm_damage_elite"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://economy_buff_state.json"))

	var state: Node = EconomyBuffStateScript.new()
	state.name = "EconomyBuffState"
	get_root().add_child(state)
	await process_frame

	_assert_ok(state.intent_register_player(PLAYER_ID), "register player")
	_assert_ok(state.intent_set_wallet(PLAYER_ID, {"nectar": 500, "honey": 0, "wax": 0, "usd": 0}), "seed wallet")

	# A) Standard mode rules
	_assert_ok(state.intent_set_mode("STANDARD"), "set standard mode")
	var start_snap: Dictionary = state.get_player_snapshot(PLAYER_ID)
	_assert_true(int(start_snap.get("available_slots", -1)) == 1, "standard starts with exactly 1 free slot")

	_assert_ok(state.intent_unlock_additional_slot(PLAYER_ID), "unlock slot 2")
	_assert_ok(state.intent_unlock_additional_slot(PLAYER_ID), "unlock slot 3")
	_assert_ok(state.intent_unlock_additional_slot(PLAYER_ID), "unlock slot 4")
	var slots_snap: Dictionary = state.get_player_snapshot(PLAYER_ID)
	_assert_true(int(slots_snap.get("available_slots", -1)) == 4, "standard supports 4 total slots")

	_assert_ok(state.intent_equip_buff(PLAYER_ID, 0, BUFF_CLASSIC), "equip classic")
	_assert_ok(state.intent_equip_buff(PLAYER_ID, 1, BUFF_PREMIUM), "equip premium")
	_assert_ok(state.intent_equip_buff(PLAYER_ID, 2, BUFF_ELITE), "equip elite")
	var two_elites: Dictionary = state.intent_equip_buff(PLAYER_ID, 3, BUFF_ELITE_2)
	_assert_code(two_elites, "too_many_elite", "reject second elite in standard")
	_assert_ok(state.intent_equip_buff(PLAYER_ID, 3, BUFF_CLASSIC), "equip classic overtime slot")

	var pre_ot_activate: Dictionary = state.intent_activate_buff(PLAYER_ID, 3)
	_assert_code(pre_ot_activate, "classic_locked_pre_overtime", "classic slot locked before overtime")
	_assert_ok(state.intent_set_overtime(true), "set overtime")
	_assert_ok(state.intent_activate_buff(PLAYER_ID, 3), "activate classic in overtime")
	var overflow_activate: Dictionary = state.intent_activate_buff(PLAYER_ID, 4)
	_assert_code(overflow_activate, "slot_locked", "cannot activate beyond slots")

	# B) Steroids league allows unlimited buffs and no tier caps.
	_assert_ok(state.intent_set_mode("STEROIDS_LEAGUE"), "set steroids mode")
	for i in range(6):
		var buff_id: String = BUFF_ELITE if i % 2 == 0 else BUFF_ELITE_2
		_assert_ok(state.intent_equip_buff(PLAYER_ID, i, buff_id), "equip steroids slot %d" % i)
	for i in range(6):
		_assert_ok(state.intent_activate_buff(PLAYER_ID, i), "activate steroids slot %d" % i)
	_assert_ok(state.intent_set_mode("STANDARD"), "switch back to standard")
	var leak_check: Dictionary = state.intent_equip_buff(PLAYER_ID, 1, BUFF_ELITE)
	_assert_code(leak_check, "too_many_elite", "steroids rules do not leak into standard")

	# C) eSports modes.
	_assert_ok(state.intent_set_mode("ESPORTS_NO_BUFFS"), "set esports no buffs")
	var esports_none_snap: Dictionary = state.get_player_snapshot(PLAYER_ID)
	_assert_true(not bool(esports_none_snap.get("loadout_ui_enabled", true)), "esports no buffs hides loadout UI")
	var esports_none_activate: Dictionary = state.intent_activate_buff(PLAYER_ID, 0)
	_assert_code(esports_none_activate, "buffs_disabled", "esports no buffs blocks activation")

	_assert_ok(state.intent_set_mode("ESPORTS_STANDARDIZED"), "set esports standardized")
	var esports_std_snap: Dictionary = state.get_player_snapshot(PLAYER_ID)
	_assert_true(bool(esports_std_snap.get("esports_standardized_buff_enabled", false)), "standardized buff enabled")
	var esports_equip_attempt: Dictionary = state.intent_equip_buff(PLAYER_ID, 0, BUFF_CLASSIC)
	_assert_code(esports_equip_attempt, "standardized_no_loadout", "cannot change standardized esports buff")

	# D) Nectar award + spend flow.
	_assert_ok(state.intent_set_mode("STANDARD"), "back to standard for nectar checks")
	var before_wallet: Dictionary = state.get_player_snapshot(PLAYER_ID).get("wallet", {}) as Dictionary
	var free_award: Dictionary = state.intent_record_match_completion(PLAYER_ID, false)
	var paid_award: Dictionary = state.intent_record_match_completion(PLAYER_ID, true)
	_assert_true(int(paid_award.get("awarded", 0)) > int(free_award.get("awarded", 0)), "paid match awards more nectar")
	var purchase_award: Dictionary = state.intent_record_store_purchase(PLAYER_ID, 10.0)
	_assert_true(int(purchase_award.get("awarded", 0)) == 60, "purchase kickback is deterministic")
	_assert_ok(state.intent_pay_tournament_entry(PLAYER_ID), "spend nectar on tournament entry")
	_assert_ok(state.intent_purchase_buff_access(PLAYER_ID, BUFF_PREMIUM, 20), "spend nectar on buff access")
	var after_wallet: Dictionary = state.get_player_snapshot(PLAYER_ID).get("wallet", {}) as Dictionary
	_assert_true(int(after_wallet.get("nectar", 0)) != int(before_wallet.get("nectar", 0)), "nectar balance changes through awards/spends")

	print("ECONOMY_BUFF_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [label, str(result)])

func _assert_code(result: Dictionary, code: String, label: String) -> void:
	if bool(result.get("ok", false)):
		_fail("%s expected code %s but got ok" % [label, code])
		return
	if str(result.get("code", "")) != code:
		_fail("%s expected code %s but got %s" % [label, code, str(result.get("code", ""))])

func _assert_true(condition: bool, label: String) -> void:
	if condition:
		return
	_fail(label)

func _fail(message: String) -> void:
	push_error("ECONOMY_BUFF_SMOKE: %s" % message)
	quit(1)
