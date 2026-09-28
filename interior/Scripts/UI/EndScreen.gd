extends CanvasLayer

@onready var time_label = $Control/VBoxContainer/TimeLabel
@onready var restart_button = $Control/VBoxContainer/RestartButton

func _ready():
	restart_button.pressed.connect(_on_restart_pressed)

func show_results(time_taken: float):
	# Show the UI and set the text
	visible = true
	time_label.text = "Total rescue time: %02d:%02d\nOutside: %.1f s  |  Inside: %.1f s\nVictim delivered safely" % [int(time_taken)/60, int(time_taken)%60, GameManager.outdoor_time, time_taken - GameManager.outdoor_time]

func _on_restart_pressed():
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
