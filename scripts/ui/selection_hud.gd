class_name SelectionHud
extends Control

@onready var title: Label = $Panel/VBox/Title
@onready var line1: Label = $Panel/VBox/Line1
@onready var line2: Label = $Panel/VBox/Line2
@onready var line3: Label = $Panel/VBox/Line3

func _ready() -> void:
	visible = false

func clear() -> void:
	visible = false
	if title:
		title.text = ""
	if line1:
		line1.text = ""
	if line2:
		line2.text = ""
	if line3:
		line3.text = ""

func show_hive(hive: HiveData, outgoing_count: int) -> void:
	visible = true
	title.text = "Hive %d" % hive.id
	line1.text = "Owner: %d" % hive.owner_id
	line2.text = "Power: %d" % hive.power
	var shock_sec: float = hive.shock_ms / 1000.0
	line3.text = "Shock: %.1fs | Out: %d" % [shock_sec, outgoing_count]

func show_lane(lane: LaneData, mode: String, impact_f: float) -> void:
	visible = true
	title.text = "Lane %d" % lane.id
	line1.text = "A:%d B:%d  Mode:%s" % [lane.a_id, lane.b_id, mode]
	var a_state: String = "ON" if lane.send_a else "OFF"
	var b_state: String = "ON" if lane.send_b else "OFF"
	line2.text = "A->B: %s  B->A: %s" % [a_state, b_state]
	if impact_f >= 0.0:
		line3.text = "Impact: %.2f" % impact_f
	else:
		line3.text = ""
