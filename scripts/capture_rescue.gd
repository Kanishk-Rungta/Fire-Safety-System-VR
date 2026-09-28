extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(path: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.select_control_mode("keyboard")
	game.start_level("city")
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(3.0, 0.2, -18.17)
	game.player.camera.look_at(Vector3(14.52, 2.3, -18.17))
	for fire in game.fires.values(): fire.extinguish(100000)
	await shot("res://.validation/house-entry.png")
	game.free()
	var apartment = load("res://interior/Scenes/Levels/Apartment.tscn").instantiate()
	root.add_child(apartment)
	apartment.get_node("Player").set_physics_process(false)
	await shot("res://.validation/indoor-entry.png")
	var player = apartment.get_node("Player")
	var victim = apartment.get_node("VictimNPC")
	player.global_position = victim.global_position + Vector3(0, 0, -2.6)
	player.camera.look_at(victim.global_position + Vector3(0, 0.6, 0))
	player._toggle_torch()
	await shot("res://.validation/victim.png")
	var gm = root.get_node("GameManager")
	var ms = root.get_node("MissionSystem")
	gm.elapsed = 184.5
	gm.outdoor_time = 117.3
	ms.current_step = ms.Step.COMPLETE
	gm.game_won()
	await shot("res://.validation/rescue-results.png")
	quit()
