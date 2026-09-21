extends Node3D

const Network = preload("res://scripts/water_network.gd")
const Player = preload("res://scripts/player.gd")
const VRPlayer = preload("res://scripts/vr_player.gd")
const VRPanel = preload("res://scripts/vr_panel.gd")
const FirePatch = preload("res://scripts/fire_patch.gd")
var level := ""
var control_mode := ""
var menu_page := "controls"
var xr_interface: XRInterface
var vr_panel: Node3D
var menu_status: Label
var world: Node3D
var player: CharacterBody3D
var data: Dictionary
var components: Dictionary
var nodes: Dictionary = {}
var network: RefCounted
var targets: Array[Dictionary] = []
var fires: Dictionary = {}
var hoses: Array[Dictionary] = []
var grabbed: Node3D
var grabbed_go := ""
var selected_port := ""
var aimed: Dictionary = {}
var progress := 0
var tutorial: Dictionary
var ui: CanvasLayer
var menu: Control
var hud: Control
var task_text: Label
var status_text: Label
var prompt: Label
var notice: Label
var notice_timer := 0.0
var fire_audio: AudioStreamPlayer
var water_audio: AudioStreamPlayer
var spray: CPUParticles3D
var nozzle_id := ""
var spraying := false
var completed := false
var pause_panel: Control
var pylon_template: Node3D
var elapsed := 0.0
var objective_marker: Label
var paused := false
var grabbed_rotation_offset := Quaternion.IDENTITY

func json_file(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _ready() -> void:
	tutorial = json_file("res://data/tutorial.json")
	ui = CanvasLayer.new()
	add_child(ui)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.7)
	sky_mat.sky_horizon_color = Color(0.75, 0.81, 0.86)
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.85, 0.95)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	fire_audio = audio("res://assets/FireSound.wav", -14)
	water_audio = audio("res://assets/JetPipeActiveSound.wav", -12)
	show_menu()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--level="):
			select_control_mode("keyboard")
			start_level(arg.substr(8))
	if "--smoke" in args:
		await get_tree().create_timer(2.0).timeout
		print("SMOKE_OK level=", level, " nodes=", nodes.size(), " ports=", network.ports.size() if network else 0)
		get_tree().quit()
	for arg in args:
		if arg.begins_with("--capture="):
			await get_tree().create_timer(3.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.substr(10))
			get_tree().quit()

func audio(path: String, volume: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = load(path)
	if a.stream is AudioStreamWAV:
		a.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	a.volume_db = volume
	add_child(a)
	return a

func full_control() -> Control:
	var c := Control.new()
	var theme := Theme.new()
	theme.default_font = preload("res://assets/LiberationSans_sharedassets0_assets_16.ttf")
	c.theme = theme
	ui.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

func label_at(parent: Control, text: String, pos: Vector2, size: Vector2, font_size := 20) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	parent.add_child(l)
	return l

func button(parent: Control, text: String, pos: Vector2, action: Callable, width := 240.0) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(width, 45)
	b.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.9, 0.9)
	style.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func show_menu() -> void:
	stop_vr()
	control_mode = ""
	menu_page = "controls"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(world): world.queue_free()
	if is_instance_valid(player): player.queue_free()
	if is_instance_valid(hud): hud.queue_free()
	if is_instance_valid(pause_panel): pause_panel.queue_free()
	if is_instance_valid(menu): menu.queue_free()
	world = null
	player = null
	level = ""
	fire_audio.stop()
	water_audio.stop()
	build_menu_background()
	var title := label_at(menu, "Choose your controls", Vector2(390, 140), Vector2(500, 50), 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(menu, "Keyboard & Mouse", Vector2(460, 255), select_control_mode.bind("keyboard"), 360)
	button(menu, "Meta VR Headset", Vector2(460, 330), select_control_mode.bind("vr"), 360)
	button(menu, "Quit", Vector2(460, 430), func(): get_tree().quit(), 360)
	menu_status = label_at(menu, "", Vector2(260, 500), Vector2(760, 135), 20)
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func build_menu_background() -> void:
	if is_instance_valid(menu):
		menu.hide()
		menu.queue_free()
	menu = full_control()
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.22126484, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)

