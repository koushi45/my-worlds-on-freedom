extends SceneTree
var failures := 0

func check(ok: bool, message: String = "check failed") -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func ready_tile(main: Node2D, tile_id: String, expected_path: String, expected_size: int) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if main.loaded_tiles.has(tile_id):
			var tile: Node2D = main.loaded_tiles[tile_id]
			if str(tile.get_meta("path")) == expected_path and tile.relief.get_width() == expected_size:
				return true
		await process_frame
	return false

func run() -> void:
	var session = root.get_node("GameSession")
	session.save_directory = "res://builds/qa/high_zoom_save_%d" % OS.get_process_id()
	check(session.new_game("uesugi_yamanouchi") == OK)
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized):
		await process_frame
	if current_scene == null or not current_scene.initialized:
		printerr("FAIL: map did not initialize")
		quit(1)
		return
	var main = current_scene
	main.set_process_unhandled_input(false)
	main.set_process_input(false)
	root.gui_disable_input = true
	main.game_clock.set_process(false)
	main.camera.position = main.elevation.project(Vector2(4480, 5504))
	var tile_id := "detail-r21-c17"
	var definition: Dictionary = main.catalog.detail_tiles.filter(func(t): return t["tile_id"] == tile_id)[0]
	for oblique in [false, true]:
		main.set_oblique(oblique)
		main.camera.position = main.elevation.project(Vector2(4480, 5504))
		for state in [[2.49, 1032], [2.5, 1548], [3.99, 1548], [4.0, 2064], [6.0, 2064], [8.0, 2064], [3.99, 1548], [2.49, 1032]]:
			main.set_map_zoom(state[0])
			main.camera.force_update_scroll()
			var path: String = main._tile_path(definition)
			if not await ready_tile(main, tile_id, path, state[1]):
				printerr("FAIL: terrain texture did not switch at zoom ", state[0], " to ", path)
				quit(1)
				return
			if "--capture" in OS.get_cmdline_user_args() and state[0] in [4.0, 6.0, 8.0]:
				var settle_deadline := Time.get_ticks_msec()+20000
				while main.has_pending_map_work() and Time.get_ticks_msec()<settle_deadline: await process_frame
				check(not main.has_pending_map_work(),"high detail streaming timed out")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://builds/qa/high_zoom_%d_%s.png" % [int(state[0]*100),"tilt" if oblique else "flat"])
	for percent in [600, 800]:
		main._zoom_at(percent/100.0,main.get_viewport_rect().size*0.5)
		for frame in 60: await process_frame
		check(is_equal_approx(main.camera.zoom.x,percent/100.0))
	check(session.save_game(main,1) == OK,session.last_error)
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty(),session.last_error)
	check(is_equal_approx(float(saved.camera.zoom),8.0))
	main.set_map_zoom(0.5)
	session.pending = saved
	session.apply_to(main)
	check(is_equal_approx(main.camera.zoom.x,8.0))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.path_for(1)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.save_directory))
	print("Close/high terrain switching and 600/800 percent selection: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
