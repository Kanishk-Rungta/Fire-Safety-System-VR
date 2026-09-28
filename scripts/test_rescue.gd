extends SceneTree
var failures: Array[String] = []
var assertions := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures.append(description)
		push_error(description)
func frames(count := 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func run() -> void:
	var gm = root.get_node("GameManager")
	var ms = root.get_node("MissionSystem")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.select_control_mode("keyboard")
	game.start_level("city")
	await frames()
	game.player.set_physics_process(false)
	game.player.global_position = game.entrance.global_position + Vector3(0, 0, 1)
	check(not game.player.test_move(game.player.global_transform, Vector3(0, 0, -1)), "Street-facing entry marker is physically reachable")
	check(not game.can_enter_house(), "Entrance is locked while outside fire burns")
	for fire in game.fires.values(): fire.extinguish(100000.0)
	game._process(0.016)
	await frames()
	check(game.completed and gm.is_game_active, "Outside completion does not finish the rescue")
	check(game.can_enter_house(), "Entrance unlocks after suppression")
	gm.elapsed = 73.0
	game.enter_house()
	await create_timer(0.8).timeout
	await frames(5)
	var apartment = current_scene
	check(apartment.name == "Apartment", "Entrance loads the actual indoor project")
	if apartment.name != "Apartment":
		quit(1)
		return
	check(gm.elapsed >= 73.0 and gm.outdoor_time >= 73.0, "Timer survives the scene transition")
	var player = apartment.get_node("Player")
	player.set_physics_process(false)
	await create_timer(0.6).timeout
	var doorway_collision := KinematicCollision3D.new()
	var doorway_blocked: bool = player.test_move(player.global_transform, Vector3(0, 0, -2.5), doorway_collision)
	if doorway_blocked: print("DOORWAY BLOCKER: ", doorway_collision.get_collider(), " at ", doorway_collision.get_position())
	check(not doorway_blocked, "Open front doorway connects porch to interior")
	var victim = apartment.get_node("VictimNPC")
	check(victim.get_node("CivilianVisual/Head") != null, "Civilian model replaces capsule placeholder")
	var safe = apartment.get_node("SafeZone")
	safe._on_body_entered(victim)
	check(gm.is_game_active and not safe.rescued, "Premature rescue cannot complete the mission")
	player.global_position = Vector3(5, 0, 1.3)
	player.camera.look_at(Vector3(5, 1.4, 2.9))
	await frames()
	player.raycast.force_raycast_update()
	player._try_interact()
	await frames()
	check(apartment.get_node("Windows/WindowLiving").is_open, "Living window opens through actual raycast interaction")
	check(ms.current_step == ms.Step.OPEN_WINDOWS, "One window does not skip kitchen ventilation")
	player.global_position = Vector3(-5, 0, 1.3)
	player.camera.look_at(Vector3(-5, 1.4, 2.9))
	await frames()
	player.raycast.force_raycast_update()
	player._try_interact()
	await frames()
	check(ms.current_step == ms.Step.PICKUP_EXTINGUISHER, "Both windows unlock extinguisher step")
	var extinguisher = apartment.get_node("Props/FireExtinguisher")
	player.global_position = extinguisher.global_position + Vector3(0, 0, -1.5)
	player.camera.look_at(extinguisher.global_position)
	await frames()
	player.raycast.force_raycast_update()
	player._try_interact()
	await frames()
	check(player.held_object == extinguisher, "Raycast interaction picks up the extinguisher")
	check(ms.current_step == ms.Step.EXTINGUISH_FIRE, "Extinguisher pickup advances objective")
	for fire in get_nodes_in_group("fire"): fire.apply_extinguisher(10000.0)
	await frames(5)
	check(ms.current_step == ms.Step.FIND_VICTIM, "All indoor fires unlock victim search")
	player._try_interact()
	player.global_position = victim.global_position + Vector3(0, 0, -2.0)
	player.camera.look_at(victim.global_position + Vector3(0, 0.6, 0))
	await frames()
	check(ms.current_step == ms.Step.CARRY_VICTIM, "Approaching victim advances carry instructions")
	player.raycast.force_raycast_update()
	player._try_interact()
	await frames()
	check(player.held_object == victim, "Raycast interaction picks up the civilian")
	check(ms.current_step == ms.Step.REACH_SAFE_ZONE, "Carrying victim selects evacuation marker")
	gm.toggle_indoor_pause()
	var paused_time: float = gm.elapsed
	var paused_health: float = victim.current_health
	var paused_position: Vector3 = victim.global_position
	await create_timer(0.15, true).timeout
	check(is_equal_approx(gm.elapsed, paused_time), "Pause freezes mission timer")
	check(is_equal_approx(victim.current_health, paused_health) and victim.global_position.is_equal_approx(paused_position), "Pause freezes victim physics and survival")
	gm.toggle_indoor_pause()
	player.global_position = Vector3(1.5, 0, 4.3)
	player.camera.rotation = Vector3(0, PI, 0)
	await frames(90)
	check(safe.rescued and not gm.is_game_active, "Carried victim entering safe zone completes rescue")
	var finish_time: float = gm.elapsed
	await create_timer(0.1, true).timeout
	check(is_equal_approx(gm.elapsed, finish_time), "Timer stops permanently on successful rescue")
	var result_screen: Node
	for child in root.get_children():
		if child.has_method("show_results"): result_screen = child
	check(result_screen != null, "Successful rescue shows the combined results screen")
	result_screen._on_restart_pressed()
	await frames(5)
	check(current_scene.name != "Apartment" and ms.current_step == ms.Step.COMPLETE, "Results restart returns to mission selection")
	current_scene.select_control_mode("keyboard")
	current_scene.start_level("city")
	check(gm.elapsed < 1.0 and ms.current_step == ms.Step.OPEN_WINDOWS, "New mission clears timer and indoor objectives")
	paused = false
	print("RESCUE_TESTS: ", assertions, " assertions, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
