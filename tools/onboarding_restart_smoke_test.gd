extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe: Node = load("res://scripts/tests/onboarding_restart_probe.gd").new()
	root.add_child(probe)
