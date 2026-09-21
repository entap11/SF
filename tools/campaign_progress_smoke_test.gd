extends SceneTree

const Catalog = preload("res://scripts/state/campaign_catalog.gd")
const Store = preload("res://scripts/state/campaign_progress_store.gd")
const MapLoader = preload("res://scripts/maps/map_loader.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("CAMPAIGN: " + message)

func _run() -> void:
	var all: Array[Dictionary] = Catalog.levels()
	check(all.size() == 25, "pilot has 25 authored challenges")
	if all.size() != 25:
		quit(1)
		return
	var store = Store.new()
	store.save_path = "user://campaign_progress.smoke.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
	var styles: Dictionary = {}
	for level in all:
		check(bool(MapLoader.load_map(str(level.map_path)).get("ok", false)), "map loads: " + str(level.id))
		check(Catalog.resolve(str(level.map_path), str(level.bot), str(level.difficulty)) == level, "selector resolves exact definition")
		styles[level.bot] = true
	check(styles.size() == 5, "all five personalities represented")
	check(store.is_unlocked("a", str(all[0].id)), "first level open")
	check(not store.is_unlocked("a", str(all[1].id)), "second initially locked")
	check(not store.bookmark("a", str(all[1].id)), "locked launch cannot move bookmark")
	var loss: Dictionary = store.record_attempt("a", "Player A", all[0], "loss-1", false, 85000, "campaign")
	check(bool(loss.ok), "loss persists")
	check(store.is_unlocked("a", str(all[1].id)), "loss unlocks next")
	check(int(loss.best_ms) == 0 and int(loss.stingers) == 0 and store.board(all[0]).is_empty(), "loss earns no PB, award or board entry")
	check(store.continue_id("a") == str(all[1].id), "continue advances after loss")
	store.record_attempt("a", "Player A", all[0], "loss-1", false, 85000, "campaign")
	check(int(store.snapshot("a", all[0]).attempts) == 1, "duplicate terminal event does not increment attempts")
	check(not store.is_unlocked("b", str(all[1].id)), "unlock is scoped to player")
	var win: Dictionary = store.record_attempt("a", "Player A", all[0], "win-1", true, 80000, "jukebox")
	check(int(win.stingers) == 3 and int(win.best_ms) == 80000, "Jukebox win earns same challenge rewards")
	store.record_attempt("a", "Player A", all[0], "win-2", true, 200000, "campaign")
	check(int(store.snapshot("a", all[0]).best_ms) == 80000, "slower replay preserves PB")
	check(int(store.snapshot("a", all[0]).stingers) == 3, "slower replay preserves mastery")
	check(store.board(all[0]).size() == 1, "one PB row per player")
	var changed: Dictionary = all[0].duplicate(true)
	changed.record_key = str(changed.record_key) + "-new-policy"
	check(store.board(changed).is_empty(), "new rules revision cannot inherit old record")
	var reopened = Store.new()
	reopened.save_path = store.save_path
	check(int(reopened.snapshot("a", all[0]).best_ms) == 80000, "save survives reopen")
	check(reopened.is_unlocked("a", str(all[1].id)), "unlock survives reopen")
	check(Catalog.stingers(all[0], true, int(all[0].two_stinger_ms)) == 2, "inclusive two-stinger target")
	check(Catalog.stingers(all[0], true, int(all[0].three_stinger_ms)) == 3, "inclusive three-stinger target")
	check(Catalog.stingers(all[0], false, 1) == 0, "fast loss is not an award")
	var broken = Store.new()
	broken.save_path = "user://campaign_corrupt.smoke.json"
	var file := FileAccess.open(broken.save_path, FileAccess.WRITE)
	file.store_string("broken historical data")
	file.close()
	check(not broken.bookmark("a", str(all[0].id)), "corrupt store fails closed")
	check(FileAccess.get_file_as_string(broken.save_path) == "broken historical data", "corrupt evidence preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(broken.save_path))
	print("CAMPAIGN_PROGRESS_SMOKE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)
