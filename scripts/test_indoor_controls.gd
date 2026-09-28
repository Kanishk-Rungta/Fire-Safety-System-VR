extends SceneTree
var failures := 0
var assertions := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)
func run() -> void:
	var gm = root.get_node("GameManager")
	gm.control_mode = "vr"
	var right := XRControllerTracker.new()
	right.name = "right_hand"
	right.type = XRServer.TRACKER_CONTROLLER
	XRServer.add_tracker(right)
	var apartment = load("res://interior/Scenes/Levels/Apartment.tscn").instantiate()
	root.add_child(apartment)
	current_scene = apartment
	await process_frame
	var player = apartment.get_node("Player")
	player.set_physics_process(false)
	check(player.camera is XRCamera3D, "Interior keeps tracked headset camera")
	check(player.raycast.get_parent() == player.vr_rig.right, "Interaction ray follows controller")
	check(apartment.panel.viewport.has_node("MissionHUD"), "Mission instructions render in headset")
	check(apartment.panel.viewport.has_node("OxygenHUD"), "Survival HUD renders in headset")
	right.set_input("connect", true)
	check(player.torch_on, "A toggles indoor flashlight")
	right.set_input("connect", false)
	right.set_input("disconnect", true)
	check(player.is_crouch_toggled, "Stick click enables indoor crouch")
	right.set_input("disconnect", false)
	right.set_input("secondary", true)
	check(paused and is_instance_valid(gm.pause_ui), "B opens indoor pause panel")
	var previous: float = gm.elapsed
	await create_timer(0.1, true).timeout
	check(is_equal_approx(previous, gm.elapsed), "VR pause stops mission clock")
	right.set_input("secondary", false)
	right.set_input("secondary", true)
	check(not paused, "B resumes indoor mission")
	gm.game_over("TEST FAILURE")
	check(paused and not gm.is_game_active, "Failure freezes mission")
	var failure_ui: Node
	for child in apartment.panel.viewport.get_children():
		if child.has_method("show_game_over"): failure_ui = child
	check(failure_ui != null, "Failure results render inside headset viewport")
	failure_ui._on_retry_pressed()
	await process_frame
	await process_frame
	check(not paused and current_scene.name != "Apartment", "Failure retry returns to combined mission menu")
	XRServer.remove_tracker(right)
	print("INDOOR CONTROL TESTS: ", assertions, " assertions, ", failures, " failures (synthetic XR)")
	quit(0 if failures == 0 else 1)
