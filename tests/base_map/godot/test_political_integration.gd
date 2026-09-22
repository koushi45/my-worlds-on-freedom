extends SceneTree

func _initialize() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	assert(packed != null)
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	assert(main.initialized and main.political_layer.initialized)
	assert(main.political_layer.data["status"] == "approved")
	assert(main.political_layer.click_polygons.size() == 66)
	assert(main.political_layer.boundary_points.size() == 135)
	for region_id in main.political_layer.click_polygons:
		var found := false
		for polygon in main.political_layer.click_polygons[region_id]:
			var bounds := Rect2(polygon[0], Vector2.ZERO)
			for point_in_polygon in polygon: bounds = bounds.expand(point_in_polygon)
			for i in range(2500):
				var sample: Vector2 = bounds.position + bounds.size * Vector2((i % 50 + 0.5)/50.0, (floori(i/50.0)+0.5)/50.0)
				if main.political_layer.hit_test(sample) == region_id:
					main.select_country(sample)
					assert(main.selection_label.text.contains(main.political_layer.region_names[region_id]))
					assert(main.political_layer.selection_lines(region_id).size() > 0)
					found = true
					break
			if found: break
		assert(found, region_id)
	for region_id in ["shikoku", "chugoku", "honshu"]:
		main.focus_region(region_id)
		assert(main.political_layer.visible)
	assert(main.political_layer.data["regional_bounds"].has("chugoku"))
	assert(main.political_layer.hit_test(Vector2(2870,5550))=="mimasaka")
	main.focus_kyushu()
	await process_frame
	assert(main.political_layer.visible)
	var point := Vector2(1900,6500)
	# Exercise the actual mouse press/release path, not only direct selection.
	var screen: Vector2 = (main.elevation.project(point)-main.camera.position)*main.camera.zoom.x + root.get_visible_rect().size*0.5
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen
	event.pressed = true
	main._unhandled_input(event)
	event.pressed = false
	main._unhandled_input(event)
	assert(main.political_layer.selected_id == "bungo")
	assert(main.selection_label.text.contains("豊後国"))
	for level in range(5):
		main.lod_level = level
		main._apply_lod(true)
		main._refresh_visible_tiles()
		assert(main.political_layer.hit_test(point)=="bungo")
		assert(main.political_layer.selection_lines("bungo").size()>=3)
	main.camera.position = Vector2(8000,500)
	main.lod_level = 4
	main._apply_lod(true)
	main._refresh_visible_tiles()
	assert(not main.political_layer.visible)
	main.focus_kyushu()
	main.select_country(point)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa"))
		assert(root.get_texture().get_image().save_png("res://builds/qa/production_kyushu.png")==OK)
	print("PASS: approved registry, click selection, 5 LODs, coastline sharing and offscreen culling")
	quit(0)
