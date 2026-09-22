extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr(message)

func frames() -> void:
	await process_frame
	await process_frame
	await preload("res://tests/base_map/godot/wait_map.gd").settled(root.get_child(root.get_child_count()-1))
	if "--capture" in OS.get_cmdline_user_args(): await RenderingServer.frame_post_draw

func _initialize() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.WORLD_SIZE == Vector2(8192,8192),"world coordinates unchanged")
	check(main.catalog.detail_tiles.size() == 211,"national detail coverage loaded")
	main.set_map_zoom(main.base_zoom*.8)
	check(is_equal_approx(main.camera.zoom.x,main.MIN_ZOOM),"map zoom never goes below 50 percent")
	main.focus_road_region("site:kishiwada_castle")
	var anchor := Vector2(760,370)
	for i in range(30): main._zoom_at(main.camera.zoom.x*1.3,anchor)
	check(is_equal_approx(main.camera.zoom.x,4),"wheel stops at 400 percent")
	var ground: Vector2 = main._screen_to_world(anchor)
	main._zoom_at(3,anchor)
	check(ground.distance_to(main._screen_to_world(anchor))<.01,"zoom preserves pointer ground position")
	main.set_map_zoom(999)
	check(is_equal_approx(main.camera.zoom.x,4),"central zoom cap")
	main._on_viewport_size_changed()
	check(is_equal_approx(main.camera.zoom.x,4),"resize retains capped zoom")
	for id in ["kishiwada_castle","tsutsui_castle"]:
		main.focus_road_region("site:"+id)
		check(main.camera.zoom.x<=4,"site focus cap")
	for route in main.connection_layer.data["routes"]:
		if route["id"] == "link_284":
			main.connection_panel.current_id=route["id"]
			main.connection_panel.focus_current()
			check(main.camera.zoom.x<=4,"short route focus cap")
	main.connection_layer.select_route("")
	main.connection_panel.current_id=""
	for oblique in [false,true]:
		main.set_oblique(oblique)
		main.road_focus_active=false
		main.set_map_zoom(4)
		main.camera.position=main.elevation.project(Vector2(3480,5840))
		await frames()
		check(main.loaded_tiles.size()>0 and main.loaded_tiles.size()<20,"only visible detail tiles resident")
		var expected: Array=main.catalog.get_detail_tiles(main.get_visible_world_rect().grow(2))
		check(main.loaded_tiles.size()==expected.size(),"visible-set matches loaded set")
		for id in main.loaded_tiles:
			check(id.begins_with("detail-"),"detail tile selected at 400 percent")
			check(main.loaded_tiles[id].relief.get_width()==1032,"4x terrain texture loaded")
		if "--capture" in OS.get_cmdline_user_args():
			root.get_texture().get_image().save_png("res://builds/detail_400_%s.png" % ("oblique" if oblique else "flat"))
			var saved: Array = main.catalog.detail_tiles
			main.catalog.detail_tiles = []
			main._clear_loaded_tiles()
			await frames()
			root.get_texture().get_image().save_png("res://builds/detail_before_400_%s.png" % ("oblique" if oblique else "flat"))
			main.catalog.detail_tiles = saved
			main._clear_loaded_tiles()
			await frames()
		main.set_relief_visible(false)
		await frames()
		check(not main.elevation.relief_visible,"relief toggle independent")
		if "--capture" in OS.get_cmdline_user_args(): root.get_texture().get_image().save_png("res://builds/detail_land_%s.png" % ("oblique" if oblique else "flat"))
		main.set_relief_visible(true)
		var loaded_before: Array=main.loaded_tiles.keys()
		main.camera.position=main.elevation.project(Vector2(4200,5500))
		await frames()
		check(main.loaded_tiles.keys()!=loaded_before,"panning replaces resident tiles")
		main.set_map_zoom(.5)
		await frames()
		for id in main.loaded_tiles: check(not id.begins_with("detail-"),"overview uses existing LOD textures")
	print("DETAIL ZOOM TEST: "+("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)
