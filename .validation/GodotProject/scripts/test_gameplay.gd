extends SceneTree
var failures: Array[String] = []
var assertions := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
		push_error(description)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for level in ["city", "forest"]:
		game.start_level(level)
		game.set_process(false)
		game.player.set_physics_process(false)
		await physics_frame
		check(game.nodes.size() > 200, level + " recovered hierarchy")
		check(game.network.ports.size() >= 20, level + " connection metadata")
		var from: Vector3 = game.player.position + Vector3.UP * 4.0
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 15.0, 1))
		check(not hit.is_empty(), level + " spawn has terrain collision")
		if level == "city": city()
		else: forest()
		check(game.progress == (26 if level == "city" else 22), level + " tutorial reaches fire suppression")
		check(game.network.nozzle_pressure(game.nozzle_id) > 0.5, level + " nozzle supplied")
		var patch = game.fires.values()[0]
		patch.ignite()
		patch.tick(2.0)
		check(patch.hp > 199.0, "Fire grows using recovered rule")
		patch.extinguish(100000.0)
		check(patch.put_out and not patch.burning, "Water extinguishes a fire")
		for fire in game.fires.values(): fire.extinguish(100000.0)
		game._process(0.016)
		check(game.completed, level + " completion")
		check(game.progress == game.tutorial[game.language + "_" + level].size() - 1, level + " final tutorial text")
		game.show_menu()
		await process_frame
	print("GAMEPLAY TESTS: ", assertions, " assertions, ", failures.size(), " failures")
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)

func pick(go: String) -> void:
	game.aimed = {}
	for target in game.targets:
		if target.go == go and target.kind == "grab": game.aimed = target; break
	check(not game.aimed.is_empty(), "Grabbable " + go + " exists")
	game.pick_up()

func join(a: String, b: String) -> void:
	game.selected_port = a
	for target in game.targets:
		if target.get("port", "") == b: game.aimed = target; break
	game.join_connection()
	check(game.network.links.get(a, "") == b, "Connected " + a + " to " + b)

func valve(go: String) -> void:
	for target in game.targets:
		if target.go == go and target.kind == "valve": game.aimed = target; break
	game.use_target()

func city() -> void:
	pick("179")
	game.place_item(game.nodes["25"].global_position)
	pick("179")
	game.place_item(game.nodes["3"].global_position)
	check(game.progress == 4, "City pylons placed")
	pick("225")
	join("1086", "954")
	pick("214")
	join("1145", "1117")
	pick("226")
	join("1118", "1144")
	pick("141")
	for target in game.targets:
		if target.kind == "hydrant": game.aimed = target; break
	game.use_target()
	game.place_item(game.nodes["141"].global_position)
	pick("35")
	game.place_item(game.nodes["22"].global_position)
	pick("223")
	join("1087", "1127")
	pick("227")
	join("1119", "965")
	valve("130")
	pick("203")
	join("1124", "964")
	join("967", "968")
	pick("202")
	join("1123", "1134")
	check(is_zero_approx(game.network.nozzle_pressure(game.nozzle_id)), "Closed distributor blocks flow")
	valve("191")
	pick("194")
	game.invoke_tutorial_event("194", "m_Activated")
	check(is_equal_approx(game.network.nozzle_pressure(game.nozzle_id), 7.5), "City pressure = (3 - .2) * 3 - .2 - .35 - .35")
	valve("45")
	check(is_equal_approx(game.network.nozzle_pressure(game.nozzle_id), 3.3), "Pump splits pressure between open outlets")
	valve("45")
	game.network.disconnect_port("1086")
	check(is_zero_approx(game.network.nozzle_pressure(game.nozzle_id)), "Disconnect source clears downstream pressure")
	check(not game.network.connect_ports("1086", "1134"), "Mismatched hose sizes rejected")
	check(game.network.connect_ports("1086", "954"), "Reconnect restores source")
	check(not game.network.connect_ports("1086", "954"), "Occupied connections rejected")

func forest() -> void:
	join("1120", "1122")
	join("1085", "1083")
	pick("247")
	join("1084", "1145")
	pick("224")
	game.place_item(game.nodes["202"].global_position)
	pick("239")
	join("1121", "1114")
	pick("32")
	game.place_item(game.nodes["201"].global_position)
	pick("237")
	join("1086", "1132")
	pick("238")
	join("1118", "980")
	valve("116")
	pick("226")
	join("1126", "979")
	join("982", "983")
	pick("225")
	join("1125", "1139")
	valve("213")
	pick("216")
	game.invoke_tutorial_event("216", "m_Activated")
	check(is_equal_approx(game.network.nozzle_pressure(game.nozzle_id), 8.1), "Forest pressure = 3 * 3 - .2 - .35 - .35")
