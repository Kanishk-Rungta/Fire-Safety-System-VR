extends Area3D

@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var heat_radius: float = 3.2
@export var heat_emission_rate: float = 18.0

@onready var particles = $GPUParticles3D
@onready var light = $OmniLight3D
@onready var audio = $AudioStreamPlayer3D

var is_extinguished: bool = false

func _ready():
	current_health = max_health
	add_to_group("fire")


func _process(delta):
	if is_extinguished:
		return
		
	# Scale visual intensity based on health
	var health_ratio = current_health / max_health
	light.light_energy = 2.0 * health_ratio
	
	# Scale CPUParticles3D emission based on health
	# CPUParticles3D doesn't have amount_ratio, so we scale the amount manually
	# Note: Changing amount at runtime restarts the emission, but it's safe for simple fire
	var target_amount = int(max(4, 64 * health_ratio))
	if particles.amount != target_amount:
		particles.amount = target_amount
	
	if current_health <= 0:
		extinguish()
		return
		
	# Dynamically adjust particles and light based on fire health
	light.light_energy = max(0.1, health_ratio * 2.0)
	if audio:
		audio.volume_db = lerp(-40.0, 0.0, health_ratio)
	
	# Radiate heat to nearby combustible objects
	_radiate_heat(delta, health_ratio)

func _radiate_heat(delta: float, intensity: float):
	var combustibles = get_tree().get_nodes_in_group("combustible")
	for obj in combustibles:
		if not is_instance_valid(obj) or obj == self:
			continue
		var dist = global_position.distance_to(obj.global_position)
		if dist <= heat_radius:
			var falloff = 1.0 - (dist / heat_radius)
			var heat_applied = heat_emission_rate * falloff * intensity * delta
			if obj.has_method("apply_heat"):
				obj.apply_heat(heat_applied, self)


func apply_extinguisher(amount: float):
	if not is_extinguished:
		current_health -= amount
		
func extinguish():
	is_extinguished = true
	current_health = 0.0
	particles.emitting = false
	light.visible = false
	if audio:
		audio.playing = false
		
