extends SceneTree
## Synthetic tracking tests validate routing; these are not a hardware headset test.
var failures: Array[String] = []
var assertions := 0
var clicked := false
var received: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
		push_error(description)

func buttons(control: Control) -> Array[String]:
	var result: Array[String] = []
	for node in control.get_children():
		if node is Button: result.append(node.text)
	return result

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(buttons(game.menu) == ["Keyboard & Mouse", "Meta VR Headset", "Quit"], "First page chooses controls, not maps")
	check(game.control_mode.is_empty(), "No controller selected implicitly")
	check(game.tutorial.size() == 2 and game.tutorial.has("city") and game.tutorial.has("forest"), "Only English map tutorials packaged")
	game.start_level("city")
	check(game.level.is_empty(), "Cannot enter a map before choosing controls")
	game.select_control_mode("keyboard")
	check(game.control_mode == "keyboard" and game.menu_page == "maps", "Keyboard selection opens maps")
	check(buttons(game.menu) == ["City Level", "Forest Level", "Back to Controls", "Quit"], "Map page includes back and exit")
	game.start_level("city")
	game.player.set_physics_process(false)
	check(game.player.get_script() == load("res://scripts/player.gd"), "Keyboard mode creates desktop controller")
	check(not root.use_xr, "Keyboard mode does not render XR")
	game.on_vr_action("secondary")
	check(not game.paused, "VR input ignored in keyboard mode")
	game.toggle_pause()
	check(game.paused, "Desktop pause works")
	game.toggle_pause()
	check(not game.paused, "Desktop resume works")
	game.show_menu()
	await process_frame
	check(game.control_mode.is_empty() and game.menu_page == "controls", "Returning to controls clears prior mode")
	# Exercise actual initialization failure without pretending a headset exists.
	game.select_control_mode("vr")
	if game.control_mode == "vr":
		check(root.use_xr and game.menu_page == "maps", "Available OpenXR runtime enters maps")
	else:
		check(game.menu_page == "controls" and not game.menu_status.text.is_empty(), "Missing runtime keeps controls menu with useful error")
	game.show_menu()
	await process_frame
	var map: OpenXRActionMap = load("res://openxr_action_map.tres")
	check(map.action_sets.size() == 1, "OpenXR action set loads")
	var names: Array[String] = []
	for action in map.action_sets[0].actions: names.append(action.resource_name)
	for required in ["aim", "grip", "trigger", "grab", "primary", "connect", "secondary", "disconnect", "menu"]:
		check(required in names, "XR action exists: " + required)
	check(map.interaction_profiles[0].interaction_profile_path == "/interaction_profiles/oculus/touch_controller", "Meta Touch interaction profile")
	check(map.interaction_profiles[0].bindings.size() == 17, "Touch paths supplied for both hands")
	var right := XRControllerTracker.new()
	right.name = "right_hand"
	right.type = XRServer.TRACKER_CONTROLLER
	XRServer.add_tracker(right)
	var left := XRControllerTracker.new()
	left.name = "left_hand"
	left.type = XRServer.TRACKER_CONTROLLER
	XRServer.add_tracker(left)
	var rig = load("res://scripts/vr_player.gd").new()
	root.add_child(rig)
	rig.set_physics_process(false)
	var pose := Transform3D(Basis.IDENTITY, Vector3(0.4, 1.3, -0.4))
	right.set_pose("aim", pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	right.set_pose("grip", pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	left.set_pose("aim", Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	check(rig.has_pointer(), "Synthetic tracked right controller is recognized")
	check(rig.right.position.is_equal_approx(pose.origin), "Controller aim follows tracking pose")
	check(rig.camera is XRCamera3D, "VR rig uses tracked camera")
	rig.action_pressed.connect(func(action: String): received.append(action))
	right.set_input("trigger", true)
	check(rig.trigger_down() and "trigger" in received, "Trigger state and action signal use tracker input")
	right.set_input("trigger", false)
	check(not rig.trigger_down(), "Trigger release stops spray input")
	var old_rotation: Vector3 = rig.rotation
	# There is no mouse-input handler in the VR rig.
	check(not rig.has_method("_unhandled_input"), "VR rig has no keyboard/mouse controller")
	right.invalidate_pose("aim")
	check(not rig.has_pointer(), "Lost tracking disables aiming")
	right.set_pose("aim", pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	rig.movement_enabled = true
	right.set_input("primary", Vector2(1, 0))
	rig._physics_process(0.0)
	check(not rig.rotation.is_equal_approx(old_rotation), "Right stick snap-turns rig")
	var turned: Vector3 = rig.rotation
	rig._physics_process(0.0)
	check(rig.rotation.is_equal_approx(turned), "Snap turn waits for stick recenter")
	# Exercise the shared game through real tracker signals with a synthetic VR rig.
	game.select_control_mode("keyboard")
	game.start_level("city")
	game.player.free()
	game.player = rig
	rig.reparent(game)
	rig.transform = Transform3D.IDENTITY
	game.control_mode = "vr"
	game.wire_vr_player()
	game.setup_spray()
	var nozzle: Node3D = game.component_node(game.nozzle_id)
	pose.origin = nozzle.global_position + Vector3(0, 0, 1)
	right.set_pose("aim", pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	right.set_pose("grip", pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	game.targets.clear()
	game.targets.append({"node":nozzle,"go":"194","kind":"grab","title":"JetPipe"})
	await process_frame
	check(game.aim_transform().origin.is_equal_approx(pose.origin), "Game aims from controller instead of headset")
	right.set_input("grab", true)
	await process_frame
	check(game.grabbed == nozzle, "Controller grip reaches real gameplay pickup")
	right.set_input("grab", false)
	game.progress = 25
	right.set_input("trigger", true)
	await process_frame
	check(game.progress == 26, "Controller nozzle activation advances original tutorial")
	right.set_input("trigger", false)
	var keyboard_event := InputEventKey.new()
	keyboard_event.physical_keycode = KEY_ESCAPE
	keyboard_event.pressed = true
	game._unhandled_input(keyboard_event)
	check(not game.paused, "Keyboard gameplay keys ignored in VR mode")
	right.set_input("secondary", true)
	await process_frame
	check(game.paused and not rig.movement_enabled, "Controller B pauses game and locomotion")
	right.set_input("secondary", false)
	right.set_input("secondary", true)
	await process_frame
	check(not game.paused and rig.movement_enabled, "Controller B resumes gameplay")
	game.show_menu()
	await process_frame
	check(game.control_mode.is_empty() and game.vr_panel == null, "Switching out of VR clears rig mode")
	XRServer.remove_tracker(right)
	XRServer.remove_tracker(left)
	var panel = load("res://scripts/vr_panel.gd").new()
	root.add_child(panel)
	panel.position.z = -2.0
	check(panel.project_ray(Transform3D.IDENTITY).is_equal_approx(Vector2(640, 360)), "Controller ray maps to UI center")
	check(panel.project_ray(Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)).x < 0, "UI ignores rays pointing away")
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.viewport.add_child(control)
	var button := Button.new()
	button.position = Vector2(540, 320)
	button.size = Vector2(200, 80)
	button.pressed.connect(func(): clicked = true)
	control.add_child(button)
	await process_frame
	panel.update_pointer(Transform3D.IDENTITY, true)
	panel.click(true)
	panel.click(false)
	check(clicked, "Controller trigger clicks a real viewport button")
	panel.free()
	game.free()
	await process_frame
	await create_timer(0.15).timeout
	print("CONTROL TESTS: ", assertions, " assertions, ", failures.size(), " failures (synthetic XR tracking)")
	quit(0 if failures.is_empty() else 1)
