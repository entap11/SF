extends Label

func _process(_dt: float) -> void:
	var phase: int = int(OpsState.match_phase)
	var ms: int = OpsState.prematch_remaining_ms
	if phase != int(OpsState.MatchPhase.PREMATCH) or ms <= 0:
		text = ""
		visible = false
	else:
		text = str(int(ceil(ms / 1000.0)))
		visible = true
