extends RefCounted
## Bakes editable native geometry for the west approach to the incident.
const ROAD_CLOSED = preload("res://scripts/road_closure.gd")

static func material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.55
	return m

static func box(parent: Node3D, title: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = title
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

static func solid(parent: Node3D, title: String, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = title
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = pos
	parent.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body

static func cylinder(parent: Node3D, title: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = title
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

static func label(parent: Node3D, title: String, text: String, pos: Vector3, size := 42) -> Label3D:
	var n := Label3D.new()
	n.name = title
	n.text = text
	n.position = pos
	n.font_size = size
	n.pixel_size = 0.008
	n.modulate = Color(0.12, 0.14, 0.17)
	n.outline_size = 0
	parent.add_child(n)
	return n

static func build(scene: Node3D, nodes: Dictionary) -> void:
	var street := Node3D.new()
	street.name = "RoadClosureApproach"
	street.set_script(ROAD_CLOSED)
	scene.add_child(street)
	var source: MeshInstance3D = scene.get_node("Batch_U21_straight")
	var basis := Basis(Vector3.UP, PI / 2.0)
	var center := source.get_aabb().get_center()
	for i in range(2):
		var tile := MeshInstance3D.new()
		tile.name = "ApproachRoad_" + str(i + 1)
		tile.mesh = source.mesh
		var position := Vector3(-20 - i * 20, 0, 0)
		tile.transform = Transform3D(basis, position - basis * center)
		street.add_child(tile)
		solid(street, "RoadSurface_" + str(i + 1), position - Vector3(0, 0.25, 0), Vector3(20, 0.5, 20))
	var kerb := material(Color(0.72, 0.73, 0.7))
	var paving := material(Color(0.48, 0.5, 0.49))
	for side in [-1, 1]:
		var z: float = 6.9 * side
		box(street, "Sidewalk_" + str(side), Vector3(-30, 0.06, z), Vector3(40, 0.12, 2.3), paving)
		solid(street, "SidewalkCollision_" + str(side), Vector3(-30, 0.02, z), Vector3(40, 0.08, 2.3))
		box(street, "Kerb_" + str(side), Vector3(-30, 0.1, side * 5.8), Vector3(40, 0.2, 0.16), kerb)
	box(street, "StopLine", Vector3(-12.2, 0.015, 0), Vector3(0.3, 0.02, 9.5), material(Color(0.97, 0.97, 0.9)))
	car(street, "WaitingCarBlue", Vector3(-16.3, 0.0, 2.6), Color(0.07, 0.23, 0.42))
	car(street, "WaitingCarSilver", Vector3(-23, 0.0, 2.6), Color(0.52, 0.57, 0.6))
	car(street, "WaitingCarRed", Vector3(-30.2, 0.0, 2.6), Color(0.55, 0.075, 0.045))
	person(street, "TrafficMarshal", Vector3(-11.7, 0.12, 6.8), Color(0.85, 0.92, 0.08), true)
	person(street, "WaitingPedestrian1", Vector3(-18, 0.12, -6.7), Color(0.15, 0.35, 0.42))
	person(street, "WaitingPedestrian2", Vector3(-19.1, 0.12, -7.1), Color(0.6, 0.22, 0.12))
	var sign := Node3D.new()
	sign.name = "ClosureSign"
	sign.position = Vector3(-11.0, 0, -5.4)
	sign.rotation.y = -PI / 2.0
	street.add_child(sign)
	box(sign, "Post", Vector3(0, 1.0, 0), Vector3(0.08, 2, 0.08), material(Color(0.3, 0.32, 0.35), 0.65))
	box(sign, "Board", Vector3(0, 1.95, 0), Vector3(2.3, 1.1, 0.08), material(Color(1, 0.68, 0.06)))
	label(sign, "Message", "FIRE RESPONSE\nSTOP HERE", Vector3(0, 1.95, 0.045), 38)
	solid(sign, "SignCollision", Vector3(0, 1.25, 0), Vector3(0.15, 2.5, 0.15))
	for id in ["25", "3"]:
		var marker := MeshInstance3D.new()
		marker.name = "ConeBay_" + id
		var ring := TorusMesh.new()
		ring.inner_radius = 0.43
		ring.outer_radius = 0.5
		ring.rings = 24
		ring.ring_segments = 6
		marker.mesh = ring
		marker.material_override = material(Color(1.0, 0.65, 0.08))
		marker.position = Vector3(nodes[id].global_position.x, 0.025, nodes[id].global_position.z)
		marker.scale.y = 0.15
		street.add_child(marker)

static func car(parent: Node3D, title: String, position: Vector3, color: Color) -> void:
	var n := Node3D.new()
	n.name = title
	n.position = position
	# Models face +X towards the closure, all behind the stop line.
	parent.add_child(n)
	var paint := material(color, 0.35)
	var rubber := material(Color(0.025, 0.03, 0.035))
	var glass := material(Color(0.065, 0.14, 0.19), 0.4)
	box(n, "Chassis", Vector3(0, 0.5, 0), Vector3(4.4, 0.6, 1.85), paint)
	box(n, "Hood", Vector3(1.45, 0.85, 0), Vector3(1.3, 0.15, 1.78), paint)
	box(n, "Cabin", Vector3(-0.25, 1.05, 0), Vector3(2.15, 0.7, 1.58), glass)
	box(n, "Roof", Vector3(-0.25, 1.425, 0), Vector3(2.18, 0.09, 1.65), paint)
	for side in [-1, 1]:
		box(n, "DoorPillar_" + str(side), Vector3(-0.2, 1.07, side * 0.802), Vector3(0.1, 0.68, 0.07), paint)
		for axle in [-1.35, 1.35]:
			var wheel := cylinder(n, "Wheel", Vector3(axle, 0.38, side * 0.91), 0.38, 0.2, rubber)
			wheel.rotation.x = PI / 2
			var hub := cylinder(n, "WheelHub", Vector3(axle, 0.38, side * 1.018), 0.18, 0.02, material(Color(0.55,0.58,0.6),0.8))
			hub.rotation.x = PI / 2
		box(n, "Headlight", Vector3(2.22, 0.68, side * 0.64), Vector3(0.025, 0.16, 0.36), material(Color(0.95, 0.95, 0.78)))
		box(n, "TailLight", Vector3(-2.22, 0.65, side * 0.65), Vector3(0.025, 0.17, 0.3), material(Color(0.8, 0.04, 0.025)))
		var hazard := material(Color(1, 0.36, 0.015))
		hazard.emission_enabled = true
		hazard.emission = Color(1, 0.24, 0)
		var lamp := box(n, "Hazard_" + str(side), Vector3(2.225, 0.67, side * 0.84), Vector3(0.025, 0.13, 0.12), hazard)
		lamp.add_to_group("traffic_hazards", true)
	box(n, "FrontBumper", Vector3(2.22, 0.4, 0), Vector3(0.12, 0.16, 1.7), rubber)
	solid(n, "CarCollision", Vector3(0, 0.75, 0), Vector3(4.55, 1.5, 2.08))

static func person(parent: Node3D, title: String, position: Vector3, shirt: Color, marshal := false) -> void:
	var n := Node3D.new()
	n.name = title
	n.position = position
	parent.add_child(n)
	var fabric := material(shirt)
	var dark := material(Color(0.055, 0.075, 0.11))
	var skin := material(Color(0.52, 0.32, 0.21))
	for side in [-1, 1]:
		box(n, "Leg", Vector3(side * 0.12, 0.45, 0), Vector3(0.16, 0.72, 0.2), dark)
		box(n, "Boot", Vector3(side * 0.12, 0.07, 0.04), Vector3(0.19, 0.14, 0.31), dark)
		box(n, "Sleeve", Vector3(side * 0.29, 1.18, 0), Vector3(0.15, 0.38, 0.19), fabric)
		box(n, "Forearm", Vector3(side * 0.29, 0.94, 0), Vector3(0.12, 0.22, 0.14), skin)
	box(n, "Torso", Vector3(0, 1.15, 0), Vector3(0.44, 0.62, 0.27), fabric)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.145
	sphere.height = 0.32
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	head.material_override = skin
	head.position.y = 1.64
	n.add_child(head)
	if marshal:
		box(n, "ReflectiveBand", Vector3(0, 1.09, 0), Vector3(0.46, 0.1, 0.29), material(Color(0.92, 0.94, 0.9)))
		cylinder(n, "Helmet", Vector3(0, 1.78, 0), 0.17, 0.11, material(Color(0.95, 0.9, 0.2)))
	solid(n, "PersonCollision", Vector3(0, 0.87, 0), Vector3(0.7, 1.74, 0.45))
