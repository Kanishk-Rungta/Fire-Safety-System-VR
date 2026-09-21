extends Node3D
## Render the same menu/HUD in the headset and forward controller-ray UI clicks.
var viewport: SubViewport
var surface: MeshInstance3D
var interactive := true
var cursor := Vector2(-1, -1)
var previous_cursor := Vector2.ZERO
var mouse_held := false
const PANEL_SIZE := Vector2(1.9, 1.06875)

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.gui_disable_input = false
	add_child(viewport)
	surface = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PANEL_SIZE
	surface.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = viewport.get_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = material
	add_child(surface)

func follow(camera: Camera3D) -> void:
	global_transform = camera.global_transform
	global_position -= camera.global_basis.z * 1.8

func project_ray(ray: Transform3D) -> Vector2:
	var inverse := global_transform.affine_inverse()
	var start := inverse * ray.origin
	var direction := inverse.basis * -ray.basis.z
	if absf(direction.z) < 0.00001: return Vector2(-1, -1)
	var distance := -start.z / direction.z
	if distance <= 0.0: return Vector2(-1, -1)
	var point := start + direction * distance
	var uv := Vector2(point.x / PANEL_SIZE.x + 0.5, 0.5 - point.y / PANEL_SIZE.y)
	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1: return Vector2(-1, -1)
	return uv * Vector2(viewport.size)

func update_pointer(ray: Transform3D, tracked: bool) -> void:
	cursor = project_ray(ray) if interactive and tracked else Vector2(-1, -1)
	var event := InputEventMouseMotion.new()
	event.position = cursor
	event.global_position = cursor
	event.relative = cursor - previous_cursor
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if mouse_held else 0
	viewport.push_input(event, true)
	previous_cursor = cursor

func click(pressed: bool) -> void:
	if pressed and (not interactive or cursor.x < 0): return
	if not pressed and not mouse_held: return
	mouse_held = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = cursor
	event.global_position = cursor
	viewport.push_input(event, true)
