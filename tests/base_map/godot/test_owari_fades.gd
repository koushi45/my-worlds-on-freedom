extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("GameSession").player_house = "oda_nobuhide"
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	while not main.initialized: await process_frame
	main.game_clock.toggle_paused()
	var target: Vector2 = main.territory_borders.country_records.owari.anchor
	for tilted in [false,true]:
		main.set_oblique(tilted)
		for zoom_value in [1.5,3.0]:
			main.set_map_zoom(zoom_value)
			main.camera.position = main.elevation.project(target)
			main._refresh_visible_tiles()
			await process_frame
			await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://builds/qa/owari_fade_%s_%d.png" % ["tilt" if tilted else "flat",int(zoom_value*100)])
	main.queue_free()
	await process_frame
	print("Owari fade captures: PASS")
	quit()
