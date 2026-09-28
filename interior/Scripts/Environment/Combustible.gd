extends Area3D
class_name Combustible

## Combustible Area3D component attached to flammable objects (furniture, debris, doors).
## Accumulates heat from nearby fires. Smolders when hot, ignites into active flames,
## and progressively chars the object's visual appearance.

@export var object_name: String = "Furniture"
@export var ignition_threshold: float = 100.0
@export var flammability_multiplier: float = 1.0
@export var natural_cooling_rate: float = 8.0
@export var fire_offset: Vector3 = Vector3(0, 0.4, 0)
@export var max_burn_duration: float = 90.0
## Thin fabrics (curtains, towels, paper) burn much faster and generate more spread heat
@export var is_thin_fabric: bool = false

var current_heat: float = 0.0
var is_ignited: bool = false
var is_burnt_out: bool = false
var burn_time: float = 0.0
var heat_received_this_frame: bool = false

# Internal nodes
var smolder_particles: CPUParticles3D
var active_fire_node: Node3D = null
var original_material: Material = null
var target_mesh: GeometryInstance3D = null

# Preload the Fire scene
var fire_scene: PackedScene = preload("res://interior/Scenes/Environment/Fire.tscn")

func _ready():
	add_to_group("combustible")
	collision_layer = 2 # Match Fire layer so extinguisher raycast can hit
	collision_mask = 0
	_setup_collision()
	_setup_smolder_particles()
	_find_target_mesh()

func _setup_collision():
	if get_node_or_null("CollisionShape3D"):
		return
	
	var parent = get_parent()
	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	
	if parent is CSGBox3D:
		var box = BoxShape3D.new()
		box.size = parent.size
		col.shape = box
		add_child(col)
	elif parent is CollisionObject3D:
		for child in parent.get_children():
			if child is CollisionShape3D and child.shape:
				col.shape = child.shape.duplicate()
				add_child(col)
				break
	else:
		var box = BoxShape3D.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		col.shape = box
		add_child(col)

func _find_target_mesh():
	var parent = get_parent()
	if parent is GeometryInstance3D:
		target_mesh = parent
	else:
		for child in get_children():
			if child is GeometryInstance3D:
				target_mesh = child
				break

	
	if target_mesh:
		if target_mesh.material_override:
			original_material = target_mesh.material_override.duplicate()
			target_mesh.material_override = original_material
		elif "material" in target_mesh and target_mesh.material:
			original_material = target_mesh.material.duplicate()
			target_mesh.material = original_material

func _setup_smolder_particles():
	smolder_particles = CPUParticles3D.new()
	smolder_particles.name = "SmolderParticles"
	smolder_particles.amount = 18
	smolder_particles.lifetime = 1.6
	smolder_particles.emitting = false
	smolder_particles.direction = Vector3(0, 1, 0)
	smolder_particles.spread = 25.0
	smolder_particles.gravity = Vector3(0, 0.8, 0)
	smolder_particles.initial_velocity_min = 0.3
	smolder_particles.initial_velocity_max = 0.7
	smolder_particles.scale_amount_min = 0.4
	smolder_particles.scale_amount_max = 1.0
	smolder_particles.color = Color(0.3, 0.28, 0.25, 0.35)
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.32, 0.3, 0.4)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	var qmesh = QuadMesh.new()
	qmesh.material = mat
	qmesh.size = Vector2(0.5, 0.5)
	smolder_particles.mesh = qmesh
	
	add_child(smolder_particles)
	smolder_particles.position = fire_offset

func apply_heat(amount: float, source: Node3D = null):
	if is_ignited or is_burnt_out:
		return
	
	heat_received_this_frame = true
	current_heat += amount * flammability_multiplier
	
	# Start smoldering visually once heat passes 35%
	if current_heat >= 35.0 and not is_ignited:
		if smolder_particles and not smolder_particles.emitting:
			smolder_particles.emitting = true
			print(object_name, " is smoldering! Heat: %.1f" % current_heat)
	
	# Flashover ignition!
	if current_heat >= ignition_threshold:
		ignite()

func cool_down(amount: float):
	current_heat = max(0.0, current_heat - amount)
	if current_heat < 30.0 and smolder_particles and smolder_particles.emitting:
		smolder_particles.emitting = false

func apply_extinguisher(amount: float):
	cool_down(amount)

func ignite():
	if is_ignited or is_burnt_out:
		return
	
	is_ignited = true
	current_heat = ignition_threshold
	# Thin fabrics burn out much faster
	if is_thin_fabric:
		max_burn_duration = min(max_burn_duration, 20.0)
	if smolder_particles:
		smolder_particles.emitting = false
	
	print("FLASHOVER! Fire spread to: ", object_name)
	
	# Spawn active fire
	if fire_scene:
		active_fire_node = fire_scene.instantiate()
		add_child(active_fire_node)
		active_fire_node.position = fire_offset
	
	# Trigger tactical HUD warning
	_broadcast_fire_spread()

func _broadcast_fire_spread():
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		var hud = player.get_node_or_null("OxygenHUD")
		if hud and hud.has_method("show_spread_alert"):
			hud.show_spread_alert(object_name)
	
	# Check if victim is dangerously close (< 3.0m)
	var victims = get_tree().get_nodes_in_group("victim")
	for victim in victims:
		if global_position.distance_to(victim.global_position) < 3.0:
			for player in players:
				var hud = player.get_node_or_null("OxygenHUD")
				if hud and hud.has_method("show_victim_danger_alert"):
					hud.show_victim_danger_alert()

func _process(delta):
	# Natural cooling when not receiving external heat
	if not heat_received_this_frame and not is_ignited:
		if current_heat > 0:
			current_heat = max(0.0, current_heat - natural_cooling_rate * delta)
			if current_heat < 30.0 and smolder_particles and smolder_particles.emitting:
				smolder_particles.emitting = false
	heat_received_this_frame = false
	
	# Check if active fire was extinguished
	if is_ignited and active_fire_node:
		var fire_health = active_fire_node.get_node_or_null(".")
		if fire_health and "is_extinguished" in fire_health and fire_health.is_extinguished:
			_on_fire_extinguished()
	
	# Handle charring & burn duration while ignited
	if is_ignited:
		burn_time += delta
		_apply_charring(delta)
		
		if burn_time >= max_burn_duration:
			_burn_out()

func _apply_charring(delta):
	if target_mesh:
		var mat = target_mesh.material_override
		if not mat and "material" in target_mesh:
			mat = target_mesh.material
		
		if mat and mat is StandardMaterial3D:
			var char_target = Color(0.1, 0.08, 0.08, 1.0)
			mat.albedo_color = mat.albedo_color.lerp(char_target, delta * 0.15)

func _on_fire_extinguished():
	print(object_name, " fire was extinguished!")
	is_ignited = false
	current_heat = 0.0
	if smolder_particles:
		smolder_particles.emitting = false

func _burn_out():
	is_burnt_out = true
	is_ignited = false
	if active_fire_node and is_instance_valid(active_fire_node):
		active_fire_node.queue_free()
		active_fire_node = null
	if smolder_particles:
		smolder_particles.emitting = false
	# Permanently char the mesh to pure black ash — object stays as a visual husk
	if target_mesh:
		var mat = target_mesh.material_override
		if not mat and "material" in target_mesh:
			mat = target_mesh.material
		if mat and mat is StandardMaterial3D:
			mat.albedo_color = Color(0.05, 0.04, 0.04, 1.0)
	print(object_name, " has burned out completely to ash.")
