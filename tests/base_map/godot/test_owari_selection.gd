extends SceneTree

var failures := 0

func capture(name: String) -> void:
	var project_dir := ProjectSettings.globalize_path(get_script().resource_path).get_base_dir().path_join("../../..").simplify_path()
	var output_dir := project_dir.path_join("builds/qa")
	DirAccess.make_dir_recursive_absolute(output_dir)
	if root.get_texture().get_image().save_png(output_dir.path_join(name + ".png")) != OK:
		failures += 1
		printerr("FAIL: screenshot " + name)

func settled(main: Node) -> void:
	await process_frame
	var deadline := Time.get_ticks_msec() + 15000
	while main.has_pending_map_work() and Time.get_ticks_msec() < deadline: await process_frame
	if main.has_pending_map_work():
		failures += 1
		printerr("FAIL: map streaming timed out")
	await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("GameSession").player_house = "oda_nobuhide"
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 45000
	while not main.initialized and Time.get_ticks_msec() < deadline: await process_frame
	if not main.initialized: quit(1); return
	main.game_clock.toggle_paused()
	main.set_oblique(false)
	main.set_map_zoom(4.0)
	for id in main.district_layer.records:
		if not str(id).begins_with("owari/"): continue
		var region: Dictionary = main.district_layer.records[id]
		var point := Vector2(region.label[0], region.label[1])
		main.camera.position = point
		main._refresh_visible_tiles()
		var picked: Array = await main.district_layer.pick_async(point)
		main.district_layer.select_key(id)
		var mesh: ArrayMesh = main.territory_borders.fill_mesh_for(id)
		if picked != [id] or mesh == null:
			failures += 1
			printerr("FAIL: selection %s picked=%s mesh=%s" % [id, picked, mesh])
		await settled(main)
		main.territory_borders.selection_pulse_phase = 0.5
		main.territory_borders.selection_pulse_alpha = main.territory_borders.SELECTION_PULSE_ALPHA
		main.territory_borders.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if DisplayServer.get_name() != "headless":
			capture("owari_selection_%s" % str(id).get_file())
		print("OWARI SELECTION: ", region.name, " ", id)
	# Exercise the real office-click path, including country/district zoom limits
	# and render-target density independent of the logical map zoom.
	var target_id := "owari/candidate-district-candidate-g09001"
	var office: Vector2 = main.district_office_layer.office_point(target_id)
	for zoom in [2.0, 2.2, 4.0]:
		for density in [0.5, 1.0, 1.5]:
			main.map_view.set_meta("probe_atlas_scale", density)
			main.camera.position = office
			main.set_map_zoom(zoom)
			main.map_view.sync(true)
			main._refresh_visible_tiles()
			await settled(main)
			if main.territory_borders.country_mode != (zoom <= 2.0):
				failures += 1
				printerr("FAIL: border mode depends on atlas density zoom=%s density=%s" % [zoom, density])
			main.district_layer.select_key("")
			main.political_layer.selected_id = "owari"
			var screen: Vector2 = main.map_view.project(office)
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = screen
			main._unhandled_input(press)
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.position = screen
			main._unhandled_input(release)
			await process_frame
			if main.district_layer.selected_key != target_id or not main.political_layer.selected_id.is_empty() or main.territory_borders.last_selected != "district:" + target_id:
				failures += 1
				printerr("FAIL: office click did not select district fill zoom=%s density=%s selected=%s pulse=%s" % [zoom, density, main.district_layer.selected_key, main.territory_borders.last_selected])
			if zoom == 4.0 and density == 1.0 and DisplayServer.get_name() != "headless":
				main.territory_borders.selection_pulse_phase = 0.5
				main.territory_borders.selection_pulse_alpha = main.territory_borders.SELECTION_PULSE_ALPHA
				main.territory_borders.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				capture("owari_office_selection_fixed")
	main.show_district_info("")
	await process_frame
	if not main.district_layer.selected_key.is_empty() or main.district_info.panel.visible or not main.territory_borders.last_selected.is_empty():
		failures += 1
		printerr("FAIL: clearing district information must clear its fill")
	main.queue_free()
	await process_frame
	print("Owari selection tests: %d failures" % failures)
	quit(1 if failures else 0)
