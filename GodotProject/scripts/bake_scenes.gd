extends SceneTree
const StreetBuilder = preload("res://scripts/city_street_builder.gd")
## Converts the recovered GLB hierarchies into editable Godot scenes.
func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	for level in ["city", "forest"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + level + ".json"))
		var scene: Node3D = load("res://assets/" + level + ".glb").instantiate()
		root.add_child(scene)
		scene.name = level.capitalize()
		var nodes := {}
		index_nodes(scene, nodes)
		for id in data.objects:
			if not nodes.has(id): continue
			var n: Node3D = nodes[id]
			n.visible = data.objects[id].active
			var original: String = data.objects[id].name
			if original in ["XR", "XR Rig", "Tutorial", "TutorialTexts", "Tutorial Texts", "Canvas", "MenuButton"]:
				n.visible = false
		for id in data.components:
			var c: Dictionary = data.components[id]
			var d: Dictionary = c.data
			var go := str(int(d.get("m_GameObject", {}).get("m_PathID", 0)))
			if not nodes.has(go): continue
			var n: Node3D = nodes[go]
			if c.type == "MeshRenderer" and not d.m_Enabled: n.visible = false
			# Tutorial zones guide placement; they must not act as invisible solid blocks.
			if str(data.objects[go].name).begins_with("FieldFor"): continue
			if c.type in ["BoxCollider", "SphereCollider"] and d.m_Enabled and not d.m_IsTrigger:
				var body := StaticBody3D.new()
				body.name = "Collision_" + id
				var shape := CollisionShape3D.new()
				if c.type == "BoxCollider":
					var box := BoxShape3D.new()
					box.size = Vector3(d.m_Size.x, d.m_Size.y, d.m_Size.z).abs().max(Vector3.ONE * 0.001)
					shape.shape = box
				else:
					var sphere := SphereShape3D.new()
					sphere.radius = maxf(0.001, d.m_Radius)
					shape.shape = sphere
				shape.position = Vector3(d.m_Center.x, d.m_Center.y, -d.m_Center.z)
				n.add_child(body)
				body.add_child(shape)
			if c.type == "MeshCollider" and d.m_Enabled and not d.m_IsTrigger:
				var source := n.get_node_or_null("CollisionSource_U" + go)
				if source is MeshInstance3D:
					source.create_trimesh_collision()
					source.hide()
				elif n is MeshInstance3D: n.create_trimesh_collision()
		add_missing_solids(scene, data, nodes)
		if level == "city": StreetBuilder.build(scene, nodes)
		set_owners(scene, scene)
		var packed := PackedScene.new()
		packed.pack(scene)
		ResourceSaver.save(packed, "res://scenes/" + level + ".tscn")
		print("BAKED ", level, " objects=", nodes.size())
		for id in nodes:
			if data.objects.has(id) and data.objects[id].name in ["XR Rig", "Main Camera", "Ground", "ForestLand", "JetPipe", "Pump"]:
				print(data.objects[id].name, " ", nodes[id].global_position)
		scene.free()
	quit()

func add_missing_solids(scene: Node3D, data: Dictionary, nodes: Dictionary) -> void:
	for go in data.objects:
		var original: String = data.objects[go].name
		var node: Node3D = nodes.get(go)
		if node == null: continue
		var batch: MeshInstance3D = scene.get_node_or_null("Batch_" + str(node.name))
		if original == "Firetruck_bearb" and batch:
			# Compute a filled, oriented hull from actual vertices, not the enlarged
			# axis-aligned bounds of the rotated forest truck. Keep physics at unit scale.
			var center: Vector3 = (batch.global_transform * batch.get_aabb()).get_center()
			var pump: Node3D = node.find_child("*Pump", true, false)
			var rear: Vector3 = pump.global_position - center
			rear.y = 0.0
			var frame := Transform3D(Basis.looking_at(-rear.normalized(), Vector3.UP), Vector3(center.x, node.global_position.y, center.z))
			var to_local := frame.affine_inverse() * batch.global_transform
			var bounds := AABB()
			var first := true
			for surface in range(batch.mesh.get_surface_count()):
				var vertices: PackedVector3Array = batch.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var point := to_local * vertex
					if first:
						bounds = AABB(point, Vector3.ZERO)
						first = false
					else: bounds = bounds.expand(point)
			# Close the undercarriage gap so a walking capsule cannot enter underneath.
			var top := bounds.end.y
			bounds.position.y = minf(bounds.position.y, -0.35)
			bounds.size.y = top - bounds.position.y
			var body := StreetBuilder.solid(scene, "FiretruckSolid", Vector3.ZERO, bounds.size)
			body.global_transform = frame * Transform3D(Basis.IDENTITY, bounds.get_center())
			body.add_to_group("solid_vehicles", true)
		elif batch and "house" in original.to_lower():
			batch.create_trimesh_collision()
			var body := batch.get_child(batch.get_child_count() - 1)
			body.name = "BuildingSolid"
			body.add_to_group("solid_buildings", true)

func index_nodes(n: Node, output: Dictionary) -> void:
	if str(n.name).begins_with("U"):
		var id := str(n.name).get_slice("_", 0).substr(1)
		if id.is_valid_int(): output[id] = n
	for child in n.get_children(): index_nodes(child, output)

func set_owners(n: Node, scene: Node) -> void:
	for child in n.get_children():
		child.owner = scene
		set_owners(child, scene)
