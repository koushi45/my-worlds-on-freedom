extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func run() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized):
		await process_frame
	if not check(current_scene != null and current_scene.initialized, "map initialized"): return
	var main = current_scene
	var army = main.army_campaign
	var session = root.get_node("GameSession")
	main.game_clock.paused = true
	main.cpu_controller.enabled = false
	var own_district := ""
	var officer_id := ""
	for id in main.governance_registry.districts:
		var district: Dictionary = main.governance_registry.districts[id]
		if main.district_actions.sortie_available(district) < 400: continue
		session.player_house = district.house_id
		var officers: Array[String] = army.available_officers(id)
		if not officers.is_empty():
			own_district = id
			officer_id = officers[0]
			break
	if not check(not own_district.is_empty(), "available army district"): return
	var enemy_district := ""
	var enemy_country := ""
	for country_id in main.territory_borders.country_records:
		var id: String = main.territory_borders.country_records[country_id].representative_district
		if session.relation(session.player_house, main.governance_registry.districts[id].house_id) == "neutral":
			enemy_country = country_id
			enemy_district = id
			break
	if not check(not enemy_district.is_empty(), "neutral foreign office with a country marker"): return
	main.territory_borders.refresh_relations()
	main.district_economy.house_resources[session.player_house].provisions = 100000
	var unit_id: String = army.dispatch(own_district, [officer_id], 25, false, false)
	if not check(not unit_id.is_empty(), "army dispatched"): return
	var office_node := "district:" + enemy_district
	army.units[unit_id].site_id = office_node
	army.units[unit_id].soldiers = 1000
	army._arrive(unit_id)
	main.army_panel.show_unit(unit_id)
	main.camera.position = main.elevation.project(main.district_office_layer.office_point(enemy_district))
	main.set_map_zoom(2.0)
	var frame_start := Time.get_ticks_msec()
	army.on_day_advanced(1546, 1, 2)
	if not check(main.territory_borders.projected[enemy_district].state == "enemy", "attack updates relationship colours"): return
	if not check(main.territory_borders.country_records[enemy_country].state == "enemy", "attack updates country relationship colours"): return
	frame_start = Time.get_ticks_msec()
	await process_frame
	if not check(Time.get_ticks_msec() - frame_start < 2000, "attack does not rebuild all territory geometry on the next frame"): return
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	# Selected armies use the wheel for facing; deselection restores map zoom.
	wheel.position = Vector2(root.get_visible_rect().size.x - 100.0, root.get_visible_rect().size.y * 0.5)
	wheel.pressed = true
	var previous_facing: float = army.units[unit_id].facing
	root.push_input(wheel, true)
	if not check(float(army.units[unit_id].facing) != previous_facing, "mouse wheel rotates selected occupying army"): return
	main.army_panel.hide_panel()
	root.push_input(wheel, true)
	if not check(main.map_view.requested_zoom > 2.0, "mouse wheel requests zoom while foreign office is occupied"): return
	for index in 30: await process_frame
	var start_position: Vector2 = main.camera.position
	var start_heading: float = main.map_view.yaw
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.position = wheel.position
	middle.pressed = true
	root.push_input(middle, true)
	var motion := InputEventMouseMotion.new()
	motion.position = middle.position + Vector2(80, 0)
	motion.relative = Vector2(80, 0)
	root.push_input(motion, true)
	middle.position = motion.position
	middle.pressed = false
	root.push_input(middle, true)
	if not check(main.map_view.yaw != start_heading and main.camera.position == start_position, "middle drag rotates while foreign office is occupied"): return
	start_position = main.camera.position
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.position = Vector2(root.get_visible_rect().size.x - 100.0, root.get_visible_rect().size.y * 0.5)
	left.pressed = true
	root.push_input(left, true)
	motion.position = left.position + Vector2(80, 0)
	motion.relative = Vector2(80, 0)
	root.push_input(motion, true)
	left.position = motion.position
	left.pressed = false
	root.push_input(left, true)
	if not check(main.camera.position.x < start_position.x - 20.0, "left drag elsewhere pans during occupation"): return
	army.occupations[enemy_district].progress = 99.9
	frame_start = Time.get_ticks_msec()
	army.on_day_advanced(1546, 1, 3)
	if not check(Time.get_ticks_msec() - frame_start < 2000, "capture updates only affected territory bands"): return
	if not check(main.governance_registry.districts[enemy_district].house_id == session.player_house, "occupation captures the office"): return
	if not check(main.territory_borders.projected[enemy_district].house_id == session.player_house, "capture updates district territory owner"): return
	if not check(main.territory_borders.country_records[enemy_country].house_id == session.player_house, "capture updates country marker owner"): return
	if not check(main.territory_borders.loaded_fade_regions == main.district_layer.records.size() - main.territory_borders.coastline_only_ids.size() + main.territory_borders.country_records.size(), "capture preserves audited fade coverage"): return
	frame_start = Time.get_ticks_msec()
	await process_frame
	if not check(Time.get_ticks_msec() - frame_start < 2000, "capture does not queue a full rebuild on the next frame"): return
	print("Office occupation input and frame update passed")
	quit(0)
