extends CharacterBody3D
var camera: Camera3D
var mouse_sensitivity := 0.0025
var spawn := Vector3.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	collider.shape = capsule
	collider.position.y = 0.85
	add_child(collider)
	camera = Camera3D.new()
	camera.name = "DesktopCamera"
	camera.position.y = 1.6
	camera.fov = 75.0
	camera.near = 0.04
	camera.far = 1000.0
	add_child(camera)
	camera.current = true
	spawn = position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -1.5, 1.5)

func _physics_process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		velocity = Vector3.ZERO
		return
	var v := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var direction := transform.basis * Vector3(v.x, 0, v.y)
	var speed := 6.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor(): velocity.y -= 18.0 * delta
	elif Input.is_physical_key_pressed(KEY_SPACE): velocity.y = 5.0
	move_and_slide()
	if position.y < -50.0: position = spawn