func select_control_mode(mode: String) -> void:
	if mode not in ["keyboard", "vr"]: return
	if mode == "vr" and not start_vr(): return
	if mode == "keyboard": stop_vr()
	control_mode = mode
	show_maps()

func show_maps() -> void:
	menu_page = "maps"
	build_menu_background()
	var title := label_at(menu, "Choose a map", Vector2(390, 135), Vector2(500, 50), 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := label_at(menu, "Meta VR Headset" if control_mode == "vr" else "Keyboard & Mouse", Vector2(390, 190), Vector2(500, 35), 21)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(menu, "City Level", Vector2(460, 260), start_level.bind("city"), 360)
	button(menu, "Forest Level", Vector2(460, 330), start_level.bind("forest"), 360)
	button(menu, "Back to Controls", Vector2(460, 420), show_menu, 360)
	button(menu, "Quit", Vector2(460, 490), func(): get_tree().quit(), 360)

func start_vr() -> bool:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null or (not xr_interface.is_initialized() and not xr_interface.initialize()):
		menu_status.text = "Meta VR could not start. Connect Quest Link or Air Link, set Meta Quest Link as the active OpenXR runtime, then select Meta VR Headset again."
		return false
	get_viewport().use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if not xr_interface.session_focussed.is_connected(on_xr_focused):
		xr_interface.session_focussed.connect(on_xr_focused)
		xr_interface.session_visible.connect(on_xr_unfocused)
		xr_interface.session_stopping.connect(on_xr_unfocused)
	player = VRPlayer.new()
	add_child(player)
	wire_vr_player()
	vr_panel = VRPanel.new()
	add_child(vr_panel)
	ui.reparent(vr_panel.viewport)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true

func stop_vr() -> void:
	if is_instance_valid(vr_panel):
		ui.reparent(self)
		vr_panel.hide()
		vr_panel.queue_free()
		vr_panel = null
	get_viewport().use_xr = false
	if xr_interface and xr_interface.is_initialized(): xr_interface.uninitialize()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

func wire_vr_player() -> void:
	# Defer callbacks because a UI action can replace the rig/panel that emitted it.
	player.action_pressed.connect(on_vr_action, CONNECT_DEFERRED)
	player.action_released.connect(on_vr_release, CONNECT_DEFERRED)

func on_xr_focused() -> void:
	# Resume is explicit, preventing an unexpected action on headset refocus.
	pass

func on_xr_unfocused() -> void:
	if control_mode == "vr" and not level.is_empty() and not paused: toggle_pause()

func on_vr_action(action: String) -> void:
	if control_mode != "vr": return
	if action in ["menu", "secondary"] and not level.is_empty():
		toggle_pause()
		return
	if level.is_empty() or paused:
		if action == "trigger" and is_instance_valid(vr_panel): vr_panel.click(true)
		return
	if not player.has_pointer(): return
	aimed = find_target()
	match action:
		"grab":
			if is_instance_valid(grabbed): drop_item()
			else: pick_up()
		"connect": join_connection()
		"disconnect": disconnect_aimed()
		"trigger":
			if grabbed == component_node(nozzle_id): invoke_tutorial_event(grabbed_go, "m_Activated")
			else: use_target()

func on_vr_release(action: String) -> void:
	if control_mode == "vr" and action == "trigger" and is_instance_valid(vr_panel): vr_panel.click(false)

func aim_transform() -> Transform3D:
	return player.right.global_transform if control_mode == "vr" else player.camera.global_transform

func controls_text() -> String:
	if control_mode == "vr": return "Left stick: move | Right stick: turn | Grip: pick/place | A: connect | Stick click: disconnect | Trigger: use/spray | B: menu"
	return "WASD Move | Shift Run | E Pick up | Q Place | F Connect | C Disconnect | R Use | LMB Spray | Esc Menu"

func index_nodes(n: Node) -> void:
	if str(n.name).begins_with("U"):
		var id := str(n.name).get_slice("_", 0).substr(1)
		if id.is_valid_int(): nodes[id] = n
	for child in n.get_children(): index_nodes(child)

func rid(p: Dictionary) -> String:
	return str(int(p.get("m_PathID", 0)))

func component_node(id: String) -> Node3D:
	if not components.has(id): return null
	return nodes.get(rid(components[id].data.get("m_GameObject", {})))

func start_level(which: String) -> void:
	if which not in ["city", "forest"]: return
	if control_mode.is_empty(): return
	if control_mode == "vr" and (xr_interface == null or not xr_interface.is_initialized()): return
	if is_instance_valid(world): world.free()
	if is_instance_valid(player): player.free()
	if is_instance_valid(hud): hud.free()
	if is_instance_valid(pause_panel): pause_panel.queue_free()
	if is_instance_valid(menu): menu.hide()
	level = which
	data = json_file("res://data/" + level + ".json")
	components = data.components
	network = Network.new(components)
	nodes.clear()
	targets.clear()
	fires.clear()
	hoses.clear()
	grabbed = null
	grabbed_go = ""
	selected_port = ""
	progress = 0
	completed = false
	paused = false
	elapsed = 0.0
	world = load("res://scenes/" + level + ".tscn").instantiate()
	add_child(world)
	index_nodes(world)
	player = VRPlayer.new() if control_mode == "vr" else Player.new()
	player.name = "VRPlayer" if control_mode == "vr" else "DesktopPlayer"
	for go in data.objects:
		if data.objects[go].name == "XR Rig":
			player.position = nodes[go].global_position + Vector3.UP * 0.1
			player.rotation.y = nodes[go].global_rotation.y
	add_child(player)
	if control_mode == "vr":
		wire_vr_player()
		player.movement_enabled = true
	print("SPAWN ", level, " ", player.position)
	setup_equipment()
	setup_fires()
	setup_hud()
	setup_spray()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if control_mode == "vr" else Input.MOUSE_MODE_CAPTURED
	message(controls_text())

func setup_equipment() -> void:
	for id in components:
		var c: Dictionary = components[id]
		var d: Dictionary = c.data
		var go := rid(d.get("m_GameObject", {}))
		var n: Node3D = nodes.get(go)
		if n == null: continue
		var script: String = c.get("script", "")
		if script in ["ConnectionController", "HoseConnectionController"]:
			targets.append({"node":n,"go":go,"port":str(id),"kind":"port","title":["A", "B", "C"][int(d.connectionSize)] + " connection"})
		if script == "XRGrabInteractable":
			var is_valve := false
			for call in d.get("m_Activated", {}).get("m_PersistentCalls", {}).get("m_Calls", []):
				if call.m_MethodName == "OnToggleConnection":
					var controller := rid(call.m_Target)
					var index := int(call.m_Arguments.m_IntArgument)
					targets.append({"node":n,"go":go,"component":controller,"index":index,"kind":"valve","title":"Valve " + str(index + 1)})
					is_valve = true
			if not is_valve: targets.append({"node":n,"go":go,"component":str(id),"kind":"grab","title":data.objects[go].name})
		if script == "HydrantController":
			targets.append({"node":n,"go":go,"component":str(id),"kind":"hydrant","title":"Hydrant"})
		if script == "JetPipeController": nozzle_id = str(id)
		if script == "HoseController":
			var line := MeshInstance3D.new()
			line.mesh = ImmediateMesh.new()
			var mat := StandardMaterial3D.new()
			mat.albedo_color = [Color(0.08,0.08,0.08),Color(0.9,0.73,0.12),Color(0.72,0.06,0.035)][int(d.hoseType)]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			line.material_override = mat
			world.add_child(line)
			hoses.append({"mesh":line,"a":component_node(rid(d.connections[0])),"b":component_node(rid(d.connections[1])),"radius":[0.06,0.045,0.035][int(d.hoseType)]})
	# The pylon mesh is a prefab in sharedassets1, outside the scene's hierarchy.
	if level == "city" and ResourceLoader.exists("res://assets/equipment.glb"):
		if is_instance_valid(pylon_template): pylon_template.free()
		var prefab: Node3D = load("res://assets/equipment.glb").instantiate()
		var template := prefab.find_child("U97_*", true, false)
		if template:
			pylon_template = template.duplicate()
		prefab.free()

func setup_fires() -> void:
	var rules := json_file("res://data/fire_rules.json")
	for id in components:
		var c: Dictionary = components[id]
		if c.get("script", "") != "FireController": continue
		var original := component_node(str(id))
		original.hide()
		var patch := FirePatch.new()
		patch.upper = rules.fireUpperBorder
		patch.growth = rules.fireMultiplicator
		patch.particle_damage = rules.particleDamage
		world.add_child(patch)
		patch.global_position = original.global_position
		fires[str(id)] = patch
	for id in fires:
		for neighbour in components[id].data.neighbours:
			var key := rid(neighbour)
			if fires.has(key): fires[id].neighbours.append(fires[key])
	if not fires.is_empty(): fires[fires.keys().pick_random()].ignite()
	fire_audio.play()

func setup_hud() -> void:
	hud = full_control()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := ColorRect.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(690, 120)
	panel.color = Color(0.04, 0.05, 0.06, 0.78)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	task_text = label_at(hud, "", Vector2(34, 28), Vector2(658, 100), 20)
	task_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_text = label_at(hud, "", Vector2(850, 22), Vector2(410, 80), 19)
	status_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var cross := label_at(hud, "+", Vector2(627, 341), Vector2(26, 38), 28)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.visible = control_mode != "vr"
	prompt = label_at(hud, "", Vector2(320, 400), Vector2(640, 70), 21)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_marker = label_at(hud, "", Vector2.ZERO, Vector2(240, 28), 17)
	objective_marker.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	objective_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice = label_at(hud, "", Vector2(150, 570), Vector2(980, 65), 20)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_at(hud, "WASD Move  •  Shift Run  •  E Pick up  •  Q Place  •  F Connect  •  C Disconnect  •  R Use valve/key  •  LMB Spray  •  Esc Menu", Vector2(24, 671), Vector2(1240, 35), 16)
	update_task()

func update_task() -> void:
	var texts: Array = tutorial[level]
	progress = mini(progress, texts.size() - 1)
	task_text.text = "%s  ·  %d / %d\n%s" % [level.capitalize(), progress + 1, texts.size(), texts[progress]]

func advance(number: int) -> void:
	if progress == number:
		progress += 1
		update_task()

func event_for(go: String) -> void:
	for c in components.values():
		if c.get("script", "") == "TutorialConnectionControler" and rid(c.data.m_GameObject) == go:
			advance(int(c.data.tutorialNumber))

func invoke_tutorial_event(go: String, event_name: String) -> void:
	# Preserve which actions advance a step: grabbing and connecting are distinct.
	for c in components.values():
		if c.get("script", "") != "XRGrabInteractable" or rid(c.data.m_GameObject) != go: continue
		for call in c.data.get(event_name, {}).get("m_PersistentCalls", {}).get("m_Calls", []):
			var target_id := rid(call.m_Target)
			if components.has(target_id) and components[target_id].get("script", "") == "TutorialConnectionControler":
				advance(int(components[target_id].data.tutorialNumber))

func message(text: String) -> void:
	if is_instance_valid(notice): notice.text = text
	notice_timer = 5.0

func setup_spray() -> void:
	spray = CPUParticles3D.new()
	spray.amount = 600
	spray.lifetime = 0.75
	spray.direction = Vector3(0, 0, -1)
	spray.spread = 3.0
	spray.initial_velocity_min = 17.0
	spray.initial_velocity_max = 21.0
	spray.gravity = Vector3(0, -3.5, 0)
	spray.scale_amount_min = 0.025
	spray.scale_amount_max = 0.05
	spray.mesh = SphereMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spray.material_override = mat
	spray.emitting = false
	spray.local_coords = false
	var emitter: Node3D = player.right if control_mode == "vr" else player.camera
	emitter.add_child(spray)
	spray.position = Vector3(0, 0, -0.15) if control_mode == "vr" else Vector3(0.25, -0.2, -0.65)

func _unhandled_input(event: InputEvent) -> void:
	if control_mode != "keyboard" or level.is_empty(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		match event.physical_keycode:
			KEY_E: pick_up()
			KEY_Q: drop_item()
			KEY_F: join_connection()
			KEY_C: disconnect_aimed()
			KEY_R: use_target()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if grabbed == component_node(nozzle_id): invoke_tutorial_event(grabbed_go, "m_Activated")

func toggle_pause() -> void:
	if not paused:
		paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_panel = full_control()
		button(pause_panel, "Resume", Vector2(520, 250), toggle_pause)
		button(pause_panel, "Restart Level", Vector2(520, 320), start_level.bind(level))
		button(pause_panel, "Main Menu", Vector2(520, 390), show_menu)
	else:
		paused = false
		if is_instance_valid(pause_panel): pause_panel.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if control_mode == "vr" else Input.MOUSE_MODE_CAPTURED
	if control_mode == "vr": player.movement_enabled = not paused

func find_target() -> Dictionary:
	var best := 0.09
	var result: Dictionary = {}
	var ray := aim_transform()
	if control_mode == "vr" and not player.has_pointer(): return {}
	for target in targets:
		var n: Node3D = target.node
		if not is_instance_valid(n) or n == grabbed: continue
		if is_instance_valid(grabbed) and grabbed.is_ancestor_of(n): continue
		var offset: Vector3 = n.global_position - ray.origin
		if offset.length() > 4.5 or offset.length() < 0.1: continue
		var angle := 1.0 - offset.normalized().dot(-ray.basis.z)
		var score := angle + offset.length() * 0.0005
		if target.kind == "port": score -= 0.001
		if score < best:
			best = score
			result = target
	return result

func pick_up() -> void:
	if is_instance_valid(grabbed):
		message("Grip places the held item; A connects it." if control_mode == "vr" else "Q places the held item; F connects it to the aimed connection.")
		return
	if aimed.is_empty(): return
	var n: Node3D = aimed.node
	if aimed.kind == "valve" or aimed.kind == "hydrant":
		use_target()
		return
	if aimed.has("port"):
		selected_port = aimed.port
		if not network.ports[selected_port].isMovable:
			message("Connection selected. Aim at a matching free connection and press " + ("A." if control_mode == "vr" else "F."))
			return
		if network.links.has(selected_port):
			message("Press the right stick to disconnect first." if control_mode == "vr" else "Press C to disconnect this connection first.")
			selected_port = ""
			return
		var parent_id: String = rid(network.ports[selected_port].parentObject)
		if components[parent_id].script != "HoseController": n = component_node(parent_id)
	grabbed = n
	grabbed_go = str(n.name).get_slice("_", 0).substr(1)
	if data.objects.has(grabbed_go) and data.objects[grabbed_go].name == "PylonSpawner":
		if pylon_template:
			grabbed = pylon_template.duplicate()
			world.add_child(grabbed)
			grabbed.global_transform = n.global_transform
			grabbed.set_meta("placement_basis", n.global_basis)
			add_cone_collision(grabbed)
			grabbed_go = "pylon"
			advance(0 if progress == 0 else 2)
	set_collision(grabbed, false)
	if control_mode == "vr":
		grabbed_rotation_offset = player.grip.global_basis.get_rotation_quaternion().inverse() * grabbed.global_basis.get_rotation_quaternion()
	invoke_tutorial_event(grabbed_go, "m_SelectEntered")
	message("Holding " + (data.objects[grabbed_go].name if data.objects.has(grabbed_go) else "Pylon"))

func set_collision(n: Node, enabled: bool) -> void:
	if n is CollisionObject3D:
		n.collision_layer = 1 if enabled else 0
		n.collision_mask = 1 if enabled else 0
	for child in n.get_children(): set_collision(child, enabled)

func add_cone_collision(cone: Node3D) -> void:
	if cone is MeshInstance3D:
		# The recovered mesh is millimetres wide with an 80x transform. Build
		# the hull at physical size so convex-shape tolerances preserve it.
		var points := PackedVector3Array()
		var mesh_scale := cone.global_basis.get_scale()
		for surface in range(cone.mesh.get_surface_count()):
			for vertex in cone.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(vertex * mesh_scale)
		var hull := ConvexPolygonShape3D.new()
		hull.points = points
		var body := StaticBody3D.new()
		body.name = "ConeCollision"
		cone.add_child(body)
		body.scale = Vector3.ONE / mesh_scale
		var shape := CollisionShape3D.new()
		shape.shape = hull
		body.add_child(shape)

func drop_item() -> void:
	if not is_instance_valid(grabbed):
		selected_port = ""
		return
	var ray := aim_transform()
	var from: Vector3 = ray.origin
	var to: Vector3 = from - ray.basis.z * 3.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	place_item(hit.position + Vector3.UP * 0.05 if not hit.is_empty() else to)

func place_item(location: Vector3) -> void:
	if not is_instance_valid(grabbed): return
	grabbed.global_position = location
	for go in data.objects:
		var field_name: String = data.objects[go].name
		var held_name: String = data.objects.get(grabbed_go, {}).get("name", "")
		var valid_field := (field_name.begins_with("FieldForPylon") and grabbed_go == "pylon") or (field_name == "FieldForDistributer" and held_name == "Distributor") or (field_name == "FieldForSuctionBasket" and held_name == "SuctionBasket")
		if valid_field and nodes.has(go):
			if grabbed.global_position.distance_to(nodes[go].global_position) < 2.0:
				grabbed.global_position = nodes[go].global_position
				if grabbed_go == "pylon":
					# Return a hand-rotated VR cone to its upright placement orientation.
					grabbed.global_basis = grabbed.get_meta("placement_basis", grabbed.global_basis)
					var p := grabbed.global_position
					var ground := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP, p - Vector3.UP * 2, 1))
					if not ground.is_empty(): grabbed.global_position.y = ground.position.y
					var closure := world.get_node_or_null("RoadClosureApproach")
					if closure: closure.cone_placed(go)
				event_for(go)
	# Desktop placement uses the same lake region as the original tutorial target.
	for id in components:
		if components[id].get("script", "") == "SuctionStrainerController" and component_node(id) == grabbed:
			for go in data.objects:
				if data.objects[go].name == "FieldForSuctionBasket" and grabbed.global_position.distance_to(nodes[go].global_position) < 3.0:
					network.sources[id] = true
					event_for(go)
	set_collision(grabbed, true)
	grabbed = null
	grabbed_go = ""
	selected_port = ""

