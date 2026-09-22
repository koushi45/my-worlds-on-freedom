extends SceneTree
var failures := 0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session := root.get_node("GameSession")
	session.player_house = "oda_nobuhide"
	session.save_directory = "user://qa_enclave_%d" % OS.get_process_id()
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec()+45000
	while not main.initialized and Time.get_ticks_msec()<deadline: await process_frame
	if not main.initialized: printerr("Map initialization timed out"); quit(1); return
	main.game_menu.toggle()
	var count: int = session.catalog.district_ids.size()
	check(main.district_layer.records.size()==count,"all active districts load")
	check(main.governance_registry.districts.size()==count,"all active districts have governance")
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/master/district_overlap_review.json"))
	var chita := "owari/unresolved-42cfaa8c657745ea"
	check(not main.district_layer.records.has(chita), "retired Chita removed from labels and picking records")
	check(not main.governance_registry.districts.has(chita), "retired Chita removed from governance")
	check(main.governance_registry.search("district", "知多郡周辺").is_empty(), "retired Chita removed from search")
	for pair in audit.pairs:
		if pair.a != chita and pair.b != chita: continue
		var found: Array = await main.district_layer.pick_async(Vector2(pair.point[0], pair.point[1]))
		check(chita not in found,"removed overlap cannot select provisional Chita")
		check(not found.is_empty(),"other district remains selectable in removed Chita overlap")
	var saved: Dictionary = session.capture(main)
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/governance/governance_1546.json")).districts
	saved.territories.districts.clear()
	for id in original:
		var r: Dictionary = original[id]
		saved.territories.districts[id] = {"house_id":r.house_id,"governor":r.governor,"ruler":r.ruler}
	check(saved.territories.districts.size()==709,"construct legacy save")
	check(session.validate(saved),"legacy IDs validate")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session.save_directory))
	var payload := JSON.stringify(saved)
	var file := FileAccess.open(session.path_for(1),FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
	file.close()
	var migrated: Dictionary = session.read_save(1)
	check(migrated.territories.districts.size()==count,"legacy save migrates to active layout")
	for id in session.catalog.district_origins:
		check(migrated.territories.districts[id]==session.catalog.district_defaults[id],"curated island uses its explicit governance setting")
	check(main.governance_registry.search("district", "島部").is_empty(),"deleted automatic island districts are absent from search")
	for layout_name in ["previous_layout_ids","overlap_layout_ids"]:
		var legacy := saved.duplicate(true)
		legacy.territories.districts.clear()
		for id in session.catalog[layout_name]:
			legacy.territories.districts[id] = saved.territories.districts.get(id,saved.territories.districts.values()[0]).duplicate(true)
		check(session.validate(legacy),layout_name+" layout accepted")
		payload = JSON.stringify(legacy)
		file = FileAccess.open(session.path_for(1),FileAccess.WRITE)
		file.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
		file.close()
		migrated = session.read_save(1)
		check(not migrated.is_empty() and migrated.territories.districts.size()==count,layout_name+" migrates to current layout")
		if not migrated.is_empty(): check(not migrated.territories.districts.has(chita),"legacy save cannot restore retired districts")
	check(session.save_game(main,2)==OK,"new layout saves")
	check(session.read_save(2).territories.districts.size()==count,"new layout loads")
	main.game_menu.toggle()
	main.district_layer.select_key("owari/candidate-district-candidate-g09002")
	main.camera.position = main.elevation.project(Vector2(3860,5260))
	main._clamp_camera()
	main._refresh_visible_tiles()
	if DisplayServer.get_name() != "headless":
		await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/enclave_chita.png")
		var island: String = session.catalog.district_origins.keys()[0]
		main.district_layer.select_key(island)
		var label: Array = main.district_layer.records[island].label
		main.set_map_zoom(2.2)
		main.camera.position = main.elevation.project(Vector2(label[0],label[1]))
		main._clamp_camera()
		main._refresh_visible_tiles()
		await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
		await RenderingServer.frame_post_draw
		check(island in main.kamon_layer.visible_keys,"curated island reaches the kamon layer")
		check(main.governance_registry.districts.has(island),"curated island has governance")
		var island_house: String = main.governance_registry.districts[island].house_id
		var island_asset: String = main.kamon_layer.kamon_by_house.get(island_house,{}).get("asset","")
		check(not island_asset.is_empty() and main.kamon_layer.kamon_textures.has(island_asset),"curated island house has a loaded kamon")
		check(main.kamon_layer.view_rect.has_point(Vector2(label[0],label[1])),"curated island anchor is in the kamon view")
		check(island in main.kamon_layer.drawn_keys,"curated island draws its own kamon")
		root.get_texture().get_image().save_png("res://builds/qa/enclave_island.png")
	main.queue_free()
	await process_frame
	print("Enclave save tests: %d failures" % failures)
	quit(1 if failures else 0)
