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
		var pipe_start := truck.to_global(Vector3(-shape.size.x / 2 - 1, 0, 0))
		var pipe_finish := truck.to_global(Vector3(shape.size.x / 2 + 1, 0, 0))
		var pipe := Node3D.new()
		root.add_child(pipe)
		pipe.global_position = pipe_start
		game.HoseCollision.move_held(pipe, pipe_finish)
		check(truck.to_local(pipe.global_position).x < -shape.size.x / 2, level + " held pipe cannot tunnel through truck")
		pipe.free()
		var route: Array[Vector3] = game.HoseCollision.route(pipe_start, pipe_finish, truck, 0.06)
		check(route.size() > 2, level + " hose routes around truck")
		var truck_bounds := AABB(-shape.size / 2, shape.size)
		# Actual pump couplings can sit inside the truck's simplified box hull.
		# Connect a hose and drag its free end to each side of the vehicle.
		for id in game.components:
			var component: Dictionary = game.components[id]
			if component.get("script", "") != "PumpController": continue
			var ports: Array = component.data.outputConnections.duplicate()
			ports.append(component.data.inputConnection)
			for port in ports:
				var port_id: String = game.rid(port)
				var outlet: Vector3 = game.component_node(port_id).global_position
				for hose in game.hoses:
					var hose_port := ""
					for candidate in game.network.ports:
						if game.component_node(candidate) == hose.a and int(game.network.ports[candidate].connectionSize) == int(game.network.ports[port_id].connectionSize):
							hose_port = candidate
							break
					if hose_port.is_empty(): continue
					var original_a: Vector3 = hose.a.global_position
					var original_b: Vector3 = hose.b.global_position
					check(game.network.connect_ports(hose_port, port_id), level + " attach hose to actual truck coupling")
					hose.a.global_position = outlet
					for side in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
						hose.b.global_position = truck.to_global(side * 10.0)
						game.draw_hose(hose)
						var attached_route: Array[Vector3] = game.HoseCollision.route(outlet, hose.b.global_position, truck, hose.radius)
						check(attached_route[0].is_equal_approx(outlet), level + " hose stays attached at coupling")
						for segment in range(attached_route.size() - 1):
							if segment == 0 and truck_bounds.has_point(truck.to_local(outlet)): continue
							check(truck_bounds.intersects_segment(truck.to_local(attached_route[segment]), truck.to_local(attached_route[segment + 1])) == null, level + " connected hose clears truck toward " + str(side))
					game.network.disconnect_port(hose_port)
					hose.a.global_position = original_a
					hose.b.global_position = original_b
					game.draw_hose(hose)
					break
		for i in range(route.size() - 1):
			check(truck_bounds.intersects_segment(truck.to_local(route[i]), truck.to_local(route[i + 1])) == null, level + " routed segment clears truck")
		var test_hose := StaticBody3D.new()
		test_hose.collision_layer = 4
		root.add_child(test_hose)
		var pipe_points: Array[Vector3] = [Vector3(-2, 100.7, 0), Vector3(2, 100.7, 0)]
		game.HoseCollision.update_body(test_hose, pipe_points, 0.06)
		await physics_frame
		for script in ["player", "vr_player"]:
			var walker: CharacterBody3D = load("res://scripts/" + script + ".gd").new()
			root.add_child(walker)
			walker.set_physics_process(false)
			await physics_frame
			walker.global_position = Vector3(0, 100, 2)
			var pipe_hit := walker.move_and_collide(Vector3(0, 0, -4))
			check(pipe_hit != null and pipe_hit.get_collider() == test_hose, level + " " + script + " cannot walk through hose")
			for side in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				var half: float = shape.size.x / 2 if side.x else shape.size.z / 2
				var local_start: Vector3 = side * (half + 1.0) + Vector3(0, -shape.size.y / 2 + 0.08, 0)
				walker.global_position = truck.global_transform * local_start
				var motion: Vector3 = truck.global_basis * -side * (half * 2 + 2)
				var hit := walker.move_and_collide(motion)
				check(hit != null and hit.get_collider() == truck, level + " " + script + " blocked by truck from " + str(side))
			walker.free()
		test_hose.free()
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
