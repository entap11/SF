extends SceneTree

const SCAN_FILES: Array[String] = [
	"res://scripts/arena.gd",
	"res://scripts/ops/ops_state.gd"
]
const SCAN_DIRS: Array[String] = [
	"res://scripts/sim",
	"res://scripts/systems"
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var offenders: Array[String] = []
	for path in SCAN_FILES:
		_scan_file(path, offenders)
	for dir_path in SCAN_DIRS:
		_scan_dir(dir_path, offenders)
	if not offenders.is_empty():
		return _fail("runtime deterministic code must not access OpsConfig: %s" % ", ".join(offenders))
	print("OPS_CONFIG_NO_RUNTIME_SIM_ACCESS_SMOKE: PASS")
	quit(0)

func _scan_dir(path: String, offenders: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.ends_with(".gd"):
			_scan_file("%s/%s" % [path, file_name], offenders)
	for child in dir.get_directories():
		_scan_dir("%s/%s" % [path, child], offenders)

func _scan_file(path: String, offenders: Array[String]) -> void:
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	if text.contains("OpsConfig") or text.contains("/root/OpsConfig"):
		offenders.append(path)

func _fail(message: String) -> void:
	push_error("OPS_CONFIG_NO_RUNTIME_SIM_ACCESS_SMOKE: %s" % message)
	quit(1)
