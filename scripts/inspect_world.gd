extends SceneTree
func _initialize() -> void:
	call_deferred("inspect")
func inspect() -> void:
	for level in ["city", "forest"]:
		var scene = load("res://scenes/" + level + ".tscn").instantiate()
		root.add_child(scene)
		print("SCENE ", level)
		walk(scene)
		scene.free()
	quit()
func walk(n: Node) -> void:
	var label := str(n.name).to_lower()
	if n is Node3D and ("truck" in label or "pylon" in label or "ground" in label or "straight" in label or "curve" in label or "plaza" in label or "pump" in label or "distribut" in label):
		print(n.get_path(), " pos=", n.global_position, " scale=", n.global_basis.get_scale())
		if n is MeshInstance3D:
			print(" WORLD AABB ", n.global_transform * n.get_aabb())
	if n is CollisionShape3D:
		print(" COLLIDER ", n.get_path(), " type=", n.shape.get_class(), " scale=", n.global_basis.get_scale(), " enabled=", not n.disabled)
	for c in n.get_children(): walk(c)
