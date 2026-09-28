extends Node

var result_viewport: SubViewport
var pause_ui: CanvasLayer
var elapsed := 0.0
var outdoor_time := 0.0
var timer_running := false
var phase := "outdoor"
var control_mode := "keyboard"

var start_time: int = 0
var end_time: int = 0
var is_game_active: bool = false
var end_screen_scene = preload("res://interior/Scenes/UI/EndScreen.tscn")
var game_over_scene = preload("res://interior/Scenes/UI/GameOverScreen.tscn")

func _ready():
	pass

func start_game():
	elapsed = 0.0
	outdoor_time = 0.0
	phase = "outdoor"
	timer_running = true
	MissionSystem.reset()
	start_time = Time.get_ticks_msec()
	is_game_active = true
	# Make sure the tree is running when a new game starts
	get_tree().paused = false

func _process(delta: float) -> void:
	if is_game_active and timer_running:
		elapsed += delta

func game_won():
	if not is_game_active or phase != "interior" or MissionSystem.current_step != MissionSystem.Step.COMPLETE:
		return

	end_time = Time.get_ticks_msec()
	is_game_active = false

	var time_taken = elapsed
	print("Game Won! Time taken: ", time_taken)

	# Instance the End Screen BEFORE pausing so it can set process_mode
	if end_screen_scene:
		var end_screen = end_screen_scene.instantiate()
		# UI must run even while paused
		end_screen.process_mode = Node.PROCESS_MODE_ALWAYS
		(result_viewport if is_instance_valid(result_viewport) else get_tree().root).add_child(end_screen)
		if end_screen.has_method("show_results"):
			end_screen.show_results(time_taken)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Pause the entire scene tree — fire/smoke/player all freeze
	get_tree().paused = true

func game_over(reason: String = "SUFFOCATED BY TOXIC SMOKE"):
	if not is_game_active:
		return

	is_game_active = false
	print("Game Over: ", reason)

	if game_over_scene:
		var go_screen = game_over_scene.instantiate()
		# UI must run even while paused
		go_screen.process_mode = Node.PROCESS_MODE_ALWAYS
		(result_viewport if is_instance_valid(result_viewport) else get_tree().root).add_child(go_screen)
		if go_screen.has_method("show_game_over"):
			go_screen.show_game_over(reason)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Pause the entire scene tree
	get_tree().paused = true

func toggle_indoor_pause() -> void:
	if not is_game_active or phase != "interior": return
	if is_instance_valid(pause_ui):
		pause_ui.queue_free()
		pause_ui = null
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	pause_ui = CanvasLayer.new()
	pause_ui.layer = 50
	pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	(result_viewport if is_instance_valid(result_viewport) else get_tree().root).add_child(pause_ui)
	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.05, 0.94)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(background)
	var title := Label.new()
	title.text = "RESCUE PAUSED - timer stopped"
	title.position = Vector2(440, 190)
	background.add_child(title)
	for i in range(2):
		var button := Button.new()
		button.text = "Resume rescue" if i == 0 else "Restart full mission"
		button.position = Vector2(460, 280 + i * 70)
		button.size = Vector2(360, 50)
		background.add_child(button)
		if i == 0: button.pressed.connect(toggle_indoor_pause)
		else: button.pressed.connect(func():
			get_tree().paused = false
			is_game_active = false
			timer_running = false
			get_viewport().use_xr = false
			pause_ui.queue_free()
			pause_ui = null
			get_tree().change_scene_to_file("res://scenes/main.tscn"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
