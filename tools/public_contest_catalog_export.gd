extends SceneTree

const PublicContestContentScript := preload("res://scripts/state/public_contest_content.gd")

func _init() -> void:
	print(JSON.stringify(PublicContestContentScript.build_catalog()))
	quit(0)
