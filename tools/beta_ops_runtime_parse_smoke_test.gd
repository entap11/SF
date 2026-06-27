extends SceneTree

const SCRIPT_PATHS: Array[String] = [
	"res://scripts/state/ops_config.gd",
	"res://scripts/state/analytics_client.gd",
	"res://scripts/arena.gd",
	"res://scripts/ui/vs_lobby.gd",
	"res://scripts/ui/vs_mode_select.gd",
	"res://scripts/state/ad_manager.gd",
	"res://scripts/state/vs_handshake_state.gd",
	"res://scripts/state/rank_state.gd",
	"res://scripts/ops/ops_console.gd",
	"res://scripts/ui/support_diagnostics_panel.gd"
]

const SCENE_PATHS: Array[String] = [
	"res://scenes/ops/ops_console.tscn",
	"res://scenes/ui/SupportDiagnosticsPanel.tscn"
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in SCRIPT_PATHS:
		var script: Resource = load(path)
		if not (script is Script):
			return _fail("script failed to parse: %s" % path)
	for path in SCENE_PATHS:
		var scene: Resource = load(path)
		if not (scene is PackedScene):
			return _fail("scene failed to load: %s" % path)
	print("BETA_OPS_RUNTIME_PARSE_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("BETA_OPS_RUNTIME_PARSE_SMOKE: %s" % message)
	quit(1)
