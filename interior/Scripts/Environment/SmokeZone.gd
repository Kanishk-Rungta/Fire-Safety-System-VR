extends Area3D
class_name SmokeZone

## SmokeZone represents a hazardous smoke layer accumulating near the ceiling.
## If the player's breathing point (camera) is inside this area and above the clear-air threshold,
## the player inhales toxic smoke and consumes oxygen.
##
## When a window is opened the smoke gradually clears:
##   - smoke_density drops from 1.0 → 0.0 over disperse_duration seconds
##   - lower_bound_y drops (smoke layer sinks) while dispersing
##   - Once density hits 0, is_active = false and particles stop

@export var smoke_density: float = 1.0
@export var is_active: bool = true
@export var lower_bound_y: float = 1.25
@export var disperse_duration: float = 12.0  ## seconds to fully clear after window opened

@onready var smoke_mesh: MeshInstance3D = get_node_or_null("SmokeMesh")
@onready var particles: CPUParticles3D = get_node_or_null("CPUParticles3D")

var _dispersing: bool = false
var _disperse_timer: float = 0.0
var _initial_density: float = 1.0
var _initial_lower_bound: float = 1.25
var _initial_alpha: float = 0.42   # matches SmokeZone.tscn material alpha

func _ready():
	add_to_group("smoke_zone")
	collision_layer = 16
	collision_mask = 0
	_initial_density = smoke_density
	_initial_lower_bound = lower_bound_y

func _process(delta: float) -> void:
	if not _dispersing:
		return

	_disperse_timer += delta
	var t: float = clamp(_disperse_timer / disperse_duration, 0.0, 1.0)

	# Density and lower_bound drop together — smoke thins AND sinks
	smoke_density = lerp(_initial_density, 0.0, t)
	# Smoke layer floor drops from 1.25m → 0m (sinks to floor as it clears)
	lower_bound_y = lerp(_initial_lower_bound, 0.0, t)

	# Fade the visual mesh alpha
	if smoke_mesh:
		var mat = smoke_mesh.material_override
		if mat == null and smoke_mesh.mesh and smoke_mesh.mesh.material:
			mat = smoke_mesh.mesh.material
		if mat:
			var new_alpha: float = lerp(_initial_alpha, 0.0, t)
			mat.albedo_color.a = new_alpha

	# Scale down particle emission proportionally
	if particles:
		var target_amount = int(max(0, 45.0 * (1.0 - t)))
		if particles.amount != target_amount:
			particles.amount = target_amount

	# Fully cleared
	if t >= 1.0:
		is_active = false
		_dispersing = false
		if particles:
			particles.emitting = false
		if smoke_mesh:
			smoke_mesh.visible = false

## Check if a given global position is inside this smoke zone and above the smoke floor.
## The effective threshold scales with smoke_density — as smoke thins the hazard shrinks.
func is_in_smoke(global_pos: Vector3) -> bool:
	if not is_active or smoke_density <= 0.0:
		return false

	# Effective floor rises as density increases (dense smoke fills more of the room)
	var effective_lower = lower_bound_y * smoke_density
	if global_pos.y < effective_lower:
		return false

	var col = get_node_or_null("CollisionShape3D")
	if col and col.shape is BoxShape3D:
		var local_pos = to_local(global_pos)
		var half_size = col.shape.size * 0.5
		if abs(local_pos.x) <= half_size.x and abs(local_pos.z) <= half_size.z:
			return true

	return false

## Call this when a window is opened — smoke clears gradually over disperse_duration seconds.
func gradual_disperse() -> void:
	if _dispersing or not is_active:
		return
	_dispersing = true
	_disperse_timer = 0.0
	_initial_density = smoke_density
	_initial_lower_bound = lower_bound_y
	# Capture current mesh alpha so the fade starts from wherever it currently is
	if smoke_mesh:
		var mat = smoke_mesh.material_override
		if mat == null and smoke_mesh.mesh and smoke_mesh.mesh.material:
			mat = smoke_mesh.mesh.material
		if mat:
			_initial_alpha = mat.albedo_color.a
	print("SmokeZone: dispersing over ", disperse_duration, "s")

## Instantly reactivate (called when window is closed again).
func reactivate() -> void:
	_dispersing = false
	_disperse_timer = 0.0
	is_active = true
	smoke_density = _initial_density
	lower_bound_y = _initial_lower_bound
	if particles:
		particles.amount = 45
		particles.emitting = true
	if smoke_mesh:
		smoke_mesh.visible = true
		var mat = smoke_mesh.material_override
		if mat == null and smoke_mesh.mesh and smoke_mesh.mesh.material:
			mat = smoke_mesh.mesh.material
		if mat:
			mat.albedo_color.a = _initial_alpha

## Legacy instant disperse kept for compatibility
func disperse(fade_time: float = 2.0):
	is_active = false
	var tween = create_tween()
	if smoke_mesh and smoke_mesh.material_override:
		tween.tween_property(smoke_mesh.material_override, "albedo_color:a", 0.0, fade_time)
	if particles:
		particles.emitting = false
