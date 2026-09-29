extends SceneTree
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 30000
	while not main.initialized and Time.get_ticks_msec() < deadline:
		await process_frame
	check(main.initialized, "game initializes")
	if not main.initialized: quit(1); return
	main.game_clock.toggle_paused()
	var registry = main.governance_registry
	check(main.kamon_layer.kamon_by_house.size() == 151, "all controlling houses have a kamon mapping")
	check(main.kamon_layer.kamon_textures.size() >= 39, "sourced and neutral kamon SVGs load at runtime")
	check(registry.districts.size() == root.get_node("GameSession").catalog.district_ids.size(), "all districts remain available internally")
	check(registry.districts.values().all(func(r): return r.population is int and r.population >= 0), "all districts have non-negative initial population")
	check(registry.districts.values().all(func(r): return r.population == r.initial_population), "new game uses the 1546 population estimate")
	var population_total := 0
	for r in registry.districts.values(): population_total += r.population
	check(population_total == 11108276, "initial district populations conserve the adopted in-map total")
	var development_counts := {1:0, 2:0, 3:0, 4:0, 5:0}
	for r in registry.districts.values():
		check(r.agriculture_development == r.commerce_development, "initial agriculture and commerce use the same reference rank")
		check(r.agriculture_development >= 1 and r.agriculture_development <= 5, "initial development stays in the requested range")
		development_counts[r.agriculture_development] += 1
	check(development_counts == {1:522, 2:78, 3:33, 4:13, 5:7}, "80 percent of districts start at development 1")
	var population_ranked: Array = registry.districts.values()
	population_ranked.sort_custom(func(a,b): return a.population > b.population)
	check(population_ranked[0].agriculture_development == 5 and population_ranked[-1].agriculture_development == 1, "higher population/productive concentration receives the higher initial tier")
	var commerce_at_one := 0
	var agriculture_at_one := 0
	for r in registry.districts.values():
		var probe: Dictionary = r.duplicate(true)
		probe.agriculture_development = 1
		probe.commerce_development = 1
		commerce_at_one += main.district_economy.income_for(probe, "commerce")
		agriculture_at_one += main.district_economy.income_for(probe, "agriculture")
	check(absf(float(commerce_at_one) / registry.districts.size() - 5.0) < 0.05, "development 1 averages about 5 money per district")
	check(absf(float(agriculture_at_one) / registry.districts.size() - 50.0) < 0.05, "development 1 averages about 50 provisions per district")
	var growth_probe := {"agriculture_development":1, "commerce_development":1, "agriculture_progress":0.0, "commerce_progress":0.0, "agriculture_developer_id":null, "commerce_developer_id":null}
	var max_politics_id := ""
	for officer_id in main.officer_registry.lookup:
		if main.officer_registry.ability(officer_id, "politics") == 30: max_politics_id = officer_id; break
	check(not max_politics_id.is_empty(), "a politics 30 officer is available for calibration")
	growth_probe.agriculture_developer_id = max_politics_id
	growth_probe.commerce_developer_id = max_politics_id
	for month in 180:
		main.district_economy.develop(growth_probe, "agriculture")
		main.district_economy.develop(growth_probe, "commerce")
	check(growth_probe.agriculture_development == 30 and growth_probe.commerce_development == 30, "politics 30 reaches both maxima in 15 years")
	var resource_house: String = registry.districts.values()[0].house_id
	main.district_economy.on_day_advanced(1546, 8, 1)
	check(main.district_economy.house_resources[resource_house].money > 0, "commerce income is collected on a monthly first day")
	check(main.district_economy.house_resources.values().all(func(v): return v.provisions == 0), "agriculture is not collected outside September")
	main.district_economy.on_day_advanced(1546, 9, 1)
	check(main.district_economy.house_resources.values().any(func(v): return v.provisions > 0), "agriculture income is collected on September 1")
	check(registry.sites.size() == 257, "accepted and deferred sites remain available internally")
	check(main.get_node_or_null("GovernancePanel") == null, "governance information has no visible panel")
	check(not main.district_info.panel.visible,"district-name window starts hidden")
	check(registry.districts["iga/merged-dff55b62903ec44f"].house_id == "rokkaku","Iga Ueno district belongs to Rokkaku")
	check(registry.districts["ise/candidate-district-candidate-g07013"].house_id == "kitabatake","current Shima-area district belongs to Kitabatake")
	check(registry.sites["site_1582_shima_108"].house_id == "kitabatake","Toba in Shima belongs to Kitabatake")
	main.show_district_info("iga/merged-dff55b62903ec44f")
	check(main.district_info.panel.visible and main.district_info.name_label.text == "阿拝郡","district click window shows the district name")
	check(main.district_info.details_rows.get_child_count() == 6, "district details have three titled groups")
	check(main.district_info.details_rows.get_child(1).get_child_count() == 2, "house and governor share one grid")
	check(main.district_info.details_rows.get_child(3).get_child_count() == 2, "provisions and money share one grid")
	check(main.district_info.details_rows.get_child(5).get_child_count() == 6, "population and safety statistics share one grid")
	var district_record: Dictionary = registry.districts["iga/merged-dff55b62903ec44f"]
	var governor_row: HBoxContainer = main.district_info.details_rows.find_child("Info_governor", true, false).get_child(0)
	check(governor_row.get_child(1).text == registry.governor_name(district_record), "district window shows its governor once")
	check(main.district_info.crest_rect.custom_minimum_size == Vector2(64, 64), "crest uses a small fixed display size")
	var district_icon: TextureRect = main.district_info.details_rows.find_child("Info_house", true, false).get_child(0).get_child(0).get_child(0)
	check(district_icon.texture.get_size() == Vector2(main.district_info.info_icon_size, main.district_info.info_icon_size), "district icon uses a prepared size")
	check(is_equal_approx(district_icon.scale.x * main.district_info.icon_scale, 1.0), "district icon is drawn at physical 100 percent")
	var district_icon_target: Control = district_icon.get_parent()
	district_icon_target.mouse_entered.emit()
	check(main.district_info.icon_hint.visible and main.district_info.icon_hint.caption.text == "支配家", "district icon label appears immediately on hover")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa"))
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://builds/qa/district_icon_hint_window.png") == OK, "district icon label capture saved")
	district_icon_target.mouse_exited.emit()
	check(not main.district_info.icon_hint.visible, "district icon label closes on mouse exit")
	var income_value: Label = main.district_info.details_rows.find_child("Info_rice", true, false).get_child(0).get_child(1)
	income_value.mouse_entered.emit()
	check(main.district_info.icon_hint.visible and main.district_info.icon_hint.caption.text.begins_with("兵糧収入："), "income text label appears immediately on hover")
	income_value.mouse_exited.emit()
	main.district_info.icon_hint.touch_mode = true
	var icon_tap := InputEventScreenTouch.new()
	icon_tap.pressed = true
	district_icon_target.gui_input.emit(icon_tap)
	check(main.district_info.icon_hint.visible and main.district_info.icon_hint.caption.text == "支配家", "district icon tap shows its label")
	main.district_info.icon_hint.touch_mode = false
	main.district_info.icon_hint.clear()
	var hud_icon_target: Control = main.house_status_hud.metric_icons["money"].get_parent()
	hud_icon_target.mouse_entered.emit()
	check(main.house_status_hud.icon_hint.visible and main.house_status_hud.icon_hint.caption.text == "所持金銭", "top HUD icon label appears immediately on hover")
	hud_icon_target.mouse_exited.emit()
	check(not main.house_status_hud.icon_hint.visible, "top HUD icon label closes on mouse exit")
	var hud_value: Label = main.house_status_hud.values["money"]
	hud_value.mouse_entered.emit()
	check(main.house_status_hud.icon_hint.visible and main.house_status_hud.icon_hint.caption.text == "所持金銭", "top HUD value label appears immediately on hover")
	hud_value.mouse_exited.emit()
	if DisplayServer.get_name() != "headless":
		var previous_clipboard := DisplayServer.clipboard_get()
		main.district_info.name_label.pressed.emit()
		check(DisplayServer.clipboard_get() == "阿拝郡","clicking the district name copies it to the clipboard")
		check("コピーしました" in main.district_info.copy_status.text,"district-name window confirms the copy")
		DisplayServer.clipboard_set(previous_clipboard)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa"))
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://builds/qa/district_name_window.png") == OK,"district-name window capture saved")
	var previous_house: String = root.get_node("GameSession").player_house
	root.get_node("GameSession").player_house = "rokkaku"
	main.show_district_info("iga/merged-dff55b62903ec44f")
	governor_row = main.district_info.details_rows.find_child("Info_governor", true, false).get_child(0)
	check(governor_row.get_child(1) is Button, "own governor value opens appointment control")
	governor_row.get_child(1).mouse_entered.emit()
	check(main.district_info.icon_hint.visible and main.district_info.icon_hint.caption.text.begins_with("郡代："), "editable text button label appears immediately on hover")
	governor_row.get_child(1).mouse_exited.emit()
	var building_grid: GridContainer = main.district_info.facilities_rows.get_child(3)
	check(building_grid.get_child_count() == main.district_buildings.slot_capacity(district_record), "building slots use a grid")
	check(building_grid.get_child(0).get_child(0).get_child(0) is TextureButton, "own empty building slot is clickable")
	var upgrade_button: TextureButton = main.district_info.facilities_rows.get_child(1).get_child(2).get_child(0)
	var infrastructure_before: int = district_record.infrastructure
	main.district_info.icon_hint.touch_mode = true
	upgrade_button.pressed.emit()
	check(main.district_info.icon_hint.visible and main.district_info.icon_hint.caption.text.begins_with("インフラ上昇"), "first tap on an action icon shows its label")
	check(district_record.infrastructure == infrastructure_before, "first tap on an action icon does not execute the action")
	main.district_info.icon_hint.touch_mode = false
	main.district_info.icon_hint.clear()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://builds/qa/district_owned_window.png") == OK, "owned district window capture saved")
	var rokkaku_members: Array = main.retainer_management.house_members.rokkaku
	if not rokkaku_members.is_empty():
		check(main.retainer_management.assign_role("rokkaku", rokkaku_members[0], "侍大将") == OK, "appointable district officer prepared")
		main.district_info._open_governor_dialog()
		check(main.district_info.governor_choice.item_count > 0, "governor selection opens from value button")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://builds/qa/district_governor_dialog.png") == OK, "governor dialog capture saved")
		main.district_info.governor_dialog.hide()
	root.get_node("GameSession").player_house = previous_house
	main.select_country(Vector2(-1,-1))
	check(not main.district_info.panel.visible,"country or empty selection hides the district-name window")
	var ruler_matches: Array = registry.search("district", "織田信秀")
	check(not ruler_matches.is_empty(), "internal search by ruler")
	if not ruler_matches.is_empty():
		check("支配家：" in registry.describe(registry.districts[ruler_matches[0]]), "internal district description remains available")
	check("上杉謙信" in registry.describe(registry.sites["site_1582_echigo_094"]), "internal castellan data remains available")
	check("未築城" in registry.describe(registry.sites["azuchi_castle"]), "internal future-castle data remains available")
	check("堺会合衆" in registry.describe(registry.sites["sakai_town"]), "internal autonomous-town data remains available")
	# Exercise real site picking without opening a governance display.
	var site: Dictionary = main.settlement_layer.lookup["site_1582_echigo_094"]
	if DisplayServer.get_name() != "headless":
		main.set_map_zoom(2.0)
		main.camera.position = main.elevation.project(Vector2(site.point[0],site.point[1]))
		main._refresh_visible_tiles()
		await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
		await RenderingServer.frame_post_draw
		var screen: Vector2 = main.settlement_layer.get_global_transform_with_canvas() * main.elevation.project(Vector2(site.display_point[0],site.display_point[1]))
		var press := InputEventMouseButton.new()
		press.position = screen
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		main._unhandled_input(press)
		var release := press.duplicate() as InputEventMouseButton
		release.pressed = false
		main._unhandled_input(release)
		await process_frame
		check(main.settlement_layer.selected_id == site.id, "map click selects a site without opening a panel")
		check(not main.district_info.panel.visible,"site click keeps the district-name window hidden")
	var before: int = main.game_clock.elapsed_days
	await create_timer(0.2).timeout
	check(main.game_clock.elapsed_days == before, "internal inspection preserves paused clock")
	main.queue_free()
	await process_frame
	print("Governance data-only tests: %d failures" % failures)
	quit(1 if failures else 0)
