extends SceneTree
var failures := 0
var session: Node

func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: "+message)

func _initialize() -> void: call_deferred("run")

func wait_map() -> Node:
	var deadline := Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.name == "Main" and current_scene.initialized: return current_scene
	check(false,"map initialized before timeout")
	return null

func escape() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	root.push_input(e)

func capture_png(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/qa/"+name+".png")

func run() -> void:
	session = root.get_node("GameSession")
	session.save_directory = "user://qa_session_%d" % OS.get_process_id()
	change_scene_to_file("res://scenes/start/start.tscn")
	await process_frame
	await process_frame
	check(current_scene.name == "StartScreen","title appears first")
	check(not ResourceLoader.has_cached("res://scenes/main/main.tscn"),"title does not preload map scene")
	check(not ResourceLoader.has_cached("res://assets/map/elevation/mesh_height.png"),"title does not load elevation texture")
	await capture_png("start_title")
	current_scene.show_houses()
	var index: int = current_scene.house_ids.find("uesugi_yamanouchi")
	check(index>=0,"playable house offered")
	current_scene.house_list.select(index)
	current_scene.house_list.ensure_current_is_visible()
	current_scene.select_house(index)
	await capture_png("start_house_picker")
	current_scene.begin()
	var main = await wait_map()
	if main == null: quit(1); return
	check(session.player_house == "uesugi_yamanouchi","chosen house starts")
	check(main.army_campaign.units.is_empty(), "new game begins without deployed load-test armies")
	check(int(main.district_economy.house_resources[session.player_house].provisions) > 0,"chosen house starts with provisions for a sortie")
	check(session.relation(session.player_house,"uesugi_ogigayatsu")=="ally","alliance lookup")
	check(session.relation("hojo",session.player_house)=="enemy","symmetric enemy lookup")
	var player_district := ""
	for district_id in main.governance_registry.districts:
		if main.governance_registry.districts[district_id].house_id == session.player_house: player_district = district_id; break
	main.show_district_info(player_district)
	check(main.district_info.security_label.text == "治安：50 / 100","owned district begins at security 50")
	check(session.relation(session.player_house,"takeda")=="neutral","unknown diplomacy remains neutral")
	check(main.game_menu.find_child("MapZoomChoices", true, false) == null,"zoom selector is removed")
	check(main.game_menu.get("zoom_label") == null and main.game_menu.get("display_options") == null,"bottom map controls are removed")
	check(main.hex_tile_layer.get("terrain_legend") == null,"terrain legend is removed")
	# This suite isolates calendar/menu persistence; CPU wars have their own scenario suite.
	main.cpu_controller.enabled = false
	var states := {}
	for r in main.territory_borders.projected.values(): states[r.state]=true
	check(states.has("self") and states.has("ally") and states.has("enemy"),"three outline classes constructed")
	main.game_clock.set_process(false)
	main.cpu_controller.work_queue.clear()
	main.game_clock.restore_state({"year":1546,"month":1,"day":1,"elapsed_days":0,"speed":1,"paused":false,"fraction":0.0,"work_started":false,"backlog":0.0})
	await advance_days(main.game_clock, 59)
	main.game_clock.advance_real_seconds(0.375)
	main.game_clock.set_speed(4)
	main.game_clock.toggle_paused()
	main.camera.position = Vector2(5000,4800)
	main.set_map_zoom(0.7)
	await process_frame
	main._refresh_visible_tiles()
	if DisplayServer.get_name() != "headless": await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
	await capture_png("start_territory_borders")
	escape()
	check(not main.district_info.panel.visible and not main.game_menu.shade.visible,"Esc closes district window before opening game menu")
	escape()
	check(paused and main.game_menu.shade.visible,"Esc opens modal and pauses tree")
	var days: int = main.game_clock.elapsed_days
	await create_timer(0.2,true).timeout
	check(main.game_clock.elapsed_days == days,"menu freezes time")
	await capture_png("start_game_menu")
	main.game_menu.show_options()
	await process_frame
	check(is_instance_valid(main.game_menu.options) and main.game_menu.options.resolution_selector.item_count == 4,"in-game options expose window sizes")
	escape()
	await process_frame
	check(main.game_menu.modal.visible and paused,"Esc returns from display options to game menu")
	main.game_menu.show_retainers()
	await process_frame
	check(main.game_menu.retainer_panel.visible and main.game_menu.retainer_panel.role_buttons.size() == 5,"role cards open from game menu")
	check(main.game_menu.retainer_panel.overview_values.prestige.text == "50.0 / 100","initial prestige appears beside its icon")
	var retainer_ids: Array = main.retainer_management.house_members[session.player_house]
	check(main.game_menu.retainer_panel.officer_buttons.size() == retainer_ids.size(),"retainer portraits and scores appear in the selection list")
	if not retainer_ids.is_empty():
		main.game_menu.retainer_panel.role_buttons["侍大将"].pressed.emit()
		main.game_menu.retainer_panel.officer_buttons[retainer_ids[0]].pressed.emit()
		check(main.game_menu.retainer_panel.selected_role == "侍大将" and main.game_menu.retainer_panel.selected_officer_id == retainer_ids[0],"role is selected above the officer list")
		main.game_menu.retainer_panel._appoint()
		check(main.retainer_management.role_of(session.player_house, retainer_ids[0]) == "侍大将","roster appointment updates state")
		main.game_menu.retainer_panel.wage_input.value = 0.2
		main.game_menu.retainer_panel._set_wage()
		check(main.retainer_management.loyalty_state[retainer_ids[0]].base_wage_tenths == 2,"roster wage control updates base stipend")
	escape()
	await process_frame
	check(not main.game_menu.retainer_panel.visible and not paused,"Esc closes the current council and resumes the map")
	main.game_menu.show_technology()
	await process_frame
	check(main.game_menu.technology_panel.visible and main.game_menu.technology_panel.technology_buttons.size() == 7,"technology tree opens with governance cards")
	check(main.game_menu.technology_panel.technology_buttons["分国法"].disabled and main.game_menu.technology_panel.technology_buttons["官僚機構制定"].disabled,"unavailable research cards cannot be clicked")
	main.game_menu.technology_panel.technology_buttons["官僚機構制定"].pressed.emit()
	check(not main.technology_tree.completed(session.player_house, "官僚機構制定"),"disabled research does nothing even if pressed programmatically")
	main.game_menu.technology_panel.branch_buttons["agriculture"].pressed.emit()
	check(main.game_menu.technology_panel.technology_buttons.size() == 9,"agriculture icon tab opens its research cards")
	main.game_menu.technology_panel.branch_buttons["commerce"].pressed.emit()
	check(main.game_menu.technology_panel.technology_buttons.size() == 8,"commerce icon tab shows eight research cards")
	main.game_menu.technology_panel.branch_buttons["governance"].pressed.emit()
	main.retainer_management.technology[session.player_house].governance = 1000.0
	main.game_menu.technology_panel.refresh()
	check(not main.game_menu.technology_panel.technology_buttons["分国法"].disabled,"affordable next research becomes clickable")
	main.game_menu.technology_panel.technology_buttons["分国法"].pressed.emit()
	check(main.technology_tree.completed(session.player_house, "分国法"),"technology research works from the menu")
	main.show_district_info(player_district)
	check(main.district_info.security_label.text == "治安：55 / 100","law research updates displayed security")
	escape()
	await process_frame
	check(main.house_prestige.on_court_appointment(session.player_house) == OK,"court appointment event accepted")
	main.house_status_hud._refresh()
	check(main.house_status_hud.values.prestige.text == "%.1f" % main.house_prestige.value_for(session.player_house) and main.house_prestige.baseline_for(session.player_house) >= 60.0,"court award raises baseline and HUD shows fractional prestige")
	main.house_status_hud.icon_hint.touch_mode = true
	var prestige_touch := InputEventScreenTouch.new()
	prestige_touch.pressed = true
	main.house_status_hud.metric_cells.prestige.gui_input.emit(prestige_touch)
	check(main.house_status_hud.icon_hint.caption.text == main.house_prestige.description_for(session.player_house), "prestige icon displays the current baseline and its sources")
	await capture_png("prestige_baseline_hint")
	main.house_status_hud.icon_hint.clear()
	main.house_status_hud.icon_hint.touch_mode = false
	# Mutate real session state so a loader that merely reloads defaults cannot pass.
	var changed_id: String = main.governance_registry.districts.keys()[0]
	var hojo_record: Dictionary
	for r in main.governance_registry.districts.values():
		if r.house_id == "hojo": hojo_record = r; break
	for field in ["house_id","governor","ruler"]: main.governance_registry.districts[changed_id][field] = hojo_record[field]
	session.relations[session.pair("oda_nobuhide","takeda")] = "enemy"
	var capture_probe: Dictionary = session.capture(main)
	check(session.validate(capture_probe),"captured current session validates before saving")
	var roundtrip_probe: Dictionary = JSON.parse_string(JSON.stringify(capture_probe))
	check(session.validate(roundtrip_probe),"serialized current session validates")
	main.game_menu.toggle()
	main.game_menu.show_slots(true)
	main.game_menu.slots.choose(1)
	check("保存しました" in main.game_menu.slots.status.text,"save slot UI succeeds")
	await capture_png("start_save_slots")
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty(),"saved payload validates")
	if saved.is_empty(): printerr(session.last_error); quit(1); return
	check(saved.clock.day == 1 and saved.clock.month == 3,"calendar crosses February")
	check(saved.version == 30 and saved.has("technology_orders") and saved.has("cpu") and saved.diplomacy.has("wars") and saved.diplomacy.has("spy_networks") and saved.has("buildings") and saved.has("building_history") and saved.has("armies") and saved.armies.has("occupations") and saved.retainers.has("officer_districts") and saved.territories.districts.values()[0].has("occupation_stability"),"current save format includes espionage and occupation progress")
	check(saved.research[session.player_house].has("commerce") and not saved.retainers.technology[session.player_house].has("agriculture"),"commerce branch and shared governance points are saved")
	check(is_equal_approx(float(saved.prestige[session.player_house]), main.house_prestige.value_for(session.player_house)) and saved.prestige_court_ranks[session.player_house] == 1,"fractional prestige and awarded rank are saved")
	check(saved.retainers.loyalty_state.size() == session.catalog.officer_ids.size(),"all officer loyalty records are saved")
	check(saved.research.has(session.player_house),"research state is saved")
	check(saved.retainers.has("appointments") and saved.retainers.has("technology"),"retainer state is saved")
	var population_id: String = saved.territories.districts.keys()[0]
	check(saved.territories.districts[population_id].population == main.governance_registry.districts[population_id].population,"district population is saved")
	check(saved.territories.districts[population_id].security == 50,"initial district security is saved")
	check(saved.territories.districts[population_id].has("agriculture_development") and saved.economy.has("house_resources"),"development and resources are saved")
	session.pending = saved
	session.apply_to(main)
	check(main.retainer_management.officer_districts == saved.retainers.officer_districts,"current officer placement restores from save")
	var wrong := saved.duplicate(true)
	wrong.clock.day = 32
	check(not session.validate(wrong),"invalid calendar rejected")
	wrong = saved.duplicate(true)
	wrong.player_house = "missing"
	check(not session.validate(wrong),"unknown player rejected")
	wrong = saved.duplicate(true)
	wrong.territories.districts[population_id].population = -1
	check(not session.validate(wrong),"negative population rejected")
	var corrupt := FileAccess.open(session.path_for(2),FileAccess.WRITE)
	corrupt.store_string("{\"payload\":\"broken\",\"sha256\":\"invalid\"}")
	corrupt.close()
	check(session.load_game(2) != OK and session.player_house == "uesugi_yamanouchi","corrupt load preserves current game")
	check(session.save_game(main,1) == OK and FileAccess.file_exists(session.path_for(1)+".bak"),"overwrite retains previous backup")
	saved = session.read_save(1)
	escape()
	await process_frame
	check(main.game_menu.modal.visible and paused,"Esc returns from slots to menu")
	escape()
	check(not paused and main.game_clock.paused,"closing menu preserves manual pause")
	main.game_clock.toggle_paused()
	main.game_clock.set_speed(1)
	main.game_clock.set_process(true)
	main.game_menu.toggle()
	var fraction: float = main.game_clock._day_fraction
	await create_timer(0.3,true).timeout
	check(is_equal_approx(main.game_clock._day_fraction,fraction),"running clock cannot tick inside menu")
	main.game_menu.toggle()
	await create_timer(0.1,true).timeout
	check(main.game_clock._day_fraction>fraction and main.game_clock._day_fraction-fraction<0.25,"menu time is not caught up on resume")
	session.return_to_title()
	await process_frame
	await process_frame
	check(current_scene.name == "StartScreen" and not paused,"returns to title")
	check(root.get_node_or_null("Main") == null,"map nodes released at title")
	check(session.load_game(1) == OK,"load launches map")
	main = await wait_map()
	if main == null: quit(1); return
	check(session.player_house == saved.player_house,"player restored")
	check(main.game_clock.year == saved.clock.year and main.game_clock.month == saved.clock.month and main.game_clock.day == saved.clock.day,"date restored")
	check(main.game_clock.speed == 4 and main.game_clock.paused,"speed and pause restored")
	check(is_equal_approx(main.game_clock._day_fraction,saved.clock.fraction),"partial day restored")
	check(main.camera.position.distance_to(Vector2(saved.camera.x,saved.camera.y))<.01,"camera restored")
	check(is_equal_approx(main.camera.zoom.x,saved.camera.zoom),"zoom restored")
	check(session.relations == saved.relations,"diplomacy restored")
	check(main.retainer_management.appointments == saved.retainers.appointments,"appointments restored")
	check(main.retainer_management.technology == saved.retainers.technology,"technology restored")
	check(saved.prestige.keys().all(func(id): return is_equal_approx(main.house_prestige.value_for(id), float(saved.prestige[id]))) and saved.prestige_court_ranks.keys().all(func(id): return int(main.house_prestige.court_ranks[id]) == int(saved.prestige_court_ranks[id])),"fractional prestige and awarded ranks restored")
	check(main.retainer_management.loyalty_state == saved.retainers.loyalty_state,"loyalty state restored")
	check(main.technology_tree.researched == saved.research,"research state restored")
	for id in saved.territories.districts:
		check(main.governance_registry.districts[id].house_id == saved.territories.districts[id].house_id,"district ownership restored")
		check(main.governance_registry.districts[id].population == saved.territories.districts[id].population,"district population restored")
		var expected: Variant = saved.territories.districts[id].governor
		if expected is Dictionary:
			expected = expected.duplicate(true)
			expected.assignment_count = int(expected.assignment_count)
		check(main.governance_registry.districts[id].governor == expected,"governor restored")
	var rebellion_officer: String = main.retainer_management.house_members[session.player_house][0]
	var rebellion_district := ""
	for id in main.governance_registry.districts:
		if main.governance_registry.districts[id].house_id == session.player_house: rebellion_district = id; break
	check(main.retainer_management.assign_role(session.player_house, rebellion_officer, "侍大将") == OK,"rebellion test promotion")
	check(main.retainer_management.appoint_district_governor(session.player_house, rebellion_officer, rebellion_district) == OK,"rebellion test governorship")
	main.retainer_management.loyalty_state[rebellion_officer].loyalty = 0
	main.retainer_management.loyalty_state[rebellion_officer].required = 90
	main.retainer_management.resolve_loyalty_crises(main.game_clock.year)
	var rebel_house: String = "rebel_" + rebellion_officer
	check(main.governance_registry.districts[rebellion_district].house_id == rebel_house,"rebellion changes map ownership")
	check(session.save_game(main,3) == OK,"rebellion can be saved")
	check(not session.read_save(3).is_empty(),"rebellion save validates")
	session.return_to_title()
	await process_frame
	await process_frame
	check(session.load_game(3) == OK,"rebellion save loads")
	main = await wait_map()
	if main == null: quit(1); return
	check(main.governance_registry.districts[rebellion_district].house_id == rebel_house,"independent district restored")
	session.return_to_title()
	await process_frame
	await process_frame
	print("Start/session tests: %d failures" % failures)
	quit(1 if failures else 0)

func advance_days(clock: Node, count: int) -> void:
	for index in range(count):
		var previous: int = clock.elapsed_days
		while clock.elapsed_days == previous:
			clock.advance_real_seconds(1.0 / clock.speed)
			await process_frame
