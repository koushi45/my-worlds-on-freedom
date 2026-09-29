extends SceneTree
const Grid = preload("res://scripts/map/hex_grid.gd")
const MERGED := ["chikugo/unresolved-42cfaa8c657745ea", "chikuzen/unresolved-42cfaa8c657745ea"]
const KANZAKI := "hizen/merged-3051a6f57adaff58"

func _initialize() -> void:
	call_deferred("run")

func require(value: bool, message: String) -> bool:
	if not value: printerr("FAIL: " + message); quit(1)
	return value

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/qa/" + name + ".png")

func run() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline and (current_scene == null or current_scene.game_menu == null): await process_frame
	if not require(current_scene != null and current_scene.game_menu != null, "map ready"): return
	var main = current_scene
	main.game_clock.set_process(false)
	var offices = main.district_office_layer
	if not require(main.territory_borders.independent_fill_files.size() == main.governance_registry.districts.size(), "fill meshes match current district geometry"): return
	if not require(offices.records.size() == main.governance_registry.districts.size(), "one office per active district"): return
	for id in MERGED:
		if not require(not main.governance_registry.districts.has(id) and not offices.records.has(id), "merged district removed"): return
	if not require(offices.records.has(KANZAKI), "merged Kanzaki has one office"): return
	if not require(main.territory_borders.review_highlights.is_empty(), "all review red fills removed"): return
	main.set_map_zoom(2.0)
	main._refresh_visible_tiles()
	for id in offices.records:
		var point: Vector2 = offices.office_point(id)
		if not require(offices.pick(point) == id, "office tile selects its own district"): return
		if not require(main.hex_tile_layer.visible_cells.has(Grid.cell_at(point)), "office is on visible hex coverage"): return
	main.set_map_zoom(1.99)
	main._refresh_visible_tiles()
	if not require(offices.pick(offices.office_point(offices.records.keys()[0])).is_empty(), "office picking disabled below 200 percent"): return
	var focus := ""
	for id in offices.records:
		var ref: Variant = offices.records[id].reference
		if ref is Dictionary and ref.id == "kofu_governance": focus = id; break
	if not require(not focus.is_empty(), "documented medieval reference retained"): return
	main.set_map_zoom(4.0)
	main.camera.position = main.elevation.project(offices.office_point(focus))
	main._refresh_visible_tiles()
	for frame in 20: await process_frame
	await capture("district_office_kofu")
	if DisplayServer.get_name() != "headless":
		if not require(main.kamon_layer.drawn_keys.is_empty(), "no separate district crest markers"): return
		if not require(offices.drawn_kamon_houses.get(focus) == main.governance_registry.districts[focus].house_id, "office renders current owning house crest"): return
		var original_house: String = main.governance_registry.districts[focus].house_id
		main.governance_registry.districts[focus].house_id = "oda_nobuhide"
		offices.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if not require(offices.drawn_kamon_houses.get(focus) == "oda_nobuhide", "office crest follows ownership changes"): return
		main.governance_registry.districts[focus].house_id = original_house
		main.set_map_zoom(2.0)
		main._refresh_visible_tiles()
		for frame in 3: await process_frame
		await capture("district_office_kamon_200")
		if not require(main.kamon_layer.drawn_keys.is_empty() and offices.drawn_kamon_houses.has(focus), "only office crest appears at 200 percent"): return
		main.set_map_zoom(4.0)
		main._refresh_visible_tiles()
	main.show_district_info(focus)
	await process_frame
	await capture("district_office_information")
	main.district_info.hide_info()
	var p: Array = main.district_layer.records[KANZAKI].label
	main.camera.position = main.elevation.project(Vector2(float(p[0]),float(p[1])))
	main._refresh_visible_tiles()
	for frame in 20: await process_frame
	await capture("district_kanzaki_merged")
	var tsuru := "kai/unresolved-b48d2f62146c8828"
	if not require(main.governance_registry.districts[tsuru].name == "都留郡", "merged district renamed Tsuru"): return
	if not require(not main.governance_registry.districts.has("sagami/unresolved-42cfaa8c657745ea"), "Miura provisional district merged"): return
	main.camera.position = main.elevation.project(offices.office_point(tsuru))
	main._refresh_visible_tiles()
	for frame in 20: await process_frame
	await capture("district_tsuru_merged")
	var uenohara := "kai/unresolved-cd2be55f925d6adb"
	if not require(not main.governance_registry.districts.has("musashi/unresolved-42cfaa8c657745ea"), "Chichibu provisional district merged"): return
	main.camera.position = main.elevation.project(offices.office_point(uenohara))
	main._refresh_visible_tiles()
	for frame in 20: await process_frame
	await capture("district_uenohara_merged")
	print("District office coverage, picking, zoom visibility and red review tests passed")
	quit(0)