func _exit_tree() -> void:
	if is_instance_valid(pylon_template): pylon_template.free()

func held_ports() -> Array[String]:
	var result: Array[String] = []
	if not selected_port.is_empty(): result.append(selected_port)
	if is_instance_valid(grabbed):
		for port in network.ports:
			var n := component_node(port)
			if n == grabbed or grabbed.is_ancestor_of(n):
				if port not in result: result.append(port)
	return result

func join_connection() -> void:
	if aimed.is_empty() or not aimed.has("port"):
		message("Aim at an A, B or C connection to connect.")
		return
	var b: String = aimed.port
	var candidates := held_ports()
	if candidates.is_empty():
		selected_port = b
		pick_up()
		return
	for a in candidates:
		if network.connect_ports(a, b):
			var source := component_node(a)
			var destination := component_node(b)
			if is_instance_valid(grabbed):
				grabbed.global_position += destination.global_position - source.global_position
				set_collision(grabbed, true)
			event_for(rid(components[a].data.m_GameObject))
			event_for(rid(components[b].data.m_GameObject))
			grabbed = null
			grabbed_go = ""
			selected_port = ""
			message("Connected. Open the appropriate valves to supply water.")
			return
	message("Connection refused: match A/B/C sizes and use two free connections on different pieces.")

