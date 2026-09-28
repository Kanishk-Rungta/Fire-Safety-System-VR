extends RigidBody3D

## VictimNPC — the character the player must rescue.
## - Takes burn damage when near active fire nodes
## - Takes smoke damage over time (faster than player, they're unconscious)
## - Shows distress audio when hurt
## - Turns red visually as health drops

@export var max_health: float = 100.0
@export var burn_damage_rate: float = 25.0    # HP/s inside fire — higher than player (unconscious)
@export var burn_radius: float = 1.8
@export var smoke_damage_rate: float = 6.0    # HP/s in smoke
@export var health_regen_rate: float = 2.0    # minimal passive regen away from hazards

var current_health: float = 100.0
var is_alive: bool = true

@onready var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var audio: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")

# Base material colour (blue suit)
const BASE_COLOR    = Color(0.2, 0.4, 0.8, 1)
const BURN_COLOR    = Color(0.9, 0.2, 0.05, 1)
const DANGER_COLOR  = Color(1.0, 0.5, 0.0, 1)

var _burn_mat: StandardMaterial3D = null
var _distress_timer: float = 0.0

func _ready():
	add_to_group("victim")
	# Clone the mesh material so we can tint it without affecting other instances
	if mesh and mesh.mesh and mesh.mesh.material:
		_burn_mat = mesh.mesh.material.duplicate()
		mesh.material_override = _burn_mat

func _process(delta: float) -> void:
	if not is_alive:
		return

	var my_pos = global_position
	var is_on_fire = false
	var is_in_smoke = false

	# ── Fire proximity check ────────────────────────────────────────────────
	for fire in get_tree().get_nodes_in_group("fire"):
		if not is_instance_valid(fire):
			continue
		var extinguished = fire.get("is_extinguished")
		if extinguished != null and extinguished:
			continue
		var dist = my_pos.distance_to(fire.global_position)
		if dist <= burn_radius:
			is_on_fire = true
			var intensity = 1.0 - (dist / burn_radius)
			current_health -= burn_damage_rate * intensity * delta
			break

	# ── Smoke proximity check ───────────────────────────────────────────────
	if not is_on_fire:
		for zone in get_tree().get_nodes_in_group("smoke_zone"):
			if zone.has_method("is_in_smoke") and zone.is_in_smoke(my_pos + Vector3(0, 1.0, 0)):
				is_in_smoke = true
				var density = zone.get("smoke_density") if zone.get("smoke_density") != null else 1.0
				current_health -= smoke_damage_rate * density * delta
				break

	# ── Regen when safe ─────────────────────────────────────────────────────
	if not is_on_fire and not is_in_smoke:
		current_health = min(max_health, current_health + health_regen_rate * delta)

	current_health = max(0.0, current_health)

	# ── Visual health feedback ──────────────────────────────────────────────
	_update_appearance(is_on_fire)

	# ── Death ───────────────────────────────────────────────────────────────
	if current_health <= 0.0:
		_victim_died()

	# ── Distress audio cue ──────────────────────────────────────────────────
	if (is_on_fire or is_in_smoke) and audio:
		_distress_timer -= delta
		if _distress_timer <= 0.0:
			# Would play a cough/groan if an audio stream were assigned
			_distress_timer = 3.5

func _update_appearance(on_fire: bool) -> void:
	if not _burn_mat:
		return
	var ratio = clamp(current_health / max_health, 0.0, 1.0)
	if on_fire:
		# Flash orange-red rapidly
		var flicker = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		_burn_mat.albedo_color = BURN_COLOR.lerp(DANGER_COLOR, flicker)
	else:
		# Lerp from blue (healthy) to orange-red (critically hurt)
		_burn_mat.albedo_color = BASE_COLOR.lerp(DANGER_COLOR, 1.0 - ratio)

func _victim_died() -> void:
	if not is_alive:
		return
	is_alive = false
	print("Victim died — game over!")
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("game_over"):
		gm.game_over("VICTIM PERISHED IN THE FIRE")
