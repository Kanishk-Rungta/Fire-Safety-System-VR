extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.select_control_mode("keyboard")
	game.start_level("city")
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(-3, 3.6, 8)
	game.player.camera.look_at(Vector3(-19, 0.7, 0))
	game.hud.hide()
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("../recovery/road-closure-preview.png")
	game.show_menu()
	await process_frame
	game.free()
	quit()
