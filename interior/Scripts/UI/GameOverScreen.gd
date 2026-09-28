extends CanvasLayer

@onready var reason_label: Label = $Control/CardPanel/Margin/VBoxContainer/ReasonLabel
@onready var tip_label: Label = $Control/CardPanel/Margin/VBoxContainer/TipLabel
@onready var retry_button: Button = $Control/CardPanel/Margin/VBoxContainer/RetryButton


func _ready():
	retry_button.pressed.connect(_on_retry_pressed)

func show_game_over(reason: String = "SUFFOCATED BY TOXIC SMOKE"):
	visible = true
	if reason_label:
		reason_label.text = reason
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_retry_pressed():
	# Unpause before reloading so the new scene starts running
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.timer_running = false
		gm.is_game_active = false
	get_viewport().use_xr = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	queue_free()
