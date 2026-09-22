extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session = root.get_node("GameSession")
	var display = root.get_node("DisplaySettings")
	display.set_bgm_volume(0.4,false)
	display.set_sfx_volume(1.0,false)
	session.player_house = "uesugi_yamanouchi"
	session.relations.clear()
	var diplomacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.DIPLOMACY))
	for relation in diplomacy.relations:
		session.relations[session.pair(relation.a,relation.b)] = relation.status
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 45000
	while not main.initialized and Time.get_ticks_msec() < deadline:
		await process_frame
	check(main.initialized, "map initializes")
	if not main.initialized: quit(1); return
	check(main.bgm_player != null and main.bgm_player.playing,"main map BGM is playing")
	check(main.bgm_tracks.size() == 2 and main.bgm_track_index == 0,"main map starts the two-track playlist with Eight Mountains")
	var first_bgm: AudioStream = main.bgm_player.stream
	main.bgm_player.finished.emit()
	check(main.bgm_track_index == 1 and main.bgm_player.stream != first_bgm and main.bgm_player.playing,"BGM advances to Rise Again and keeps playing")
	main.bgm_player.finished.emit()
	check(main.bgm_track_index == 0 and main.bgm_player.stream == first_bgm and main.bgm_player.playing,"BGM alternates back to Eight Mountains")
	check(is_equal_approx(main.bgm_player.volume_linear,0.4),"main map BGM defaults to 40 percent")
	display.set_bgm_volume(0.2,false)
	check(is_equal_approx(main.bgm_player.volume_linear,0.2),"BGM option updates the active player")
	display.set_bgm_volume(0.4,false)
	main.game_clock.toggle_paused()
	check(is_equal_approx(main.camera.zoom.x,0.5), "new games start at 50 percent")
	check(main.territory_borders.country_records.size() == 66, "all countries receive a representative district")
	var expected_fade_regions: int = main.district_layer.records.size()-main.territory_borders.coastline_only_ids.size()+main.territory_borders.country_records.size()
	check(main.territory_borders.loaded_fade_regions == expected_fade_regions, "all current districts and countries load their audited interior fade meshes")
	for country_id in main.territory_borders.country_records:
		var country: Dictionary = main.territory_borders.country_records[country_id]
		check(main.district_layer.records[country.representative_district].parent == country_id,"representative district belongs to its country: "+country_id)
		check(main.political_layer.click_polygons[country_id].any(func(ring): return Geometry2D.is_point_in_polygon(country.anchor,ring)),"country crest anchor is inside country: "+country_id)
	await process_frame
	check(main.territory_borders.country_mode and main.political_layer.visible and not main.district_layer.boundaries_enabled,"country borders are used through 200 percent")
	check(main.kamon_layer.drawn_keys.any(func(key): return str(key).begins_with("country:")),"country crests draw at country zoom")
	var player_district_key := ""
	var nearest_player_distance := INF
	for key in main.governance_registry.districts:
		var district: Dictionary = main.governance_registry.districts[key]
		if district.get("house_id", "") != session.player_house:
			continue
		var district_position: Vector2 = main.elevation.project(Vector2(district.point[0],district.point[1]))
		var distance: float = district_position.distance_squared_to(main.camera.position)
		if distance < nearest_player_distance:
			nearest_player_distance = distance
			player_district_key = key
	check(not player_district_key.is_empty(), "on-screen player district found")
	var player_country: String = main.district_layer.records[player_district_key].parent
	main.political_layer.selected_id = player_country
	await create_timer(0.3).timeout
	var country_low_alpha: float = main.territory_borders.selection_pulse_alpha
	check(country_low_alpha > 0.0,"selected country theme fill fades in")
	await create_timer(0.9).timeout
	var country_high_alpha: float = main.territory_borders.selection_pulse_alpha
	check(country_high_alpha > country_low_alpha,"selected country theme fill grows gradually")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/country_selection_pulse.png")
	await create_timer(1.2).timeout
	check(main.territory_borders.selection_pulse_alpha < country_high_alpha,"selected country theme fill returns to transparent")
	main.political_layer.selected_id = ""
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa"))
		root.get_texture().get_image().save_png("res://builds/qa/country_borders_inward.png")
	main.set_map_zoom(2.0)
	main._refresh_visible_tiles()
	await process_frame
	check(main.territory_borders.country_mode and main.political_layer.visible,"exactly 200 percent remains in country mode")
	main.set_map_zoom(2.01)
	main._refresh_visible_tiles()
	await process_frame
	check(not main.territory_borders.country_mode and not main.political_layer.visible,"district mode begins above 200 percent")
	var target_record: Dictionary = main.governance_registry.districts[player_district_key]
	var target := Vector2(target_record.point[0],target_record.point[1])
	check(target != Vector2.ZERO, "player district found")
	main.set_map_zoom(2.2)
	main.camera.position = main.elevation.project(target)
	main._refresh_visible_tiles()
	await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
	await process_frame
	await RenderingServer.frame_post_draw
	check(not main.territory_borders.country_mode and not main.political_layer.visible and main.district_layer.boundaries_enabled,"district borders replace country borders above 200 percent")
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("res://builds/qa/district_borders_inward.png")
	check(main.kamon_layer != main.district_layer, "kamon markers use a dedicated map layer")
	check(main.kamon_layer.label_count > 0, "kamon markers draw in the detailed view")
	check(main.kamon_layer.z_index > main.settlement_layer.z_index, "kamon layer has priority over settlement names")
	check(main.territory_borders.independent_fill_files.size() == main.district_layer.records.size(), "all current district fill meshes are registered")
	var smallest := ""
	var largest := ""
	for key in main.district_layer.independent_geometry.regions:
		if smallest.is_empty() or main.district_layer.independent_geometry.regions[key].map_area < main.district_layer.independent_geometry.regions[smallest].map_area: smallest = key
		if largest.is_empty() or main.district_layer.independent_geometry.regions[key].map_area > main.district_layer.independent_geometry.regions[largest].map_area: largest = key
	check(main.kamon_layer.kamon_screen_size(smallest) < main.kamon_layer.kamon_screen_size(largest), "kamon size follows district area")
	check(main.kamon_layer.kamon_screen_size(smallest) >= 24.0, "smallest district kamon is at least 24 by 24 screen pixels")
	var takeda_background: Color = main.kamon_layer.kamon_background_color("takeda")
	check(Color(takeda_background,1.0).is_equal_approx(Color("#cf3632")) and is_equal_approx(takeda_background.a,0.92), "kamon background uses the house theme colour")
	check(main.territory_borders.draw_counts.self > 0, "player border draws")
	check(main.territory_borders.draw_counts.neutral > 0, "other border draws")
	main.district_layer.select_key(player_district_key)
	await create_timer(1.2).timeout
	check(main.territory_borders.selection_pulse_alpha > 0.0,"selected district theme fill pulses")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/district_selection_pulse.png")
	main.district_layer.select_key("")
	check(main.territory_borders.band_nodes.size() > 0, "ownership colours draw as inward bands")
	check(main.territory_borders.theme_colors.size() == 189, "every house has a theme colour")
	check(main.territory_borders.theme_color("takeda").is_equal_approx(Color("#cf3632")), "Takeda theme is red")
	check(main.territory_borders.band_styles.size() > 20, "house colours use a broad runtime palette")
	check(main.territory_borders.projected.values().any(func(record): return record.state == "ally"), "alliance border class exists")
	check(main.territory_borders.projected.values().any(func(record): return record.state == "enemy"), "enemy border class exists")
	check(not main.territory_borders.fill_enabled, "territory fill defaults off")
	main.game_menu.territory_fill_toggle.button_pressed = true
	await process_frame
	await RenderingServer.frame_post_draw
	check(main.territory_borders.fill_enabled, "bottom-right option enables territory fill")
	check(main.territory_borders.fill_mesh_for(smallest) != null, "current district fill mesh loads")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa"))
	check(root.get_texture().get_image().save_png("res://builds/qa/kamon_territory_fill.png") == OK, "capture saved")
	main.set_map_zoom(0.5)
	main._refresh_visible_tiles()
	await process_frame
	await RenderingServer.frame_post_draw
	check(main.kamon_layer.label_count > 0, "kamon markers also draw below the old zoom threshold")
	check(root.get_texture().get_image().save_png("res://builds/qa/kamon_territory_fill_overview.png") == OK, "overview capture saved")
	main.queue_free()
	await process_frame
	print("Kamon rendering tests: %d failures" % failures)
	quit(1 if failures else 0)
