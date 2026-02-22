class_name SwarmPassPrestigeCapTracker
extends RefCounted

const SwarmPassConfigScript := preload("res://scripts/state/swarm_pass_config.gd")

var _model: int = SwarmPassConfigScript.PrestigeModel.SOFT_CAP
var _hard_caps: Dictionary = {}
var _soft_cutoffs: Dictionary = {}
var _unlock_counts_by_level: Dictionary = {}

func configure(model: int, hard_caps: Dictionary, soft_cutoffs: Dictionary) -> void:
	_model = model
	_hard_caps = hard_caps.duplicate(true)
	_soft_cutoffs = soft_cutoffs.duplicate(true)

func set_unlock_counts(raw: Dictionary) -> void:
	_unlock_counts_by_level.clear()
	for level_key_any in raw.keys():
		var level_key: String = str(level_key_any)
		var count: int = maxi(0, int(raw.get(level_key_any, 0)))
		_unlock_counts_by_level[level_key] = count

func unlock_counts() -> Dictionary:
	return _unlock_counts_by_level.duplicate(true)

func preview_unlock(level: int) -> Dictionary:
	var key: String = str(level)
	var current_count: int = int(_unlock_counts_by_level.get(key, 0))
	if _model == SwarmPassConfigScript.PrestigeModel.HARD_BRICK:
		var cap: int = int(_hard_caps.get(key, -1))
		var ok: bool = cap < 0 or current_count < cap
		return {
			"ok": ok,
			"model": "hard_brick",
			"cap": cap,
			"remaining": cap - current_count if cap >= 0 else -1,
			"variant": "prestige" if ok else "locked"
		}
	var cutoff: int = int(_soft_cutoffs.get(key, -1))
	var variant: String = "prestige"
	if cutoff >= 0 and current_count >= cutoff:
		variant = "standard"
	return {
		"ok": true,
		"model": "soft_cap",
		"cap": cutoff,
		"remaining": cutoff - current_count if cutoff >= 0 else -1,
		"variant": variant
	}

func commit_unlock(level: int) -> Dictionary:
	var preview: Dictionary = preview_unlock(level)
	if not bool(preview.get("ok", false)):
		return preview
	var key: String = str(level)
	var next_count: int = int(_unlock_counts_by_level.get(key, 0)) + 1
	_unlock_counts_by_level[key] = next_count
	preview["count_after"] = next_count
	return preview

func remaining_slots(level: int) -> int:
	var preview: Dictionary = preview_unlock(level)
	return int(preview.get("remaining", -1))

