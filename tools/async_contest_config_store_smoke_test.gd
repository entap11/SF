extends SceneTree

const AsyncContestConfigStoreScript := preload("res://scripts/state/async_contest_config_store.gd")
const MatchSetupRandomizer := preload("res://scripts/state/match_setup_randomizer.gd")

const SMOKE_SAVE_PATH: String = "user://async_contest_config_store_smoke.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	var store: RefCounted = AsyncContestConfigStoreScript.new()
	store.save_path = SMOKE_SAVE_PATH
	var maps: Array[Dictionary] = store.available_async_maps()
	if maps.is_empty():
		_fail("expected at least one non-3P async map")
		return
	for entry in maps:
		var token: String = ("%s|%s" % [str(entry.get("path", "")), str(entry.get("map_id", ""))]).to_lower()
		if token.contains("__3p"):
			_fail("3P map leaked into async map pool: %s" % token)
			return
	var config: Dictionary = store.config_for("WEEKLY", 3)
	config["randomizer_pct"] = 100
	config["bot_style"] = "balancer"
	config["bot_tier"] = "medium"
	config["prize_type"] = "Bundle"
	config["amount"] = "7"
	config = store.update_config("WEEKLY", 3, config)
	var options: Dictionary = store.launch_options("WEEKLY", 3)
	if str(options.get("vs_cpu_style", "")) != "balancer":
		_fail("bot style not merged")
		return
	if str(options.get("vs_cpu_tier", "")) != "medium":
		_fail("bot tier not merged")
		return
	if not options.has("stage_map_paths"):
		_fail("stage map paths missing")
		return
	var payload: Dictionary = options.get(MatchSetupRandomizer.CONTEXT_KEY, {}) as Dictionary
	if payload.is_empty() or not bool(payload.get("hit", false)):
		_fail("100 percent randomizer did not hit")
		return
	var categories: Dictionary = payload.get("categories", {}) as Dictionary
	if categories.size() != MatchSetupRandomizer.CATEGORY_ORDER.size():
		_fail("100 percent randomizer should select every category")
		return
	var structures: Dictionary = payload.get("structures", {}) as Dictionary
	if str(structures.get("kind", "")) != "mixed":
		_fail("randomizer structure kind should be mixed")
		return
	config["randomizer_pct"] = 0
	store.update_config("WEEKLY", 3, config)
	options = store.launch_options("WEEKLY", 3)
	if options.has(MatchSetupRandomizer.CONTEXT_KEY):
		_fail("0 percent randomizer should not emit payload")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	print("ASYNC_CONTEST_CONFIG_STORE_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("ASYNC_CONTEST_CONFIG_STORE_SMOKE: %s" % message)
	quit(1)
