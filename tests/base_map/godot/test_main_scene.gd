extends SceneTree


func fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)


func _initialize() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	if packed == null:
		fail("main scene could not be loaded")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
	if not main.initialized:
		fail("main map runtime did not initialize")
		return
	if main.get_loaded_tile_count() < 1:
		fail("main map runtime did not load a visible map tile")
		return
	if main.get_lod_level() != 0:
		fail("main map runtime must start at national LOD")
		return
	var view_rect: Rect2 = main.get_visible_world_rect()
	if not view_rect.has_point(Vector2(4096.0, 4096.0)):
		fail("initial camera is not centered on the map")
		return
	main._set_lod(4, Vector2(640.0, 360.0))
	await process_frame
	await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
	if main.get_lod_level() != 4 or main.get_loaded_tile_count() < 1 or main.get_loaded_tile_count() > 4:
		fail("detailed LOD did not load only the visible local tiles")
		return
	for tile_node in main.loaded_tiles.values():
		if not str(tile_node.name).begins_with("detail-"):
			fail("a tile from the previous LOD remained active: "+str(tile_node.name)+" zoom="+str(main.camera.zoom))
			return
	main._set_lod(0, Vector2(640.0, 360.0))
	await process_frame
	await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa"))
		var viewport_texture := root.get_texture()
		if viewport_texture == null:
			fail("main scene viewport texture is unavailable")
			return
		var capture := viewport_texture.get_image()
		if capture == null or capture.is_empty() or capture.save_png("res://builds/qa/main_scene.png") != OK:
			fail("main scene screenshot could not be saved")
			return
	print("Godot main scene rendering contract passed")
	quit(0)
