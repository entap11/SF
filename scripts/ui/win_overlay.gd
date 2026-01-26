class_name WinOverlay
extends Control

@onready var title_label: Label = $Panel/Title
@onready var subtitle_label: Label = $Panel/Sub

func show_win(winner_id: int, reason: String) -> void:
	if winner_id == 0:
		title_label.text = "DRAW"
	else:
		title_label.text = "PLAYER %d WINS" % winner_id
	subtitle_label.text = "Reason: %s" % reason
	visible = true

func hide_overlay() -> void:
	visible = false
