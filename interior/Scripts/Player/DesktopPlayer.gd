extends CharacterBody3D

## First-person controller with survival mechanics:
## - WASD to move (normal speed or low crawl speed when crouching)
## - Mouse look with captured cursor
## - Left-click to interact / pickup / drop
## - Right-click (hold) to spray fire extinguisher
## - Hold CTRL or press C to crouch / crawl below smoke
## - Dynamic oxygen depletion in ceiling smoke layers

# Movement parameters
@export var standing_speed: float = 5.0
@export var crouch_speed: float = 2.5
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 9.8

# Crouch dimensions & speeds
const STANDING_HEIGHT: float = 1.75
const CROUCHING_HEIGHT: float = 0.9
const STANDING_CAMERA_Y: float = 1.65
const CROUCHING_CAMERA_Y: float = 0.8
const CROUCH_LERP_SPEED: float = 10.0

var vr_rig: CharacterBody3D
var vr_mode := false
var vr_turn_latched := false
var is_crouching: bool = false
var is_crouch_toggled: bool = false
var camera_pitch: float = 0.0

# Oxygen & Survival parameters
@export var max_oxygen: float = 100.0
@export var oxygen_depletion_rate: float = 12.5 # ~8 seconds in smoke to empty
@export var oxygen_recovery_rate: float = 20.0   # ~5 seconds to full recovery
var current_oxygen: float = 100.0
var is_in_smoke: bool = false
var is_alive: bool = true
## Tracks whether the player was ever in smoke during this crouch session,
## so we only auto-release the toggle when THAT smoke has cleared.
var _was_in_smoke_while_crouched: bool = false

# Node references
@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: RayCast3D = get_node_or_null("CeilingCheck")
@onready var oxygen_hud: CanvasLayer = get_node_or_null("OxygenHUD")
@onready var torch: SpotLight3D = get_node_or_null("Camera3D/Torch")

var torch_on: bool = false
const TORCH_ENERGY: float = 3.5

# Held object carrying
var held_object: RigidBody3D = null
const HOLD_DISTANCE: float = 1.8
const CARRY_SPRING: float = 14.0   # velocity multiplier toward hold point
const CARRY_DAMP: float = 0.8      # damping factor applied to carried body each frame

# Saved physics properties for held object restore on drop
var _held_gravity_scale: float = 1.0
var _held_linear_damp: float = 0.0
var _held_angular_damp: float = 0.0

# Health / burn damage
@export var max_health: float = 100.0
@export var burn_damage_rate: float = 20.0
@export var health_regen_rate: float = 5.0
@export var burn_radius: float = 1.5
var current_health: float = 100.0
var is_on_fire: bool = false

# Crosshair aim-at-fire indicator
var is_aiming_at_fire: bool = false

# C-key just-pressed tracker (more reliable than _unhandled_input)
var _prev_c_key: bool = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	vr_mode = GameManager.control_mode == "vr"
	if vr_mode:
		vr_rig = preload("res://scripts/vr_player.gd").new()
		add_child(vr_rig)
		vr_rig.set_physics_process(false)
		vr_rig.get_node("BodyCollision").disabled = true
		var old_camera := camera
		camera = vr_rig.camera
		raycast.reparent(vr_rig.right, false)
		torch.reparent(camera, false)
		old_camera.current = false
		camera.current = true
		vr_rig.action_pressed.connect(func(action: String):
			if action == "grab" and not get_tree().paused: _try_interact()
			if action == "connect": _toggle_torch()
			if action == "disconnect": is_crouch_toggled = not is_crouch_toggled)
	current_oxygen = max_oxygen
	add_to_group("player")
	
	# Duplicate collision shape so changes don't affect other instances
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()


