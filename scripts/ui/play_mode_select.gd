extends Control

signal closed

@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var time_puzzle_button: Button = $Panel/VBox/Buttons/TimePuzzle
@onready var vs_button: Button = $Panel/VBox/Buttons/VS

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	time_puzzle_button.pressed.connect(_on_time_puzzle_pressed)
	vs_button.pressed.connect(_on_vs_pressed)

func _on_time_puzzle_pressed() -> void:
	var lobby := preload("res://scenes/ui/TimePuzzleLobby.tscn").instantiate()
	lobby.closed.connect(func():
		lobby.queue_free()
		visible = true
	)
	add_child(lobby)
	lobby.set_scope("WEEKLY")
	lobby.visible = true
	visible = false

func _on_vs_pressed() -> void:
	var panel := preload("res://scenes/ui/VsModeSelect.tscn").instantiate()
	panel.closed.connect(func():
		panel.queue_free()
		visible = true
	)
	add_child(panel)
	visible = false

func _on_back_pressed() -> void:
	closed.emit()
