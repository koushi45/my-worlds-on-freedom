extends SceneTree
const Wait = preload("res://tests/base_map/godot/wait_map.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var deadline := Time.get_ticks_msec() + 45000
	while not main.initialized and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(main.initialized, "game map must finish initializing")
	main.game_clock.set_process(false)
	var surface: RefCounted = main.elevation
	var max_error := 0.0
	for y in range(0, 8193, 79):
		for x in range(0, 8193, 71):
			var point := Vector2(x, y)
			max_error = maxf(max_error, point.distance_to(surface.unproject(surface.project(point))))
	assert(max_error < 0.01, "displaced terrain picking must remain accurate")
	assert(float(surface.manifest.max_display_y_derivative) < 1.0, "terrain projection must remain invertible")
	main.camera.position = surface.project(Vector2(4332, 5094))
	main.set_map_zoom(4.0)
	main.camera.force_update_scroll()
	await Wait.settled(main)
	assert(not main.loaded_tiles.is_empty(), "terrain chunks must match the new height fingerprint")
	var checked := 0
	for tile in main.loaded_tiles.values():
		if not tile.has_method("set_view_zoom"): continue
		assert(tile.material.shader == main.TerrainReliefShader)
		assert(is_equal_approx(tile.material.get_shader_parameter("gutter_uv"), 1.0 / 258.0))
		var arrays: Array = tile.mesh.surface_get_arrays(0)
		var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var b: Array = tile.definition.global_viewport
		var origin := Vector2(b[0], b[1])
		for index in range(0, vertices.size(), 31):
			var source := origin + uv[index] * 258.0 - Vector2.ONE
			assert(surface.project(source).distance_to(vertices[index]) < 0.02, "baked terrain must follow the live picking surface")
		checked += 1
	assert(checked > 0)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/terrain-relief-mountains.png")
	main.developer_tools.open()
	main.developer_tools.set_contour_mode(true)
	assert(not surface.enabled and not main.tile_root.visible)
	main.developer_tools.close()
	assert(main.is_oblique() and main.tile_root.visible and not main.developer_tools.contour_mode)
	await Wait.settled(main)
	print("PASS: DEM relief materials, baked mesh alignment, inverse picking and contour restoration; error ", max_error)
	quit()
