extends Node3D
## Native implementation of FireController's state, growth and particle damage.
var hp := 0.001
var upper := 10000.0
var growth := 100.0
var particle_damage := 0.45
var burning := false
var put_out := false
var neighbours: Array = []
var flame: MeshInstance3D
var smoke: CPUParticles3D
var sparks: CPUParticles3D
var material: ShaderMaterial

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/fire.gdshader")
	for angle in [0.0, PI / 2.0]:
		flame = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.8, 2.5)
		flame.mesh = quad
		flame.material_override = material
		flame.position.y = 1.1
		flame.rotation.y = angle
		add_child(flame)
	smoke = particles(Color(0.16, 0.16, 0.16, 0.5), 30, 0.4, 1.0, 5.0)
	smoke.position.y = 1.8
	sparks = particles(Color(1.0, 0.45, 0.04), 20, 0.02, 2.8, 1.2)
	visible = false

func particles(color: Color, count: int, size: float, speed: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 0.1, 0)
	p.initial_velocity_min = speed
	p.initial_velocity_max = speed * 1.5
	p.scale_amount_min = size
	p.scale_amount_max = size * 2.0
	p.color = color
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	p.emitting = false
	add_child(p)
	return p

func ignite() -> void:
	if burning or put_out: return
	burning = true
	hp = 0.001
	visible = true
	smoke.emitting = true
	sparks.emitting = true

func tick(delta: float) -> void:
	if not burning: return
	hp = minf(upper + 1.0, hp + growth * delta)
	material.set_shader_parameter("strength", clampf(hp / upper, 0.0, 1.0))
	if hp >= upper:
		for other in neighbours: other.ignite()

func extinguish(particle_hits: float) -> void:
	if not burning: return
	hp -= particle_hits * particle_damage
	if hp < 0.0:
		burning = false
		put_out = true
		visible = false
		smoke.emitting = false
		sparks.emitting = false
