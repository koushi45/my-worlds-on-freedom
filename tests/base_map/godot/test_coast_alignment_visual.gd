extends SceneTree

const TARGET := Vector2(5232.4, 5471.5)
const ZOOMS := [0.5, 2.0, 2.01, 3.0, 4.0]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var requested := Vector2i(1920, 1080)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--resolution="):
			var parts := argument.trim_prefix("--resolution=").split("x")
			if parts.size() == 2:
				requested = Vector2i(int(parts[0]), int(parts[1]))
	root.size = requested
	DisplayServer.window_set_size(requested)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/coast_alignment"))
	root.get_node("GameSession").player_house = "oda_nobuhide"
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	while not main.initialized:
		await process_frame
	var resolution_index: int = root.get_node("DisplaySettings").RESOLUTIONS.find(requested)
	if resolution_index >= 0:
		root.get_node("DisplaySettings").apply_resolution(resolution_index, false)
	root.size = requested
	await process_frame
	main.game_clock.toggle_paused()
	for tilted in [false, true]:
		main.set_oblique(tilted)
		for zoom_value in ZOOMS:
			main.set_map_zoom(zoom_value)
			main.camera.position = main.elevation.project(TARGET)
			main._refresh_visible_tiles()
			await process_frame
			await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image.get_size() != requested:
				printerr("FAIL: requested ", requested, " but rendered ", image.get_size())
				quit(1)
				return
			var zoom_label := str(int(round(zoom_value * 100.0)))
			var filename := "tokyo_bay_%dx%d_%s_%spct.png" % [
				requested.x,
				requested.y,
				"tilt" if tilted else "flat",
				zoom_label,
			]
			var error := image.save_png(
				"res://builds/qa/coast_alignment/" + filename
			)
			if error != OK:
				printerr("FAIL: could not save " + filename)
				quit(1)
				return
	main.queue_free()
	await process_frame
	print("PASS: Tokyo Bay coast alignment captures at ", requested)
	quit(0)
