extends Label

const SFLog := preload("res://scripts/util/sf_log.gd")

func _ready() -> void:
	SFLog.info("PREMATCH_VIEW_READY", {"path": str(get_path())})

func _process(_dt: float) -> void:
	var phase: int = int(OpsState.match_phase)
	var ms: int = int(OpsState.prematch_remaining_ms)
	if phase != int(OpsState.MatchPhase.PREMATCH) or ms <= 0:
		visible = false
		text = ""
		return
	visible = true
	text = str(int(ceil(ms / 1000.0)))
