extends RigidBody3D

@onready var raycast = $RayCast3D
@onready var particles = $GPUParticles3D
@onready var audio = $AudioStreamPlayer3D

var is_spraying = false
## 200/s so a burst visibly kills a fire quickly
var spray_damage_per_sec = 200.0
## Radius within which nearby Combustible objects are cooled
var spray_cool_radius = 2.0

## Cached reference to the holding player's camera — set on pickup
var _holder_camera: Camera3D = null

func _ready():
	particles.emitting = false
	raycast.collide_with_areas = true

func start_spraying():
	if not is_spraying:
		is_spraying = true
		particles.emitting = true
		if audio and not audio.playing:
			audio.play()

func stop_spraying():
	if is_spraying:
		is_spraying = false
		particles.emitting = false
		if audio and audio.playing:
			audio.stop()

func _physics_process(delta):
	# ── Orientation: smoothly face the same direction as the holder's camera ──
	if _holder_camera:
		var cam_basis = _holder_camera.global_transform.basis
		global_transform.basis = global_transform.basis.slerp(cam_basis, 10.0 * delta)

func _process(delta):

	# ── Spray logic ────────────────────────────────────────────────────────
	if is_spraying:
		# 1. Raycast: hit whatever the nozzle aims at directly
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider:
				if collider.has_method("apply_extinguisher"):
					collider.apply_extinguisher(spray_damage_per_sec * delta)
				elif collider.get_parent() and collider.get_parent().has_method("apply_extinguisher"):
					collider.get_parent().apply_extinguisher(spray_damage_per_sec * delta)

		# 2. Area cool: suppress nearby smoldering Combustibles in spray radius
		var nozzle_pos = raycast.global_position
		var combustibles = get_tree().get_nodes_in_group("combustible")
		for obj in combustibles:
			if not is_instance_valid(obj):
				continue
			if obj.get("is_burnt_out"):
				continue
			var dist = nozzle_pos.distance_to(obj.global_position)
			if dist <= spray_cool_radius:
				if obj.has_method("cool_down"):
					var falloff = 1.0 - (dist / spray_cool_radius)
					obj.cool_down(spray_damage_per_sec * falloff * delta)
