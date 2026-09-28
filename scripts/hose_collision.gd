extends RefCounted
## Shared path for the visible hose and its solid capsules.

static func route(a: Vector3, b: Vector3, truck: StaticBody3D, radius: float) -> Array[Vector3]:
	var shape: BoxShape3D = truck.get_child(0).shape
	var half := shape.size * 0.5
	var start := truck.to_local(a)
	var finish := truck.to_local(b)
	var clearance := radius + 0.12
	var bounds := AABB(-half - Vector3(clearance, 0, clearance), shape.size + Vector3(clearance * 2, 0, clearance * 2))
	var original_start := start
	var original_finish := finish
	start = outlet_exit(start, bounds)
	finish = outlet_exit(finish, bounds)
	var prefix: Array[Vector3] = []
	var suffix: Array[Vector3] = []
	if not start.is_equal_approx(original_start): prefix.append(a)
	if not finish.is_equal_approx(original_finish): suffix.append(b)
	if bounds.intersects_segment(start, finish) == null:
		prefix.append(truck.to_global(start))
		prefix.append(truck.to_global(finish))
		prefix.append_array(suffix)
		return prefix
	var x := half.x + clearance + 0.04
	var z := half.z + clearance + 0.04
	var y := clampf(minf(start.y, finish.y), -half.y + radius, half.y)
	var vertices: Array[Vector3] = [start, finish, Vector3(-x,y,-z), Vector3(x,y,-z), Vector3(x,y,z), Vector3(-x,y,z)]
	var distances := [0.0, INF, INF, INF, INF, INF]
	var previous := [-1, -1, -1, -1, -1, -1]
	var visited: Array[int] = []
	for _step in range(vertices.size()):
		var current := -1
		for i in range(vertices.size()):
			if i not in visited and (current == -1 or distances[i] < distances[current]): current = i
		if current == 1 or distances[current] == INF: break
		visited.append(current)
		for j in range(vertices.size()):
			if j == current or j in visited: continue
			if bounds.intersects_segment(vertices[current], vertices[j]) != null: continue
			var length: float = distances[current] + vertices[current].distance_to(vertices[j])
			if length < distances[j]:
				distances[j] = length
				previous[j] = current
	if previous[1] == -1: return [a, b]
	var path: Array[Vector3] = []
	var index := 1
	while index != -1:
		path.push_front(truck.to_global(vertices[index]))
		index = previous[index]
	return prefix + path + suffix

static func outlet_exit(point: Vector3, bounds: AABB) -> Vector3:
	# A recessed coupling exits through its nearest side before routing.
	# Never bypass routing just because a connection is inside the truck hull.
	if not bounds.has_point(point): return point
	var exits: Array[Vector3] = [
		Vector3(bounds.position.x - 0.04, point.y, point.z),
		Vector3(bounds.end.x + 0.04, point.y, point.z),
		Vector3(point.x, point.y, bounds.position.z - 0.04),
		Vector3(point.x, point.y, bounds.end.z + 0.04)]
	var nearest := exits[0]
	for candidate in exits:
		if point.distance_squared_to(candidate) < point.distance_squared_to(nearest): nearest = candidate
	return nearest

static func move_held(item: Node3D, destination: Vector3) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, item.global_position)
	query.motion = destination - item.global_position
	query.collision_mask = 1
	query.margin = 0.015
	var result := item.get_world_3d().direct_space_state.cast_motion(query)
	item.global_position += query.motion * result[0]

static func update_body(body: StaticBody3D, points: Array[Vector3], radius: float) -> void:
	while body.get_child_count() < points.size() - 1:
		var collider := CollisionShape3D.new()
		collider.shape = CapsuleShape3D.new()
		body.add_child(collider)
	for i in range(body.get_child_count()):
		var collider: CollisionShape3D = body.get_child(i)
		collider.disabled = i >= points.size() - 1
		if collider.disabled: continue
		var delta := points[i + 1] - points[i]
		if delta.length() < 0.001:
			collider.disabled = true
			continue
		collider.shape.radius = radius
		collider.shape.height = delta.length() + radius * 2
		collider.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, delta.normalized())), (points[i] + points[i + 1]) * 0.5)
