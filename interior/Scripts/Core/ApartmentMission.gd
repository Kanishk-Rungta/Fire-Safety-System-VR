extends Node3D
var panel: Node3D
func _ready() -> void:
	if not GameManager.is_game_active:
		GameManager.start_game()
	GameManager.phase = "interior"
	$Interactables/FrontDoor.interact()
	if GameManager.control_mode == "vr":
		panel = preload("res://scripts/vr_panel.gd").new()
		add_child(panel)
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
		$Player/OxygenHUD.reparent(panel.viewport)
		$Player/MissionHUD.reparent(panel.viewport)
		panel.viewport.get_node("OxygenHUD/Control/ControlsLabel").text = "Left stick: Move | Grip: Pick / Place / Open | Trigger: Spray | A: Torch | Stick click: Crouch | B: Pause"
		GameManager.result_viewport = panel.viewport
		$Player.vr_rig.action_pressed.connect(func(action: String):
			if action in ["menu", "secondary"]: GameManager.toggle_indoor_pause()
			if action == "trigger" and get_tree().paused: panel.click(true))
		$Player.vr_rig.action_released.connect(func(action: String):
			if action == "trigger": panel.click(false))
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child in get_children():
		if child != panel: child.process_mode = Node.PROCESS_MODE_PAUSABLE
func _process(_delta: float) -> void:
	if is_instance_valid(panel):
		panel.follow($Player.camera)
		panel.interactive = get_tree().paused
		panel.update_pointer($Player.vr_rig.right.global_transform, $Player.vr_rig.has_pointer())
