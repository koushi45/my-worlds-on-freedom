extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/base_map/independent_crossings.json"))
	root.get_node("GameSession").player_house = "hongo"
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec()+45000
	while not main.initialized and Time.get_ticks_msec()<deadline: await process_frame
	check(main.initialized,"map initialized")
	if not main.initialized: quit(1); return
	main.game_clock.toggle_paused()
	main.set_map_zoom(2.2)
	main._refresh_visible_tiles()
	check(main.territory_borders.z_index-1>main.political_layer.z_index,"district lines above country lines")
	check(main.district_layer.compiled_parents.is_empty() and main.district_layer.batch_nodes.is_empty(),"clipped legacy batches disabled")
	for fixture in fixtures:
		var p := Vector2(fixture.point[0],fixture.point[1])
		var found: Array = await main.district_layer.pick_async(p)
		check(fixture.key in found,"cross-country district is selectable: "+fixture.key)
	var example: Dictionary = fixtures[1]
	for tilted in [false,true]:
		main.set_oblique(tilted)
		main.camera.position = main.elevation.project(Vector2(example.point[0],example.point[1]))
		main.set_map_zoom(1.8)
		main._refresh_visible_tiles()
		main.district_layer.select_key(example.key)
		if DisplayServer.get_name() != "headless":
			await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://builds/qa/independent_district_%s.png" % ("tilt" if tilted else "flat"))
		check(main.district_layer.contains_point(example.key,Vector2(example.point[0],example.point[1])),"picking remains independent of projection")
	main.queue_free()
	await process_frame
	print("Independent district tests: %d failures" % failures)
	quit(1 if failures else 0)
