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
	check(session.relation(session.player_house,"uesugi_ogigayatsu")=="ally","alliance lookup")
	check(session.relation("hojo",session.player_house)=="enemy","symmetric enemy lookup")
	check(session.relation(session.player_house,"takeda")=="neutral","unknown diplomacy remains neutral")
	check(main.game_menu.zoom_label.text == "マップ拡大率：50%","bottom-left shows the 50% initial map zoom")
	check("上杉" not in main.game_menu.zoom_label.text and "自領" not in main.game_menu.zoom_label.text and "同盟" not in main.game_menu.zoom_label.text and "敵対" not in main.game_menu.zoom_label.text and "その他" not in main.game_menu.zoom_label.text,"bottom-left omits house and diplomacy legend")
	var states := {}
	for r in main.territory_borders.projected.values(): states[r.state]=true
	check(states.has("self") and states.has("ally") and states.has("enemy"),"three outline classes constructed")
	main.game_clock.set_process(false)
	main.game_clock.restore_state({"year":1546,"month":1,"day":1,"elapsed_days":0,"speed":1,"paused":false,"fraction":0.0})
	main.game_clock.advance_real_seconds(59.375)
	main.game_clock.set_speed(4)
	main.game_clock.toggle_paused()
	main.camera.position = Vector2(5000,4800)
	main.set_map_zoom(0.7)
	await process_frame
	check(main.game_menu.zoom_label.text == "マップ拡大率：70%","zoom display follows camera changes")
	main._refresh_visible_tiles()
	if DisplayServer.get_name() != "headless": await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
	await capture_png("start_territory_borders")
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
	# Mutate real session state so a loader that merely reloads defaults cannot pass.
	var changed_id: String = main.governance_registry.districts.keys()[0]
	var hojo_record: Dictionary
	for r in main.governance_registry.districts.values():
		if r.house_id == "hojo": hojo_record = r; break
	for field in ["house_id","governor","ruler"]: main.governance_registry.districts[changed_id][field] = hojo_record[field]
	session.relations[session.pair("oda_nobuhide","takeda")] = "enemy"
	var capture_probe: Dictionary = session.capture(main)
	check(session.validate(capture_probe),"captured version 3 session validates before saving")
	var roundtrip_probe: Dictionary = JSON.parse_string(JSON.stringify(capture_probe))
	check(session.validate(roundtrip_probe),"serialized version 3 session validates")
	main.game_menu.show_slots(true)
	main.game_menu.slots.choose(1)
	check("保存しました" in main.game_menu.slots.status.text,"save slot UI succeeds")
	await capture_png("start_save_slots")
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty(),"saved payload validates")
	if saved.is_empty(): printerr(session.last_error); quit(1); return
	check(saved.clock.day == 1 and saved.clock.month == 3,"calendar crosses February")
	check(saved.version == 3,"current save format includes population and economy")
	var population_id: String = saved.territories.districts.keys()[0]
	check(saved.territories.districts[population_id].population == main.governance_registry.districts[population_id].population,"district population is saved")
	check(saved.territories.districts[population_id].has("agriculture_development") and saved.economy.has("house_resources"),"development and resources are saved")
	var version_two := saved.duplicate(true)
	version_two.version = 2
	version_two.erase("economy")
	for id in version_two.territories.districts:
		for field in ["agriculture_development","commerce_development","agriculture_progress","commerce_progress","agriculture_developer_id","commerce_developer_id"]: version_two.territories.districts[id].erase(field)
	check(session.validate(version_two),"version 2 population save remains loadable")
	var legacy := saved.duplicate(true)
	legacy.version = 1
	legacy.erase("economy")
	for id in legacy.territories.districts:
		for field in ["population","agriculture_development","commerce_development","agriculture_progress","commerce_progress","agriculture_developer_id","commerce_developer_id"]: legacy.territories.districts[id].erase(field)
	check(session.validate(legacy),"version 1 save without population remains loadable")
	main.governance_registry.districts[population_id].population = 1
	check(main.governance_registry.apply_initial_population() == OK,"legacy-load scene initializes population from the adopted ledger")
	session.pending = legacy
	session.apply_to(main)
	check(main.governance_registry.districts[population_id].population == main.governance_registry.districts[population_id].initial_population,"version 1 migration keeps the adopted initial population")
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
	for id in saved.territories.districts:
		check(main.governance_registry.districts[id].house_id == saved.territories.districts[id].house_id,"district ownership restored")
		check(main.governance_registry.districts[id].population == saved.territories.districts[id].population,"district population restored")
		var expected: Variant = saved.territories.districts[id].governor
		if expected is Dictionary:
			expected = expected.duplicate(true)
			expected.assignment_count = int(expected.assignment_count)
		check(main.governance_registry.districts[id].governor == expected,"governor restored")
	session.return_to_title()
	await process_frame
	await process_frame
	print("Start/session tests: %d failures" % failures)
	quit(1 if failures else 0)
