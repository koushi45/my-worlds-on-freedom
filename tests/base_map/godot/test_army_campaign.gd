extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(value: bool, message: String) -> bool:
	if not value: printerr("FAIL: " + message); quit(1)
	return value

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/qa/" + name + ".png")

func mouse_button(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	return event

func map_screen(main: Node2D, point: Vector2) -> Vector2:
	if main.map_view != null:
		main.map_view.sync(true)
		return main.map_view.project(point)
	return (main.elevation.project(point) - main.camera.position) * main.camera.zoom.x + main.get_viewport_rect().size * 0.5

func test_melee(main: Node2D, army: Node2D, template: Dictionary, enemy_house: String, ally_house: String) -> bool:
	var grid = preload("res://scripts/map/hex_grid.gd")
	var session: Node = root.get_node("GameSession")
	var officer_ids: Array = main.officer_registry.lookup.keys()
	var high_id: String = officer_ids[0]
	var low_id: String = officer_ids[1]
	var high_scores: Dictionary = main.officer_registry.lookup[high_id].assessment.scores
	var low_scores: Dictionary = main.officer_registry.lookup[low_id].assessment.scores
	var old_high: Variant = high_scores.tactics
	var old_low: Variant = low_scores.tactics
	high_scores.tactics = 30; low_scores.tactics = 10
	var a: Dictionary = template.duplicate(true)
	a.id = "melee_a"; a.soldiers = 1000; a.officers = [high_id]; a.bow_reload = 0.0; a.bow_damage = 0.0; a.melee_damage = 0.0
	a.next_site = ""; a.progress = 0.0; a.orders = []; a.movement_hold = true
	var b: Dictionary = a.duplicate(true)
	b.id = "melee_b"; b.house_id = enemy_house; b.officers = [low_id]
	army.units = {"melee_a":a, "melee_b":b}
	if not require(army.melee_engagements().has("melee_a") and army.melee_engagements().has("melee_b"), "enemies sharing a tile engage in melee"): return false
	army._bow_step(1.0)
	if not require(a.soldiers == 1000 and b.soldiers == 1000 and is_zero_approx(a.bow_reload) and is_zero_approx(b.bow_reload), "engaged formations stop firing arrows"): return false
	army._march_step(1.0)
	if not require(b.soldiers < a.soldiers and a.soldiers < 1000, "equal troops with higher valor inflict greater melee casualties and both return attacks"): return false
	var mixed: Dictionary = a.duplicate(true)
	mixed.officers = [high_id, low_id]
	if not require(is_equal_approx(army.unit_valor(mixed), 20.0), "unit valor averages commander and deputies"): return false
	var larger: Dictionary = a.duplicate(true)
	larger.soldiers = a.soldiers * 2
	if not require(is_equal_approx(army.melee_power(larger, 1.0), army.melee_power(a, 1.0) * 2.0), "troop count scales melee damage"): return false
	a.soldiers = 1000; b.soldiers = 1000; a.melee_damage = 0.0; b.melee_damage = 0.0
	b.officers = [high_id]
	army._melee_step(0.5)
	if not require(a.soldiers == b.soldiers and a.soldiers < 1000, "equal valor and equal troops produce equal melee casualties"): return false
	a.soldiers = 1000; b.soldiers = 1000; a.melee_damage = 0.0; b.melee_damage = 0.0
	b.officers = [low_id]
	army._melee_step(0.001)
	if not require(a.soldiers == 1000 and b.soldiers == 1000 and b.melee_damage > a.melee_damage and a.melee_damage > 0.0, "small melee ticks retain fractional damage instead of rounding it away"): return false
	main.game_clock.paused = true
	var fraction_before: float = b.melee_damage
	army._process(0.5)
	if not require(b.melee_damage == fraction_before and b.soldiers == 1000, "paused clock stops melee damage"): return false
	main.game_clock.paused = false
	b.house_id = ally_house
	army._melee_step(1.0)
	if not require(army.melee_engagements().is_empty() and a.soldiers == 1000 and b.soldiers == 1000, "overlapping allied armies never fight each other"): return false
	b.house_id = a.house_id
	if not require(army.melee_engagements().is_empty(), "overlapping own armies never fight each other"): return false
	b.house_id = enemy_house
	var origin_cell: Vector2i = grid.cell_at(army.unit_position(a))
	b.site_id = grid.key(origin_cell + Vector2i(1, 0)); b.next_site = grid.key(origin_cell); b.progress = 0.6
	if not require(army.melee_engagements().has("melee_b"), "moving army engages when its current position enters the occupied tile"): return false
	b.progress = 0.1
	if not require(army.melee_engagements().is_empty(), "adjacent tiles do not trigger melee"): return false
	var ranged_target: Vector2 = army.unit_position(b)
	var strong_profile: Dictionary = army.bow_profile(a, ranged_target)
	a.officers = [low_id]
	if not require(army.bow_profile(a, ranged_target) == strong_profile, "valor affects none of the bow firing parameters"): return false
	b.next_site = ""; b.progress = 0.0; b.bow_reload = 10.0
	a.bow_reload = 0.0; a.bow_damage = 0.0; b.bow_damage = 0.0
	army._bow_step(army.MOVE_STEP)
	var low_valor_loss: int = 1000 - int(b.soldiers)
	var low_valor_fraction: float = b.bow_damage
	a.officers = [high_id]; a.bow_reload = 0.0; b.soldiers = 1000; b.bow_damage = 0.0
	army._bow_step(army.MOVE_STEP)
	if not require(1000 - int(b.soldiers) == low_valor_loss and is_equal_approx(b.bow_damage, low_valor_fraction), "actual arrow damage is unchanged by valor"): return false
	b.site_id = a.site_id
	var allied_fighter: Dictionary = a.duplicate(true)
	allied_fighter.id = "allied_fighter"; allied_fighter.house_id = ally_house
	var allied_enemy_pair: String = session.pair(ally_house, enemy_house)
	var old_relation: Variant = session.relations.get(allied_enemy_pair)
	session.relations[allied_enemy_pair] = "enemy"
	army.units = {"melee_a":a, "melee_b":b, "allied_fighter":allied_fighter}
	var allied_engagements: Dictionary = army.melee_engagements()
	if not require(allied_engagements.has("allied_fighter") and allied_engagements.allied_fighter == ["melee_b"] and allied_engagements.melee_a == ["melee_b"], "own and allied formations engage the common enemy without attacking each other"): return false
	if old_relation == null: session.relations.erase(allied_enemy_pair)
	else: session.relations[allied_enemy_pair] = old_relation
	b.site_id = a.site_id; b.melee_damage = 0.0; a.melee_damage = 0.0; a.soldiers = 1000; b.soldiers = 1000
	var c: Dictionary = b.duplicate(true)
	c.id = "melee_c"
	army.units = {"melee_a":a, "melee_b":b, "melee_c":c}
	var attack_budget: float = army.melee_power(a, 1.0)
	army._melee_step(1.0)
	if not require(b.soldiers == c.soldiers and is_equal_approx(2000.0 - b.soldiers - c.soldiers + b.melee_damage + c.melee_damage, attack_budget), "multiple enemies share a formation's melee attack budget"): return false
	a.soldiers = 1; b.soldiers = 1; a.melee_damage = 0.0; b.melee_damage = 0.0
	army.units = {"melee_b":b, "melee_a":a}; army.selected_id = "melee_a"
	army._melee_step(100.0)
	if not require(army.units.is_empty() and army.selected_id.is_empty(), "lethal melee resolves simultaneously and clears selection"): return false
	high_scores.tactics = old_high; low_scores.tactics = old_low
	return true

func run() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized): await process_frame
	if not require(current_scene != null and current_scene.initialized, "map initialized"): return
	var main = current_scene
	main.set_oblique(false)
	main.game_clock.set_process(false)
	var army = main.army_campaign
	army.set_process(false)
	var grid_script = preload("res://scripts/map/hex_grid.gd")
	var detail_definition: Dictionary = main.catalog.detail_tiles[0]
	var original_zoom: Vector2 = main.camera.zoom
	main.camera.zoom = Vector2.ONE * 2.49
	var normal_texture_path: String = main._tile_path(detail_definition)
	main.camera.zoom = Vector2.ONE * 2.5
	var close_texture_path: String = main._tile_path(detail_definition)
	main.camera.zoom = original_zoom
	if not require(normal_texture_path.ends_with(".res") and close_texture_path == normal_texture_path.replace(".res", "_close.res"), "250 percent selects the dedicated close terrain resource"): return
	if not require(main.shared_road_layer.get_parent() == main.hex_tile_layer and main.connection_layer.get_parent() == main.hex_tile_layer, "roads are children of hex layer"): return
	for stroke in main.shared_road_layer.data.strokes:
		var previous: Variant = null
		for raw in stroke.points:
			var point := Vector2(float(raw[0]), float(raw[1]))
			var cell: Vector2i = grid_script.cell_at(point)
			if not require(point.is_equal_approx(grid_script.center(cell)), "road vertex is a tile center"): return
			if previous != null and not require(grid_script.distance(previous, cell) == 1, "road follows adjacent centers"): return
			previous = cell
	var represented := {}
	for district_key in main.district_buildings.historical_facilities:
		for site_id in main.district_buildings.existing_facilities(district_key):
			if not require(not represented.has(site_id), "historical facility occupies one district only"): return
			represented[site_id] = true
	for site_id in main.governance_registry.sites:
		var site: Dictionary = main.governance_registry.sites[site_id]
		if "castle" in site.roles or "port" in site.roles:
			if not require(represented.has(site_id), "castle or port has a building slot"): return
	for site in main.settlement_layer.data.sites:
		if "castle" in site.roles or "port" in site.roles:
			if not require(not main.settlement_layer.eligible(site), "castle and port markers are suppressed"): return
	var session = root.get_node("GameSession")
	var district_id := ""
	var officer_ids: Array[String] = []
	for id in main.governance_registry.districts:
		var district: Dictionary = main.governance_registry.districts[id]
		if not district.get("site_ids", []).is_empty(): continue
		if army.graph.get("district:" + id, []).is_empty() or main.district_actions.sortie_available(district) < 400: continue
		session.player_house = district.house_id
		officer_ids = army.available_officers(id)
		if not officer_ids.is_empty(): district_id = id; break
	if not require(not district_id.is_empty(), "a district without castles can dispatch"): return
	var district: Dictionary = main.governance_registry.districts[district_id]
	var starting: int = district.sortie_troops
	var house_id: String = district.house_id
	var other_district := ""
	for candidate in main.governance_registry.districts:
		if candidate != district_id and main.governance_registry.districts[candidate].house_id == house_id: other_district = candidate; break
	if not require(not other_district.is_empty(), "house has a second district for placement"): return
	if not require(main.retainer_management.place_officer(house_id, officer_ids[0], other_district) == OK, "officer can be placed in another district"): return
	if not require(officer_ids[0] not in army.available_officers(district_id), "sortie candidates exclude officers in other districts"): return
	if not require(army.dispatch(district_id, [officer_ids[0]], 25, false, false).is_empty() and army.last_error == "選択した武将は出陣できません。", "dispatch rejects an officer stationed elsewhere"): return
	if not require(main.retainer_management.place_officer(house_id, officer_ids[0], district_id) == OK, "officer can return to source district"): return
	main.show_district_info(district_id)
	main.district_info._open_placement()
	if not require(main.army_panel.panel.visible and main.army_panel.mode == "placement" and not main.district_info.panel.visible, "district placement opens without duplicate panel"): return
	main.army_panel._open_placement_roster()
	if not require(main.army_panel.right_panel.visible, "placement shows the house roster on the right"): return
	await capture("army_placement")
	main.army_panel.hide_panel()
	main.show_district_info(district_id)
	main.district_info._open_sortie()
	if not require(main.army_panel.panel.visible and not main.district_info.panel.visible, "district sortie value opens formation without duplicate panel"): return
	main.army_panel._open_officer_roster(0)
	if not require(main.army_panel.right_panel.visible, "commander opens right-side officer list"): return
	await capture("army_commander")
	(main.army_panel.roster.get_child(0) as Button).pressed.emit()
	if not require(main.army_panel.selected_officers[0] == officer_ids[0] and not main.army_panel.right_panel.visible, "officer selection closes right-side list"): return
	main.army_panel.hide_panel()
	main.district_economy.house_resources[house_id].provisions = starting * 5
	var unit_id: String = army.dispatch(district_id, [officer_ids[0]], 25, false, false)
	if not require(not unit_id.is_empty(), "dispatch succeeds: " + army.last_error): return
	if not require(main.retainer_management.place_officer(house_id, officer_ids[0], other_district) == ERR_BUSY, "deployed officer cannot be moved"): return
	if not require(army.units[unit_id].soldiers >= 100 and district.sortie_troops < starting, "soldiers leave district"): return
	var marching_save: Dictionary = session.capture(main)
	if not require(session.validate(marching_save) and marching_save.armies.units.has(unit_id) and marching_save.retainers.officer_districts[officer_ids[0]] == district_id, "marching army and placement validate for save"): return
	session.save_directory = "res://builds/qa/army_%d" % OS.get_process_id()
	if not require(session.save_game(main, 1) == OK, "marching army writes save"): return
	if not require(session.read_save(1).armies.units.has(unit_id), "marching army reads from save"): return
	var grid = preload("res://scripts/map/hex_grid.gd")
	var terrain = preload("res://scripts/map/hex_terrain.gd")
	if not require(terrain.name_for(terrain.PLAIN) == "平地" and terrain.name_for(terrain.MOUNTAIN) == "山地" and terrain.name_for(terrain.RIVER) == "川" and terrain.name_for(terrain.HIGH_MOUNTAIN) == "高山地" and terrain.name_for(terrain.NO_LAND) == "陸地なし", "all terrain classes have tile names"): return
	if not require(terrain.days_for(terrain.PLAIN, true) == 1.0 and terrain.days_for(terrain.PLAIN, false) == 1.5 and terrain.days_for(terrain.MOUNTAIN, true) == 1.5 and terrain.days_for(terrain.MOUNTAIN, false) == 2.5 and terrain.days_for(terrain.RIVER, true) == 1.5 and terrain.days_for(terrain.RIVER, false) == 5.0 and is_inf(terrain.days_for(terrain.HIGH_MOUNTAIN, true)) and is_inf(terrain.days_for(terrain.NO_LAND, true)), "terrain and road travel times follow the requested values"): return
	if not require(main.hex_tile_layer.terrain_for(Vector2i(-1000, -1000)) == terrain.NO_LAND, "outside coverage is impassable"): return
	var mountain_cell := Vector2i.ZERO
	var mountain_neighbor := Vector2i.ZERO
	for cell in main.hex_tile_layer.visible_cells:
		if main.hex_tile_layer.terrain_for(cell) != terrain.MOUNTAIN: continue
		var neighbor: Vector2i = cell + Vector2i(1, 0)
		if main.hex_tile_layer.can_enter(neighbor):
			mountain_cell = cell
			mountain_neighbor = neighbor
			break
	if not require(mountain_cell != Vector2i.ZERO, "measured mountain tile exists"): return
	var road = main.developer_tools.network
	var old_from: bool = road.cells.has(mountain_neighbor)
	var old_to: bool = road.cells.has(mountain_cell)
	var edge: Vector4i = road.edge_key(mountain_neighbor, mountain_cell)
	var old_excluded: bool = road.excluded_edges.has(edge)
	road.cells[mountain_neighbor] = true
	road.cells[mountain_cell] = true
	road.excluded_edges.erase(edge)
	if not require(is_equal_approx(army.travel_days_for_leg(grid.key(mountain_neighbor), grid.key(mountain_cell)), 1.5), "connected road permits plain-speed mountain travel"): return
	road.excluded_edges[edge] = true
	if not require(is_equal_approx(army.travel_days_for_leg(grid.key(mountain_neighbor), grid.key(mountain_cell)), 2.5), "disconnected road does not accelerate mountain travel"): return
	if not old_from: road.cells.erase(mountain_neighbor)
	if not old_to: road.cells.erase(mountain_cell)
	if not old_excluded: road.excluded_edges.erase(edge)
	var river_cell := Vector2i.ZERO
	var river_neighbor := Vector2i.ZERO
	for cell in main.hex_tile_layer.visible_cells:
		if main.hex_tile_layer.terrain_for(cell) != terrain.RIVER: continue
		var neighbor: Vector2i = cell + Vector2i(1, 0)
		if main.hex_tile_layer.can_enter(neighbor):
			river_cell = cell
			river_neighbor = neighbor
			break
	if not require(river_cell != Vector2i.ZERO, "mapped river tile exists"): return
	var river_from_road: bool = road.cells.has(river_neighbor)
	var river_to_road: bool = road.cells.has(river_cell)
	var river_edge: Vector4i = road.edge_key(river_neighbor, river_cell)
	var river_excluded: bool = road.excluded_edges.has(river_edge)
	road.cells[river_neighbor] = true
	road.cells[river_cell] = true
	road.excluded_edges.erase(river_edge)
	if not require(is_equal_approx(army.travel_days_for_leg(grid.key(river_neighbor), grid.key(river_cell)), 1.5), "bridge permits river crossing in 1.5 days"): return
	road.excluded_edges[river_edge] = true
	if not require(is_equal_approx(army.travel_days_for_leg(grid.key(river_neighbor), grid.key(river_cell)), 5.0), "river without a connected bridge remains slow"): return
	if not river_from_road: road.cells.erase(river_neighbor)
	if not river_to_road: road.cells.erase(river_cell)
	if not river_excluded: road.excluded_edges.erase(river_edge)
	var high_cell := Vector2i.ZERO
	var detour_from := Vector2i.ZERO
	var detour_to := Vector2i.ZERO
	for cell in main.hex_tile_layer.high_mountain_cells:
		for delta in grid.NEIGHBORS:
			var from_cell: Vector2i = cell - delta
			var to_cell: Vector2i = cell + delta
			if main.hex_tile_layer.can_enter(from_cell) and main.hex_tile_layer.can_enter(to_cell):
				high_cell = cell
				detour_from = from_cell
				detour_to = to_cell
				break
		if high_cell != Vector2i.ZERO: break
	if not require(high_cell != Vector2i.ZERO, "high mountain with passable neighboring tiles exists"): return
	if DisplayServer.get_name() != "headless" and "--capture" in OS.get_cmdline_user_args():
		var preview_high := high_cell
		var best_neighbors := -1
		for candidate in main.hex_tile_layer.high_mountain_cells:
			var neighbor_count := 0
			for delta in grid.NEIGHBORS:
				if main.hex_tile_layer.high_mountain_cells.has(candidate + delta): neighbor_count += 1
			if neighbor_count > best_neighbors or (neighbor_count == best_neighbors and candidate.x < preview_high.x):
				preview_high = candidate
				best_neighbors = neighbor_count
		var original_camera_position: Vector2 = main.camera.position
		var original_camera_zoom: Vector2 = main.camera.zoom
		main.camera.position = main.elevation.project(grid.center(preview_high))
		main.set_map_zoom(3.0)
		main.camera.force_update_scroll()
		for frame in 120: await process_frame
		if not require(main.detail_active, "mountain preview uses detailed terrain"): return
		var has_detail_tile := false
		for tile_id in main.loaded_tiles:
			if str(tile_id).begins_with("detail-"):
				has_detail_tile = true
				break
		if not require(has_detail_tile, "mountain preview streamed detailed texture"): return
		for tile_id in main.loaded_tiles:
			if str(tile_id).begins_with("detail-") and not require(str(main.loaded_tiles[tile_id].get_meta("path")).ends_with("_close.res"), "300 percent displays the close terrain texture"): return
		await capture("hex_high_mountain")
		main.camera.position = original_camera_position
		main.set_map_zoom(original_camera_zoom.x)
		main.camera.force_update_scroll()
	if not require(not army.order(unit_id, grid.key(high_cell)) and army.last_error == "高山地は通行できません。", "high mountain cannot be ordered as a target"): return
	var original_site: String = army.units[unit_id].site_id
	army.units[unit_id].site_id = grid.key(detour_from)
	var blocked_route: Array[String] = [grid.key(high_cell)]
	if not require(not army.order_path(unit_id, blocked_route) and army.last_error == "高山地は通行できません。", "hand-drawn route cannot enter an adjacent high mountain"): return
	army.units[unit_id].site_id = original_site
	var detour: Array = army.route(grid.key(detour_from), grid.key(detour_to))
	if not require(not detour.is_empty() and detour.back() == grid.key(detour_to), "click route finds a high-mountain detour"): return
	var detour_previous := detour_from
	for node_id in detour:
		var next_cell: Vector2i = grid.parse(node_id)
		if not require(grid.distance(detour_previous, next_cell) == 1 and not main.hex_tile_layer.high_mountain_cells.has(next_cell), "detour stays on adjacent passable tiles"): return
		detour_previous = next_cell
	army.units[unit_id].next_site = grid.key(high_cell)
	army._march_step(1.0)
	if not require(army.units[unit_id].site_id == army.units[unit_id].origin and army.units[unit_id].next_site.is_empty(), "march guard does not enter a high mountain"): return
	var no_land_cell := Vector2i.ZERO
	var shore_cell := Vector2i.ZERO
	for cell in main.hex_tile_layer.visible_cells:
		if main.hex_tile_layer.terrain_for(cell) != terrain.NO_LAND: continue
		for delta in grid.NEIGHBORS:
			if main.hex_tile_layer.can_enter(cell + delta):
				no_land_cell = cell
				shore_cell = cell + delta
				break
		if no_land_cell != Vector2i.ZERO: break
	if not require(no_land_cell != Vector2i.ZERO, "land-free tile beside a shore exists"): return
	if not require(not army.order(unit_id, grid.key(no_land_cell)) and army.last_error == "陸地のないタイルは通行できません。", "land-free target cannot be ordered"): return
	if not require(army.route(grid.key(shore_cell), grid.key(no_land_cell)).is_empty(), "route cannot end on water"): return
	army.units[unit_id].site_id = grid.key(shore_cell)
	var water_route: Array[String] = [grid.key(no_land_cell)]
	if not require(not army.order_path(unit_id, water_route) and army.last_error == "陸地のないタイルは通行できません。", "hand-drawn route cannot enter water"): return
	army.units[unit_id].site_id = original_site
	army.units[unit_id].next_site = grid.key(no_land_cell)
	army._march_step(1.0)
	if not require(army.units[unit_id].site_id == army.units[unit_id].origin and army.units[unit_id].next_site.is_empty(), "march guard does not enter water"): return
	var origin_cell: Vector2i = grid.cell_at(army.node_point(army.units[unit_id].origin))
	for color in ["blue", "green", "red", "neutral"]:
		for side in [64, 96, 128, 192, 256]:
			if not require(army.ARMY_ICONS[color][side].get_size() == Vector2(side, side), "native transparent army PNG exists: %s %d" % [color, side]): return
	if not require(army.icon_color_key({"house_id":house_id}) == "blue", "player unit is blue"): return
	var ally_house := "hojo" if house_id != "hojo" else "takeda"
	var enemy_house_for_color := "takeda" if house_id != "takeda" and ally_house != "takeda" else "uesugi"
	session.relations[session.pair(house_id, ally_house)] = "ally"
	session.relations[session.pair(house_id, enemy_house_for_color)] = "enemy"
	if not require(army.icon_color_key({"house_id":ally_house}) == "green" and army.icon_color_key({"house_id":enemy_house_for_color}) == "red", "allied and enemy units use relation colors"): return
	if not require(origin_cell == grid.cell_at(main.district_office_layer.office_point(district_id)), "district node is the office tile"): return
	var tile_target: String = grid.key(origin_cell + Vector2i(3, 0))
	if not require(army.order(unit_id, tile_target), "empty tile target accepted"): return
	var forward: Vector2 = (main.elevation.project(army.node_point(army.units[unit_id].next_site)) - main.elevation.project(army.unit_position(army.units[unit_id]))).normalized()
	if not require(Vector2.UP.rotated(army.facing_angle(army.units[unit_id])).dot(forward) > 0.99, "totsu faces the marching direction"): return
	if not require(army.route_points_for(unit_id).size() > 1, "player route has visible arrow points"): return
	var foreign_unit: Dictionary = army.units[unit_id].duplicate(true)
	foreign_unit.house_id = ally_house
	army.units["foreign_route_check"] = foreign_unit
	if not require(army.route_points_for("foreign_route_check").is_empty(), "allied and enemy routes are hidden"): return
	army.units.erase("foreign_route_check")
	var previous_cell := origin_cell
	for step in [army.units[unit_id].next_site] + army.units[unit_id].orders:
		var cell: Vector2i = grid.cell_at(army.node_point(step))
		if not require(grid.distance(previous_cell, cell) == 1, "route uses adjacent hexes"): return
		previous_cell = cell
	var hex_save: Dictionary = session.capture(main)
	if not require(session.validate(hex_save), "hex orders validate for save"): return
	if not require(session.save_game(main, 1) == OK, "hex orders save"): return
	var loaded: Dictionary = session.read_save(1)
	if not require(loaded.armies.units[unit_id].orders == army.units[unit_id].orders, "hex orders round trip"): return
	army.units[unit_id].next_site = ""
	army.units[unit_id].orders.clear()
	var bend: Array[String] = [grid.key(origin_cell + Vector2i(1, 0)), grid.key(origin_cell + Vector2i(1, 1)), grid.key(origin_cell + Vector2i(2, 1))]
	if not require(army.order_path(unit_id, bend), "hand-drawn hex path accepted"): return
	if not require(army.units[unit_id].next_site == bend[0] and army.units[unit_id].orders[0] == bend[1] and grid.cell_at(army.node_point(army.units[unit_id].orders.back())) == origin_cell + Vector2i(2, 1), "drawn bend is kept instead of replaced by a shortest route"): return
	if not require(session.save_game(main, 1) == OK and session.read_save(1).armies.units[unit_id].orders == army.units[unit_id].orders, "hand-drawn bends survive save and load"): return
	var first_leg_days: float = army.travel_days_for_leg(army.units[unit_id].site_id, army.units[unit_id].next_site)
	army.move_accumulator = 0.0
	army._process(0.02)
	if not require(is_zero_approx(float(army.units[unit_id].progress)), "visual processing alone does not advance movement"): return
	main.game_clock.advance_real_seconds(1.0 / 30.0)
	if not require(army.units[unit_id].site_id == army.units[unit_id].origin and is_equal_approx(float(army.units[unit_id].progress), 1.0 / (30.0 * first_leg_days)), "first 1/30 second applies destination terrain speed"): return
	main.game_clock.paused = true
	main.game_clock.advance_real_seconds(0.10)
	if not require(is_equal_approx(float(army.units[unit_id].progress), 1.0 / (30.0 * first_leg_days)), "paused clock stops movement"): return
	main.game_clock.paused = false
	main.game_clock.set_process(false)
	for tick in range(ceili(first_leg_days * 30.0) - 1): army._march_step(army.MOVE_STEP)
	if not require(grid.distance(origin_cell, grid.cell_at(army.unit_position(army.units[unit_id]))) == 1, "terrain-adjusted ticks complete one tile"): return
	if not require(session.save_game(main, 1) == OK and session.read_save(1).armies.units[unit_id].site_id == army.units[unit_id].site_id and is_equal_approx(float(session.read_save(1).armies.units[unit_id].progress), float(army.units[unit_id].progress)), "current hex and movement progress round trip"): return
	army.units[unit_id].site_id = army.units[unit_id].origin
	army.units[unit_id].next_site = ""
	army.units[unit_id].progress = 0.0
	army.units[unit_id].orders.clear()
	main.camera.position = main.elevation.project(army.node_point(army.units[unit_id].origin))
	main.camera.zoom = Vector2.ONE * 2.0
	main.camera.force_update_scroll()
	main.army_panel.show_unit(unit_id)
	var click_target := grid.key(origin_cell + Vector2i(3, 0))
	var click_screen := map_screen(main, army.node_point(click_target))
	main._unhandled_input(mouse_button(click_screen, true))
	main._unhandled_input(mouse_button(click_screen, false))
	if not require(grid.cell_at(army.node_point(army.units[unit_id].orders.back())) == origin_cell + Vector2i(3, 0), "unit selection followed by plain hex click orders movement"): return
	var queued_before: Array = army.units[unit_id].orders.duplicate()
	var next_before: String = army.units[unit_id].next_site
	var via_target := grid.key(origin_cell + Vector2i(3, 1))
	if not require(main.army_panel.handle_node_click(via_target, false), "second plain click handled"): return
	if not require(army.units[unit_id].next_site == next_before and army.units[unit_id].orders.slice(0, queued_before.size()) == queued_before and grid.cell_at(army.node_point(army.units[unit_id].orders.back())) == origin_cell + Vector2i(3, 1), "second plain click preserves first destination as a waypoint"): return
	main.army_panel.handle_node_click(via_target, false)
	if not require(army.units[unit_id].orders.is_empty() and army.units[unit_id].next_site.is_empty(), "repeat destination click cancels movement before departure"): return
	main.army_panel.handle_node_click(click_target, false)
	main.army_panel.handle_node_click(click_target, false)
	if not require(army.units[unit_id].orders.is_empty() and army.units[unit_id].next_site.is_empty(), "a then a cancels the original destination"): return
	var right_click := mouse_button(click_screen, true)
	right_click.button_index = MOUSE_BUTTON_RIGHT
	main._input(right_click)
	if not require(main.army_panel.unit_id.is_empty() and army.selected_id.is_empty() and not main.army_panel.panel.visible, "right click clears unit selection and panel"): return
	main.army_panel.show_unit(unit_id)
	for index in 2:
		var touch := InputEventScreenTouch.new()
		touch.index = index; touch.pressed = true; touch.position = click_screen + Vector2(index * 30, 0)
		main._input(touch)
	if not require(main.army_panel.unit_id == unit_id and army.selected_id == unit_id and main.suppress_touch_mouse, "two fingers preserve selection and suppress synthesized mouse"): return
	var touch_facing: float = army.units[unit_id].facing
	var turn := InputEventScreenDrag.new()
	turn.index = 1; turn.position = click_screen + Vector2(0, 30)
	main._input(turn)
	if not require(is_equal_approx(angle_difference(touch_facing, army.units[unit_id].facing), PI / 2.0), "two finger twist rotates selected army"): return
	for index in 2:
		var touch := InputEventScreenTouch.new()
		touch.index = index; touch.pressed = false
		main._input(touch)
	var single_touch := InputEventScreenTouch.new()
	single_touch.index = 0; single_touch.pressed = true
	main._input(single_touch)
	if not require(not main.suppress_touch_mouse, "next single touch restores normal input"): return
	single_touch.pressed = false; main._input(single_touch)
	var before_wheel: Vector2 = army.unit_position(army.units[unit_id])
	var zoom_before_wheel: Vector2 = main.camera.zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true; wheel.position = click_screen
	var wheel_facing: float = army.units[unit_id].facing
	main._input(wheel)
	if not require(is_equal_approx(angle_difference(wheel_facing, army.units[unit_id].facing), deg_to_rad(15.0)) and main.camera.zoom == zoom_before_wheel and army.unit_position(army.units[unit_id]) == before_wheel, "wheel rotates in place without zooming"): return
	var bow_unit: Dictionary = army.units[unit_id]
	bow_unit.facing = 0.0; bow_unit.movement_hold = false
	var bow_point: Vector2 = army.unit_position(bow_unit)
	var front: Dictionary = army.bow_profile(bow_unit, bow_point + Vector2.UP * army.BOW_RANGE)
	var side_profile: Dictionary = army.bow_profile(bow_unit, bow_point + Vector2.RIGHT * army.BOW_RANGE)
	var rear: Dictionary = army.bow_profile(bow_unit, bow_point + Vector2.DOWN * army.BOW_RANGE)
	if not require(front.in_range and not army.bow_profile(bow_unit, bow_point + Vector2.UP * (army.BOW_RANGE + 0.01)).in_range, "bow range includes exactly 1.5 tile spacings"): return
	if not require(front.accuracy > side_profile.accuracy and side_profile.accuracy > rear.accuracy and front.arrows > side_profile.arrows and side_profile.arrows > rear.arrows and front.reload < side_profile.reload and side_profile.reload < rear.reload, "front flank rear affect all firing parameters"): return
	if not require(rear.arrows < front.arrows * 0.04, "rear fires almost no arrows"): return
	if not require(army.order(unit_id, click_target), "resume movement for bow test"): return
	bow_unit.progress = 0.35
	var march_position: Vector2 = army.unit_position(bow_unit)
	var march_target: Vector2 = march_position + Vector2.UP.rotated(bow_unit.facing) * army.BOW_RANGE
	var moving_profile: Dictionary = army.bow_profile(bow_unit, march_target)
	army.rotate_unit(unit_id, 0.0)
	var held_profile: Dictionary = army.bow_profile(bow_unit, march_target)
	army._march_step(0.1)
	if not require(army.unit_position(bow_unit) == march_position and held_profile.accuracy > moving_profile.accuracy and held_profile.arrows > moving_profile.arrows and held_profile.reload < moving_profile.reload, "rotation holds mid-leg position and improves all firing parameters"): return
	if not require(session.save_game(main, 1) == OK, "bow state saves"): return
	var bow_save: Dictionary = session.read_save(1)
	if not require(bow_save.armies.units[unit_id].movement_hold and is_equal_approx(bow_save.armies.units[unit_id].facing, bow_unit.facing) and is_equal_approx(bow_save.armies.units[unit_id].progress, 0.35), "facing and mid-leg hold survive save load"): return
	var original_units: Dictionary = army.units.duplicate(true)
	var shooter: Dictionary = bow_unit.duplicate(true)
	shooter.site_id = grid.key(origin_cell); shooter.next_site = ""; shooter.orders = []; shooter.progress = 0.0; shooter.facing = PI / 2.0
	shooter.soldiers = 1000; shooter.bow_reload = 0.0; shooter.bow_damage = 0.0
	var victim: Dictionary = shooter.duplicate(true)
	victim.house_id = enemy_house_for_color; victim.site_id = grid.key(origin_cell + Vector2i(1, 0)); victim.facing = PI / 2.0
	army.units = {"shooter":shooter, "victim":victim}
	army._bow_step(army.MOVE_STEP)
	if not require(victim.soldiers < 1000 and shooter.soldiers == 1000 and shooter.bow_reload > 0.0, "enemy in front takes arrow damage while rear return fire is negligible"): return
	var victim_after: int = victim.soldiers
	army._bow_step(army.MOVE_STEP)
	if not require(victim.soldiers == victim_after, "reloading prevents another volley"): return
	victim.site_id = grid.key(origin_cell + Vector2i(2, 0)); shooter.bow_reload = 0.0
	army._bow_step(1.0)
	if not require(victim.soldiers == victim_after and is_zero_approx(shooter.bow_reload), "enemy beyond range cannot be fired upon"): return
	victim.site_id = grid.key(origin_cell + Vector2i(1, 0)); victim.house_id = ally_house
	army._bow_step(1.0)
	if not require(victim.soldiers == victim_after and is_zero_approx(shooter.bow_reload), "no volley is fired when only allied armies are in range"): return
	var blocker: Dictionary = shooter.duplicate(true)
	blocker.site_id = shooter.site_id; blocker.next_site = victim.site_id; blocker.progress = 0.5
	blocker.movement_hold = true; blocker.bow_reload = 10.0; blocker.bow_damage = 0.0
	victim.house_id = enemy_house_for_color; victim.soldiers = 1000; victim.bow_reload = 10.0; victim.bow_damage = 0.0
	shooter.bow_reload = 0.0; shooter.bow_damage = 0.0
	army.units = {"shooter":shooter, "blocker":blocker, "victim":victim}
	army._bow_step(army.MOVE_STEP)
	if not require(blocker.soldiers < 1000 and victim.soldiers == 1000 and shooter.soldiers == 1000, "own army between shooter and enemy intercepts arrows without damaging the firing unit"): return
	blocker.house_id = ally_house; blocker.soldiers = 1000; blocker.bow_damage = 0.0
	shooter.bow_reload = 0.0
	army._bow_step(army.MOVE_STEP)
	if not require(blocker.soldiers < 1000 and victim.soldiers == 1000, "allied army in the line of fire also intercepts arrows"): return
	blocker.site_id = grid.key(origin_cell + Vector2i(0, 1)); blocker.next_site = ""; blocker.progress = 0.0
	var collateral_profile: Dictionary = army.bow_profile(shooter, army.unit_position(victim))
	var clear_hits: Dictionary = army._bow_volley_hits("shooter", "victim", collateral_profile)
	if not require(clear_hits.has("victim") and not clear_hits.has("blocker"), "allied army outside the arrow path is unharmed"): return
	blocker.site_id = grid.key(origin_cell + Vector2i(2, 0))
	var behind_hits: Dictionary = army._bow_volley_hits("shooter", "victim", collateral_profile)
	if not require(behind_hits.has("victim") and not behind_hits.has("blocker"), "arrows stop at the enemy rather than damaging armies behind it"): return
	blocker.site_id = victim.site_id
	var overlapping_hits: Dictionary = army._bow_volley_hits("shooter", "victim", collateral_profile)
	if not require(overlapping_hits.has("blocker") and overlapping_hits.has("victim") and is_equal_approx(overlapping_hits.blocker, overlapping_hits.victim), "allies overlapping the enemy share arrow hits"): return
	army.units = {"victim":victim, "blocker":blocker, "shooter":shooter}
	if not require(army._bow_volley_hits("shooter", "victim", collateral_profile) == overlapping_hits, "overlapping hits are independent of unit iteration order"): return
	# A formation clipping only the edge of the fan intercepts part of the volley.
	blocker.site_id = shooter.site_id; blocker.next_site = grid.key(origin_cell + Vector2i(0, 1)); blocker.progress = 0.3
	var partial_hits: Dictionary = army._bow_volley_hits("shooter", "victim", collateral_profile)
	if not require(partial_hits.has("blocker") and partial_hits.has("victim"), "partial obstruction splits the volley between ally and enemy"): return
	if not test_melee(main, army, shooter, enemy_house_for_color, ally_house): return
	army.units = original_units
	army.units[unit_id].melee_damage = 0.375
	if not require(session.save_game(main, 1) == OK and is_equal_approx(session.read_save(1).armies.units[unit_id].melee_damage, 0.375), "fractional melee damage survives current save and load"): return
	army.units[unit_id].melee_damage = 0.0
	army.units[unit_id].movement_hold = false; army.units[unit_id].progress = 0.0
	main.army_panel.show_unit(unit_id)
	army.units[unit_id].next_site = ""
	army.units[unit_id].orders.clear()
	var first_drag_cell := Vector2i.ZERO
	var second_drag_cell := Vector2i.ZERO
	var neighbors := [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(0,-1), Vector2i(1,-1)]
	for offset in neighbors:
		var first: Vector2i = origin_cell + offset
		if not main.hex_tile_layer.visible_cells.has(first): continue
		for next_offset in neighbors:
			var second: Vector2i = first + next_offset
			if main.hex_tile_layer.visible_cells.has(second) and grid.distance(origin_cell, second) == 2:
				first_drag_cell = first
				second_drag_cell = second
				break
		if second_drag_cell != Vector2i.ZERO: break
	if not require(second_drag_cell != Vector2i.ZERO, "two adjacent land tiles available for dragging"): return
	var icon_screen := map_screen(main, army.unit_position(army.units[unit_id]))
	var first_screen := map_screen(main, grid.center(first_drag_cell))
	var second_screen := map_screen(main, grid.center(second_drag_cell))
	main._unhandled_input(mouse_button(icon_screen, true))
	for point in [first_screen, second_screen]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.relative = point - icon_screen
		main._unhandled_input(motion)
	main._unhandled_input(mouse_button(second_screen, false))
	if not require(army.units[unit_id].next_site == grid.key(first_drag_cell) and grid.cell_at(army.node_point(army.units[unit_id].orders.back())) == second_drag_cell, "dragging the unit draws its actual route"): return
	army.units[unit_id].next_site = ""
	army.units[unit_id].orders.clear()
	main._unhandled_input(mouse_button(icon_screen, true))
	for point in [first_screen, second_screen, first_screen]:
		var motion := InputEventMouseMotion.new()
		motion.position = point; motion.relative = point - icon_screen
		main._unhandled_input(motion)
	if not require(main.drag_route.size() == 2 and main.drag_route.back() == grid.key(first_drag_cell), "drag a b c b trims the preview to a b"): return
	main._unhandled_input(mouse_button(first_screen, false))
	if not require(grid.cell_at(army.node_point(army.units[unit_id].next_site)) == first_drag_cell and army.units[unit_id].orders.is_empty(), "drag a b c b commits only a b"): return
	army.units[unit_id].next_site = ""
	main._unhandled_input(mouse_button(icon_screen, true))
	for point in [first_screen, icon_screen]:
		var motion := InputEventMouseMotion.new()
		motion.position = point; motion.relative = point - icon_screen
		main._unhandled_input(motion)
	main._unhandled_input(mouse_button(icon_screen, false))
	if not require(army.units[unit_id].next_site.is_empty() and army.units[unit_id].orders.is_empty(), "drag back to the origin cancels the entire route"): return
	var restored_route: Array[String] = [grid.key(first_drag_cell), grid.key(second_drag_cell)]
	army.order_path(unit_id, restored_route)
	await process_frame
	await capture("army_route")
	main.army_panel.hide_panel()
	army.units[unit_id].next_site = ""
	army.units[unit_id].orders.clear()
	main.camera.zoom = Vector2.ONE * 1.99
	main.hex_tile_layer.update_view(main.get_visible_world_rect(), main.camera.zoom.x)
	if not require(not main.hex_tile_layer.visible, "hex grid hidden below 200 percent"): return
	if not require(not main.shared_road_layer.is_visible_in_tree(), "roads hidden below 200 percent"): return
	await process_frame
	await capture("hex_below_200")
	main.camera.zoom = Vector2.ONE * 2.0
	main.hex_tile_layer.update_view(main.get_visible_world_rect(), main.camera.zoom.x)
	if not require(main.hex_tile_layer.visible, "hex grid shown at 200 percent"): return
	if not require(main.hex_tile_layer.terrain_legend.visible, "terrain legend shown at 200 percent"): return
	if not require(main.shared_road_layer.is_visible_in_tree() or main.developer_tools.road_layer.is_visible_in_tree(), "roads visible at 200 percent"): return
	await process_frame
	await capture("hex_tiles")
	main.hex_tile_layer.update_view(main.get_visible_world_rect(), 1.99)
	if not require(not main.hex_tile_layer.visible, "zooming out hides the grid again"): return
	if not require(not main.hex_tile_layer.terrain_legend.visible, "terrain legend hidden below 200 percent"): return
	main.hex_tile_layer.update_view(main.get_visible_world_rect(), main.camera.zoom.x)
	main.camera.position.y -= 400
	main.hex_tile_layer.update_view(main.get_visible_world_rect(), main.camera.zoom.x)
	await process_frame
	await capture("hex_offshore")
	for key in main.district_buildings.historical_facilities:
		var has_port := false
		for site_id in main.district_buildings.existing_facilities(key):
			if "port" in main.governance_registry.sites[site_id].roles: has_port = true
		if has_port:
			main.show_district_info(key)
			await process_frame
			await capture("hex_district_facilities")
			main.district_info.hide_info()
			break
	var target: String = army.graph["district:" + district_id][0]
	main.governance_registry.sites[target].house_id = house_id
	if not require(army.order(unit_id, target), "hex target accepted"): return
	army._march_step(1000.0)
	if not require(army.units[unit_id].site_id == target, "unit reaches the next site"): return
	if not require(army.return_home(unit_id), "return order accepted"): return
	army._march_step(1000.0)
	if not require(not army.units.has(unit_id) and district.sortie_troops == starting, "return restores district troops"): return
	var enemy_site := ""
	var occupation_id := ""
	for candidate in army.garrisons:
		if candidate != target: enemy_site = candidate; break
	if not enemy_site.is_empty():
		var enemy_house := "hojo" if house_id != "hojo" else "takeda"
		main.governance_registry.sites[enemy_site].house_id = enemy_house
		session.relations[session.pair(house_id, enemy_house)] = "enemy"
		army.garrisons[enemy_site] = 10
		var attack_id: String = army.dispatch(district_id, [officer_ids[0]], 25, false, false)
		if not require(not attack_id.is_empty(), "attack unit dispatched"): return
		# Isolate siege arithmetic from route travel, which was tested above.
		army.units[attack_id].site_id = enemy_site
		army._besiege(attack_id)
		if not require(main.governance_registry.sites[enemy_site].house_id == house_id, "enemy castle captured after siege"): return
		occupation_id = attack_id
	var enemy_district := ""
	for candidate in main.district_office_layer.records:
		if main.governance_registry.districts[candidate].house_id != house_id:
			enemy_district = candidate
			break
	if not require(not enemy_district.is_empty(), "enemy office exists"): return
	var defender_house: String = main.governance_registry.districts[enemy_district].house_id
	session.relations[session.pair(house_id, defender_house)] = "enemy"
	var office_node := "district:" + enemy_district
	if not require(army.target_at(main.district_office_layer.office_point(enemy_district)) == office_node, "office tile is a route target"): return
	if occupation_id.is_empty(): occupation_id = army.dispatch(district_id, [officer_ids[0]], 25, false, false)
	if not require(not occupation_id.is_empty(), "occupation unit dispatched"): return
	army.units[occupation_id].site_id = office_node
	army.office_defenses[enemy_district] = 25
	army._arrive(occupation_id)
	if not require(army.occupying_house(enemy_district) == house_id and main.governance_registry.districts[enemy_district].house_id == defender_house, "office arrival starts occupation without immediate capture"): return
	main.army_panel.show_unit(occupation_id)
	main.camera.position = Vector2(4096, 4096)
	main.camera.zoom = Vector2.ONE * 2.0
	var pan_start: Vector2 = main.camera.position
	var pan_point := Vector2(900, 550)
	main._unhandled_input(mouse_button(pan_point, true))
	var pan_motion := InputEventMouseMotion.new()
	pan_motion.position = pan_point + Vector2(80, 0)
	pan_motion.relative = Vector2(80, 0)
	main._unhandled_input(pan_motion)
	main._unhandled_input(mouse_button(pan_motion.position, false))
	if not require(main.camera.position.x < pan_start.x - 20 and not main.dragging, "map still pans while an office is occupied"): return
	main._unhandled_input(mouse_button(pan_point, true))
	main._input(mouse_button(pan_point, false))
	main._reset_stale_drag()
	if not require(not main.dragging, "GUI-consumed mouse release clears stale map dragging"): return
	main.army_panel.hide_panel()
	var occupation_save: Dictionary = session.capture(main)
	if not require(session.validate(occupation_save) and int(occupation_save.armies.office_defenses[enemy_district]) == 25, "occupation defense is saved and validated"): return
	if not require(session.save_game(main, 1) == OK and int(session.read_save(1).armies.office_defenses[enemy_district]) == 25, "occupation defense round trips through a save file"): return
	army.on_day_advanced(1546, 2, 2)
	if not require(int(army.office_defenses[enemy_district]) > 0 and int(army.office_defenses[enemy_district]) < 25 and main.governance_registry.districts[enemy_district].house_id == defender_house, "partial office damage keeps occupation in progress"): return
	for day in range(3, 10):
		if int(army.office_defenses[enemy_district]) == 0: break
		army.on_day_advanced(1546, 2, day)
	if not require(int(army.office_defenses[enemy_district]) == 0 and main.governance_registry.districts[enemy_district].house_id == house_id, "office defense reaching zero captures the district"): return
	if not require(army.occupying_house(enemy_district).is_empty(), "occupation ends after capture"): return
	for site_id in main.governance_registry.districts[enemy_district].get("site_ids", []):
		if not require(main.governance_registry.sites[site_id].house_id == house_id, "office capture transfers district buildings"): return
	var saved: Dictionary = session.capture(main)
	if not require(session.validate(saved), "army state validates for save"): return
	await process_frame
	await process_frame
	print("Army campaign dispatch, hex movement, return and save passed")
	quit(0)