func disconnect_aimed() -> void:
	if aimed.has("port"):
		network.disconnect_port(aimed.port)
		message("Disconnected.")
	elif not selected_port.is_empty(): network.disconnect_port(selected_port)

func use_target() -> void:
	if aimed.is_empty(): return
	if aimed.has("port"):
		var parent := rid(network.ports[aimed.port].parentObject)
		if components.get(parent, {}).get("script", "") == "HydrantController":
			for target in targets:
				if target.kind == "hydrant": aimed = target; break
	if aimed.kind == "valve":
		var id: String = aimed.component
		var i: int = aimed.index
		network.valves[id][i] = not network.valves[id][i]
		var n: Node3D = component_node(rid(components[id].data.outputOpener[i]))
		var change := Vector3(0, PI/2.0, 0) if components[id].script == "DistributorController" else Vector3(0, 0, TAU)
		create_tween().tween_property(n, "rotation", n.rotation + change * (1.0 if network.valves[id][i] else -1.0), 1.0)
		invoke_tutorial_event(aimed.go, "m_SelectEntered")
		invoke_tutorial_event(aimed.go, "m_Activated")
		message("Valve " + ("open" if network.valves[id][i] else "closed"))
	elif aimed.kind == "hydrant":
		if grabbed_go.is_empty() or data.objects.get(grabbed_go, {}).get("name", "") != "HydrantKey":
			message("Pick up the hydrant key first.")
			return
		network.sources[aimed.component] = not network.sources.get(aimed.component, false)
		event_for(aimed.go)
		message("Hydrant " + ("open" if network.sources[aimed.component] else "closed"))