func _unhandled_input(event):
	if not is_alive:
		return
		
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		GameManager.toggle_indoor_pause()
		return

	# Mouse look
	if not vr_mode and event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clamp(camera_pitch - event.relative.y * mouse_sensitivity, -1.4, 1.4)
		camera.rotation.x = camera_pitch
	
	# Toggle torch with F  |  C-key toggle is in _physics_process for reliability
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_toggle_torch()
	
	# Left-click: interact or pickup/drop
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and ((event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
		_try_interact()

func _physics_process(delta):
	if not is_alive:
		return
		
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# C-key crouch toggle — checked here (not _unhandled_input) so it's never swallowed
	var c_now = Input.is_key_pressed(KEY_C)
	if c_now and not _prev_c_key:
		is_crouch_toggled = !is_crouch_toggled
	_prev_c_key = c_now

	# Evaluate crouching state
	var wants_crouch = Input.is_key_pressed(KEY_CTRL) or is_crouch_toggled
	if not wants_crouch and is_crouching:
		# Check ceiling clearance before standing up
		if ceiling_check and ceiling_check.is_colliding():
			is_crouching = true
		else:
			is_crouching = false
	else:
		is_crouching = wants_crouch
	
	# Smooth camera height transition
	var target_cam_y = CROUCHING_CAMERA_Y if is_crouching else STANDING_CAMERA_Y
	if not vr_mode:
		camera.position.y = lerp(camera.position.y, target_cam_y, CROUCH_LERP_SPEED * delta)
	else:
		vr_rig.origin.position.y = -0.7 if wants_crouch else 0.0
		is_crouching = camera.global_position.y - global_position.y < 1.15
		var turn: float = vr_rig.right.get_vector2("primary").x
		if absf(turn) < 0.3: vr_turn_latched = false
		if absf(turn) > 0.7 and not vr_turn_latched:
			rotate_y(-signf(turn) * PI / 6.0)
			vr_turn_latched = true
	
	# Dynamic collision shape resizing
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var target_height = CROUCHING_HEIGHT if is_crouching else STANDING_HEIGHT
		collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, CROUCH_LERP_SPEED * delta)
		collision_shape.position.y = collision_shape.shape.height * 0.5
	
	# Movement input
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if vr_mode:
		var stick: Vector2 = vr_rig.left.get_vector2("primary")
		input_dir = Vector2(stick.x, -stick.y) if stick.length() > 0.2 else Vector2.ZERO
	input_dir = input_dir.normalized()
	
	var active_speed = crouch_speed if is_crouching else standing_speed
	var move_basis := camera.global_basis if vr_mode else transform.basis
	var direction = (move_basis * Vector3(input_dir.x, 0, input_dir.y))
	direction.y = 0.0
	direction = direction.normalized()
	if direction:
		velocity.x = direction.x * active_speed
		velocity.z = direction.z * active_speed
	else:
		velocity.x = move_toward(velocity.x, 0, active_speed)
		velocity.z = move_toward(velocity.z, 0, active_speed)
	
	move_and_slide()
	
	# Hold right-click to spray extinguisher
	if (vr_mode and vr_rig.trigger_down()) or (not vr_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		if held_object and held_object.has_method("start_spraying"):
			held_object.start_spraying()
	else:
		if held_object and held_object.has_method("stop_spraying"):
			held_object.stop_spraying()

func _process_smoke_and_oxygen(delta: float):
	if not is_alive:
		return
		
	var breathing_point = camera.global_position
	is_in_smoke = false
	var current_density: float = 0.0
	
	# Check all active smoke zones — track the highest density affecting the player
	var smoke_zones = get_tree().get_nodes_in_group("smoke_zone")
	for zone in smoke_zones:
		if zone.has_method("is_in_smoke") and zone.is_in_smoke(breathing_point):
			is_in_smoke = true
			var d = zone.get("smoke_density")
			if d != null:
				current_density = max(current_density, d)
			else:
				current_density = 1.0

	# Deplete or recover oxygen proportional to smoke density
	if is_in_smoke:
		current_oxygen = max(0.0, current_oxygen - oxygen_depletion_rate * current_density * delta)
		if current_oxygen <= 0.0:
			_die_of_suffocation()
		# Track that we were in smoke while crouched (for auto-release later)
		if is_crouch_toggled:
			_was_in_smoke_while_crouched = true
	else:
		current_oxygen = min(max_oxygen, current_oxygen + oxygen_recovery_rate * delta)
		# Auto-release the crouch toggle ONLY if we crouched specifically to escape
		# smoke and that smoke has now fully cleared — never when there was no smoke at all
		if is_crouch_toggled and _was_in_smoke_while_crouched and current_density <= 0.0:
			is_crouch_toggled = false
			_was_in_smoke_while_crouched = false

	# Update HUD — pass density so it can show graduated warning intensity
	if oxygen_hud and oxygen_hud.has_method("update_oxygen"):
		oxygen_hud.update_oxygen(current_oxygen, max_oxygen, is_in_smoke, is_crouching, delta, current_density)

func _die_of_suffocation():
	if not is_alive:
		return
	is_alive = false
	print("Player suffocated from smoke inhalation!")
	
	# Drop held item if spraying
	if held_object and held_object.has_method("stop_spraying"):
		held_object.stop_spraying()
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("game_over"):
		gm.game_over("SUFFOCATED BY TOXIC SMOKE")

func _try_interact():
	if held_object:
		# Drop: restore saved physics properties
		if held_object.has_method("stop_spraying"):
			held_object.stop_spraying()
		if "_holder_camera" in held_object:
			held_object._holder_camera = null
		held_object.gravity_scale = _held_gravity_scale
		held_object.linear_damp = _held_linear_damp
		held_object.angular_damp = _held_angular_damp
		held_object = null
		print("Dropped object")
		return
	
	if raycast and raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# Walk up parent chain for interactable (e.g. door)
		var node = collider
		while node:
			if node.has_method("interact"):
				node.interact()
				return
			node = node.get_parent()
		
		# Pickup logic — spring carry, no freeze, so physics resolves wall collisions
		if collider is RigidBody3D:
			if collider.is_in_group("victim") and MissionSystem.current_step < MissionSystem.Step.FIND_VICTIM:
				return
			held_object = collider
			# Save original physics properties
			_held_gravity_scale = held_object.gravity_scale
			_held_linear_damp   = held_object.linear_damp
			_held_angular_damp  = held_object.angular_damp
			# Disable gravity + add heavy damping so we control it
			held_object.gravity_scale = 0.0
			held_object.linear_damp   = 6.0
			held_object.angular_damp  = 8.0
			# Extinguisher: give it our camera for orientation
			if "_holder_camera" in held_object:
				held_object._holder_camera = camera
			print("Picked up: ", collider.name)
			
			# Mission advancement

func _toggle_torch():
	if not torch:
		return
	torch_on = !torch_on
	var tween = create_tween()
	var target_energy = TORCH_ENERGY if torch_on else 0.0
	tween.tween_property(torch, "light_energy", target_energy, 0.25)
	print("Torch: ", "ON" if torch_on else "OFF")

func _process(delta):
	# Spring-carry: push held object toward hold point using linear_velocity.
	# Physics engine is still running so it will stop the object at walls.
	if held_object and is_instance_valid(held_object):
		var target_pos = camera.global_position + (-camera.global_transform.basis.z * HOLD_DISTANCE)
		if held_object.is_in_group("victim"):
			target_pos.y -= 0.8
		var diff = target_pos - held_object.global_position
		held_object.linear_velocity = diff * CARRY_SPRING
		# Kill spin so item doesn't tumble
		held_object.angular_velocity = Vector3.ZERO

	# Oxygen & Smoke hazard checking
	_process_smoke_and_oxygen(delta)

	# Fire burn damage
	_process_burn_damage(delta)

	# Crosshair fire-aim indicator
	_update_fire_aim_indicator()

	# Torch flicker
	if torch_on and torch:
		torch.light_energy = TORCH_ENERGY + randf_range(-0.15, 0.15)

## Check proximity to all active fire nodes — deal burn damage if too close.
func _process_burn_damage(delta: float) -> void:
	if not is_alive:
		return
	is_on_fire = false
	var player_pos = global_position
	var fire_nodes = get_tree().get_nodes_in_group("fire")
	for fire in fire_nodes:
		if not is_instance_valid(fire):
			continue
		# Skip fully extinguished fires
		var extinguished = fire.get("is_extinguished")
		if extinguished != null and extinguished:
			continue
		var dist = player_pos.distance_to(fire.global_position)
		if dist <= burn_radius:
			is_on_fire = true
			var intensity = 1.0 - (dist / burn_radius)  # closer = more damage
			current_health -= burn_damage_rate * intensity * delta
			current_health = max(0.0, current_health)
			break
	if not is_on_fire:
		current_health = min(max_health, current_health + health_regen_rate * delta)
	if current_health <= 0.0:
		_die_of_burns()
	# Push health to HUD
	if oxygen_hud and oxygen_hud.has_method("update_health"):
		oxygen_hud.update_health(current_health, max_health, is_on_fire)

func _die_of_burns() -> void:
	if not is_alive:
		return
	is_alive = false
	print("Player burned to death!")
	if held_object and held_object.has_method("stop_spraying"):
		held_object.stop_spraying()
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("game_over"):
		gm.game_over("BURNED ALIVE")

## Light up the crosshair when the player's raycast is pointing at fire or a combustible.
func _update_fire_aim_indicator() -> void:
	is_aiming_at_fire = false
	if not raycast or not raycast.is_colliding():
		_set_crosshair_fire(false)
		return
	var collider = raycast.get_collider()
	if collider == null:
		_set_crosshair_fire(false)
		return
	# Check if it's a fire or combustible area
	var node = collider
	while node:
		if node.is_in_group("fire") or node.is_in_group("combustible"):
			is_aiming_at_fire = true
			break
		node = node.get_parent()
	_set_crosshair_fire(is_aiming_at_fire)

func _set_crosshair_fire(on: bool) -> void:
	if oxygen_hud and oxygen_hud.has_method("set_crosshair_fire"):
		oxygen_hud.set_crosshair_fire(on)
