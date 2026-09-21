extends CharacterBody3D
## PC OpenXR rig. Head and controller poses come only from the active XR runtime.
signal action_pressed(action: String)
signal action_released(action: String)
var camera: XRCamera3D
var origin: XROrigin3D
var left: XRController3D
var right: XRController3D
var grip: XRController3D
var movement_enabled := false
var spawn := Vector3.ZERO
var turn_latched := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	origin = XROrigin3D.new()
	add_child(origin)
	camera = XRCamera3D.new()
	camera.near = 0.04
	camera.far = 1000.0
	origin.add_child(camera)
	camera.current = true
	left = controller("left_hand", "aim")
	right = controller("right_hand", "aim")
	grip = controller("right_hand", "grip")
	right.button_pressed.connect(func(action: String): action_pressed.emit(action))
	right.button_released.connect(func(action: String): action_released.emit(action))
	left.button_pressed.connect(func(action: String):
		if action == "menu": action_pressed.emit("menu"))
	var pointer := MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.002
	beam.bottom_radius = 0.002
	beam.height = 3.0
	pointer.mesh = beam
	pointer.rotation.x = PI / 2.0
	pointer.position.z = -1.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.8, 1.0)
	pointer.material_override = material
	right.add_child(pointer)
	spawn = position

func controller(tracker_name: String, pose_name: String) -> XRController3D:
	var node := XRController3D.new()
	node.tracker = StringName(tracker_name)
	node.pose = StringName(pose_name)
	node.show_when_tracked = true
	origin.add_child(node)
	return node

func has_pointer() -> bool:
	return right.get_has_tracking_data()

func trigger_down() -> bool:
	return has_pointer() and right.is_button_pressed("trigger")

func _physics_process(delta: float) -> void:
	if not movement_enabled or not has_pointer():
		velocity = Vector3.ZERO
		return
	# Keep body collision underneath the tracked head, including room-scale movement.
	var shape: CollisionShape3D = $BodyCollision
	var head := to_local(camera.global_position)
	shape.position = Vector3(head.x, 0.85, head.z)
	var stick := left.get_vector2("primary")
	if stick.length() < 0.2: stick = Vector2.ZERO
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var sideways := forward.cross(Vector3.UP)
	var motion := (sideways * stick.x + forward * stick.y).limit_length() * 2.5
	velocity.x = motion.x
	velocity.z = motion.z
	if not is_on_floor(): velocity.y -= 18.0 * delta
	else: velocity.y = 0.0
	move_and_slide()
	var turn := right.get_vector2("primary").x
	if absf(turn) < 0.3: turn_latched = false
	if absf(turn) > 0.7 and not turn_latched:
		var before := camera.global_position
		rotate_y(-signf(turn) * PI / 6.0)
		global_position += before - camera.global_position
		turn_latched = true
	if position.y < -50.0: position = spawn