func _process(delta: float) -> void:
	if control_mode == "vr" and is_instance_valid(vr_panel) and is_instance_valid(player):
		vr_panel.follow(player.camera)
		vr_panel.interactive = level.is_empty() or paused
		vr_panel.update_pointer(player.right.global_transform, player.has_pointer())
	if level.is_empty() or not is_instance_valid(player): return
	if paused:
		spray.emitting = false
		water_audio.stop()
		return
	elapsed += delta
	notice_timer -= delta
	if notice_timer < 0.0: notice.text = ""
	if is_instance_valid(grabbed):
		if control_mode == "vr":
			if player.grip.get_has_tracking_data():
				grabbed.global_position = player.grip.global_position
				grabbed.global_basis = Basis(player.grip.global_basis.get_rotation_quaternion() * grabbed_rotation_offset).scaled(grabbed.global_basis.get_scale())
		else:
			var camera: Camera3D = player.camera
			grabbed.global_position = camera.global_position - camera.global_basis.z * 1.3 + camera.global_basis.x * 0.35 - camera.global_basis.y * 0.35
	for a in network.links:
		var b: String = network.links[a]
		if components[a].script == "HoseConnectionController" and components[b].script != "HoseConnectionController":
			component_node(a).global_position = component_node(b).global_position
	aimed = find_target()
	update_objective_marker()
	prompt.text = aimed.get("title", "")
	if aimed.has("port"): prompt.text += "  [A Connect / Stick click Disconnect]" if control_mode == "vr" else "  [F Connect / C Disconnect]"
	elif aimed.get("kind", "") in ["valve", "hydrant"]: prompt.text += "  [Trigger Use]" if control_mode == "vr" else "  [R Use]"
	elif not aimed.is_empty(): prompt.text += "  [Grip Pick up]" if control_mode == "vr" else "  [E Pick up]"
	var pressure: float = network.nozzle_pressure(nozzle_id) if not nozzle_id.is_empty() else 0.0
	spraying = is_instance_valid(grabbed) and grabbed == component_node(nozzle_id) and (player.trigger_down() if control_mode == "vr" else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and pressure > 0.5
	spray.emitting = spraying
	if spraying:
		if not water_audio.playing: water_audio.play()
		apply_water(delta)
	else: water_audio.stop()
	var burning := 0
	for fire in fires.values():
		fire.tick(delta)
		if fire.burning: burning += 1
	if burning == 0 and not completed:
		completed = true
		fire_audio.stop()
		progress = tutorial[level].size() - 1
		update_task()
		message("All fires extinguished. " + ("B opens the menu." if control_mode == "vr" else "Esc opens the menu."))
	status_text.text = "Nozzle: %.2f bar\nActive fires: %d  ·  %02d:%02d" % [pressure, burning, int(elapsed)/60, int(elapsed)%60]
	for hose in hoses: draw_hose(hose)

func update_objective_marker() -> void:
	var target: Node3D
	for c in components.values():
		if c.get("script", "") == "TutorialConnectionControler" and int(c.data.tutorialNumber) == progress:
			target = nodes.get(rid(c.data.m_GameObject))
			break
	if level == "city" and progress in [0, 2]:
		for go in data.objects:
			if data.objects[go].name == "PylonSpawner": target = nodes.get(go)
	if progress == tutorial[level].size() - 2:
		for patch in fires.values():
			if patch.burning: target = patch; break
	objective_marker.visible = is_instance_valid(target)
	if not is_instance_valid(target): return
	var camera: Camera3D = player.camera
	var point := target.global_position + Vector3.UP * 0.5
	var screen := camera.unproject_position(point)
	if camera.is_position_behind(point): screen.x = 40.0 if (point-camera.global_position).dot(camera.global_basis.x) < 0 else 1240.0
	objective_marker.position = Vector2(clampf(screen.x - 120.0, 15.0, 1025.0), clampf(screen.y, 160.0, 535.0))
	objective_marker.text = "▼  %.1f m" % camera.global_position.distance_to(point)

func apply_water(delta: float) -> void:
	var ray := aim_transform()
	var origin: Vector3 = ray.origin
	var direction: Vector3 = -ray.basis.z
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * 18.0, 1))
	var max_distance := 18.0 if hit.is_empty() else origin.distance_to(hit.position) + 0.6
	for fire in fires.values():
		var offset: Vector3 = fire.global_position + Vector3.UP - origin
		var along := offset.dot(direction)
		if along > 0 and along < max_distance and (offset - direction * along).length() < 1.3:
			# Desktop stream samples replace Unity particle collision event counts.
			fire.extinguish(2400.0 * delta)

func draw_hose(hose: Dictionary) -> void:
	var mesh: ImmediateMesh = hose.mesh.mesh
	mesh.clear_surfaces()
	var a: Vector3 = hose.a.global_position
	var b: Vector3 = hose.b.global_position
	if a.distance_to(b) < 0.001: return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for i in range(13):
		var t := float(i) / 12.0
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * minf(0.35, a.distance_to(b) * 0.03)
		points.append(p)
	for i in range(12):
		var axis: Vector3 = (points[i + 1] - points[i]).normalized()
		var right := axis.cross(Vector3.UP).normalized()
		if right.length() < 0.1: right = Vector3.RIGHT
		var up := axis.cross(right).normalized()
		for j in range(6):
			var angle := TAU * j / 6.0
			var next := TAU * (j + 1) / 6.0
			var p: Vector3 = (right * cos(angle) + up * sin(angle)) * hose.radius
			var q: Vector3 = (right * cos(next) + up * sin(next)) * hose.radius
			for v in [points[i]+p, points[i+1]+p, points[i]+q, points[i]+q, points[i+1]+p, points[i+1]+q]: mesh.surface_add_vertex(v)
	mesh.surface_end()
