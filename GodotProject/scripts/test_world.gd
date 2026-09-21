extends SceneTree
var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
		push_error(description)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for level in ["city", "forest"]:
		game.select_control_mode("keyboard")
		game.start_level(level)
		game.player.set_physics_process(false)
		await physics_frame
		var truck: StaticBody3D = game.world.get_node("FiretruckSolid")
		check(truck.global_basis.get_scale().is_equal_approx(Vector3.ONE), level + " truck collider has unit scale")
		var shape: BoxShape3D = truck.get_child(0).shape
		check(shape.size.x < 4.0 and shape.size.z > 8.0, level + " truck hull follows the vehicle orientation")
		for script in ["player", "vr_player"]:
			var walker: CharacterBody3D = load("res://scripts/" + script + ".gd").new()
			root.add_child(walker)
			walker.set_physics_process(false)
			await physics_frame
			for side in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				var half: float = shape.size.x / 2 if side.x else shape.size.z / 2
				var local_start: Vector3 = side * (half + 1.0) + Vector3(0, -shape.size.y / 2 + 0.08, 0)
				walker.global_position = truck.global_transform * local_start
				var motion: Vector3 = truck.global_basis * -side * (half * 2 + 2)
				var hit := walker.move_and_collide(motion)
				check(hit != null and hit.get_collider() == truck, level + " " + script + " blocked by truck from " + str(side))
			walker.free()
		# A player can still stand outside the rear and use the pump.
		var pump_id := "213" if level == "city" else "231"
		var pump: Node3D = game.nodes[pump_id]
		var rear := truck.global_transform * Vector3(0, -shape.size.y / 2 + 1.0, shape.size.z / 2 + 0.6)
		check(rear.distance_to(pump.global_position) < 4.5, level + " pump remains within interaction reach")
		if level == "city":
			check(get_nodes_in_group("solid_buildings").size() >= 4, "Building meshes have physical walls")
			var street: Node3D = game.world.get_node("RoadClosureApproach")
			var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
			for x in [-49.0, -30.05, -29.95, -10.05, -9.95]:
				var point := Vector3(x, 2, -2.6)
				var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 5, 1))
				check(not floor_hit.is_empty() and absf(floor_hit.position.y) < 0.05, "Extended road has continuous floor at " + str(x))
			for name in ["WaitingCarBlue", "WaitingCarSilver", "WaitingCarRed"]:
				var car: Node3D = street.get_node(name)
				check(car.position.x + 2.3 < -12.2, name + " stays behind stop line")
				var from := car.global_position + Vector3(0, 0.9, 3)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 0, 6), 1))
				check(not hit.is_empty() and hit.collider.name == "CarCollision", name + " is solid")
			check(street.get_node("ClosureSign/Message").text.contains("STOP"), "Traffic sign initially requests a stop")
			for bay in ["25", "3"]:
				for target in game.targets:
					if target.go == "179" and target.kind == "grab": game.aimed = target; break
				game.pick_up()
				var cone: Node3D = game.grabbed
				game.place_item(game.nodes[bay].global_position)
				check(absf(cone.global_position.y) < 0.04, "Placed cone rests on the road")
				await physics_frame
				var from: Vector3 = cone.global_position + Vector3(0, 0.2, 1)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 0, 2), 1))
				check(not hit.is_empty() and cone.is_ancestor_of(hit.collider), "Placed cone collision is enabled")
			check(game.progress == 4 and street.placed_bays.size() == 2, "Both physical cones advance the tutorial")
			check(street.get_node("ClosureSign/Message").text.contains("ROAD CLOSED"), "Both cones activate road-closed sign")
		game.show_menu()
		await process_frame
	game.free()
	await create_timer(0.15).timeout
	print("WORLD TESTS: ", assertions, " assertions, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
