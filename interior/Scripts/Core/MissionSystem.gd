extends Node

enum Step { OPEN_WINDOWS, PICKUP_EXTINGUISHER, EXTINGUISH_FIRE, FIND_VICTIM, CARRY_VICTIM, REACH_SAFE_ZONE, COMPLETE }
const STEP_TITLE = {
 Step.OPEN_WINDOWS: "Ventilate the kitchen and living room",
 Step.PICKUP_EXTINGUISHER: "Pick up the extinguisher",
 Step.EXTINGUISH_FIRE: "Extinguish all indoor fires",
 Step.FIND_VICTIM: "Find the victim in the bedroom",
 Step.CARRY_VICTIM: "Pick up the victim",
 Step.REACH_SAFE_ZONE: "Carry the victim to the green rescue zone",
 Step.COMPLETE: "Victim rescued"
}
const STEP_HINT = {
 Step.OPEN_WINDOWS: "E / Left-click: open both marked windows. C / Ctrl: crouch below smoke.",
 Step.PICKUP_EXTINGUISHER: "Follow the beacon. E / Left-click: pick up. F: flashlight.",
 Step.EXTINGUISH_FIRE: "Hold Right-click to spray at the base of each fire. Include burning furniture.",
 Step.FIND_VICTIM: "E / Left-click: put down the extinguisher. Follow the victim beacon.",
 Step.CARRY_VICTIM: "Aim at the victim and press E / Left-click to carry them.",
 Step.REACH_SAFE_ZONE: "Return to the green zone by the front door with the victim.",
 Step.COMPLETE: "The mission timer has stopped."
}
var current_step: Step = Step.OPEN_WINDOWS
var target_node: Node3D
signal step_changed(step: Step, title: String, hint: String)
func advance(to_step: Step) -> void:
	if to_step != current_step + 1: return
	current_step = to_step
	step_changed.emit(current_step, get_title(), get_hint())
func get_title() -> String: return STEP_TITLE[current_step]
func get_hint() -> String:
	var hint: String = STEP_HINT[current_step]
	if GameManager.control_mode == "vr":
		hint = hint.replace("E / Left-click", "Grip").replace("Right-click", "Trigger").replace("C / Ctrl", "Stick click").replace("F:", "A:")
	return hint
func set_target(node: Node3D) -> void: target_node = node
func reset() -> void:
	current_step = Step.OPEN_WINDOWS
	target_node = null
	step_changed.emit(current_step, get_title(), get_hint())
func _process(_delta: float) -> void:
	if GameManager.phase != "interior" or not GameManager.is_game_active: return
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	match current_step:
		Step.OPEN_WINDOWS:
			var remaining := 0
			for window in get_tree().get_nodes_in_group("windows"):
				if not window.smoke_zone_path.is_empty() and not window.is_open: remaining += 1
			if remaining == 0: advance(Step.PICKUP_EXTINGUISHER)
		Step.PICKUP_EXTINGUISHER:
			if is_instance_valid(player.held_object) and player.held_object.is_in_group("extinguisher"): advance(Step.EXTINGUISH_FIRE)
		Step.EXTINGUISH_FIRE:
			for fire in get_tree().get_nodes_in_group("fire"):
				if not fire.is_extinguished: return
			advance(Step.FIND_VICTIM)
		Step.FIND_VICTIM:
			var victim = get_tree().get_first_node_in_group("victim")
			if victim and player.global_position.distance_to(victim.global_position) < 3.0: advance(Step.CARRY_VICTIM)
		Step.CARRY_VICTIM:
			if is_instance_valid(player.held_object) and player.held_object.is_in_group("victim"): advance(Step.REACH_SAFE_ZONE)
