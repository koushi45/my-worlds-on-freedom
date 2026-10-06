extends SceneTree

const Grid = preload("res://scripts/map/hex_grid.gd")
var failures := 0
var main: Node
var session: Node

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func place(unit: Dictionary, node: String) -> void:
	unit.site_id = node; unit.next_site = ""; unit.orders.clear(); unit.progress = 0.0
	unit.soldiers = 1000; unit.supply_days = 120; unit.automatic = null

func enemy_fixture(army: Node, template: Dictionary, id: String, cell: Vector2i, soldiers: int) -> void:
	var enemy: Dictionary = template.duplicate(true)
	enemy.id = id; enemy.house_id = "hojo"; enemy.site_id = Grid.key(cell)
	enemy.soldiers = soldiers; enemy.automatic = null
	army.units[id] = enemy

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/qa/" + name + ".png")

func run() -> void:
	session = root.get_node("GameSession")
	session.player_house = "uesugi_yamanouchi"
	session.save_directory = "user://qa_automatic_%d" % OS.get_process_id()
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized): await process_frame
	if current_scene == null or not current_scene.initialized: printerr("FAIL: map initialization"); quit(1); return
	main = current_scene; main.game_clock.paused = true
	main.cpu_controller.enabled = false; main.cpu_controller.work_queue.clear()
	var army: Node = main.army_campaign
	var home := ""
	var targets: Array[String] = []
	for district_id in main.district_office_layer.records:
		var record: Dictionary = main.governance_registry.districts[district_id]
		if record.house_id == session.player_house and not army.available_officers(district_id).is_empty(): home = district_id
		if record.house_id == "hojo": targets.append(district_id)
	if home.is_empty() or targets.size() < 2: printerr("FAIL: automation fixtures"); quit(1); return
	var id: String = army.dispatch(home, [army.available_officers(home)[0]], 25, false, false)
	if id.is_empty(): printerr("FAIL: dispatch: " + army.last_error); quit(1); return
	var unit: Dictionary = army.units[id]
	place(unit, unit.origin)
	var center := Grid.cell_at(army.node_point(unit.origin))
	# Controlled local travel surface: direct river crossing is slower than a plain detour.
	main.cpu_controller.connections.clear()
	for q in range(-6, 7):
		for r in range(-6, 7):
			var cell := center + Vector2i(q, r)
			main.hex_tile_layer.visible_cells[cell] = 0
			main.hex_tile_layer.impassable_cells.erase(cell)
			main.developer_tools.network.cells.erase(cell)
	var slow := center + Vector2i(2, 0)
	var fast := center + Vector2i(0, 3)
	main.hex_tile_layer.visible_cells[center + Vector2i(1, 0)] = 2
	var trip: Dictionary = army.automation.fastest_route(unit.origin, Grid.key(slow), unit.house_id, "hojo", 120)
	check(trip.reachable and is_equal_approx(float(trip.days), 4.5) and trip.path.size() == 3, "weighted route prefers three plain tiles to two tiles through a river")
	main.developer_tools.network.cells[center] = true
	main.developer_tools.network.cells[center + Vector2i(1, 0)] = true
	main.developer_tools.network.cells[slow] = true
	main.developer_tools.network.changed.emit()
	trip = army.automation.fastest_route(unit.origin, Grid.key(slow), unit.house_id, "hojo", 120)
	check(trip.reachable and is_equal_approx(float(trip.days), 2.5) and trip.path.size() == 2, "road edits invalidate cached route and select the new fastest crossing")
	for cell in [center, center + Vector2i(1, 0), slow]: main.developer_tools.network.cells.erase(cell)
	main.developer_tools.network.changed.emit()
	main.hex_tile_layer.visible_cells[slow] = 2
	enemy_fixture(army, unit, "slow_enemy", slow, 100)
	enemy_fixture(army, unit, "fast_enemy", fast, 100)
	enemy_fixture(army, unit, "strong_enemy", center + Vector2i(-3, 0), 5000)
	session.relations[session.pair(unit.house_id, "hojo")] = "enemy"
	check(army.automation.start(id, "battle", "hojo"), "player can issue battle automation")
	check(unit.automatic.target_unit == "fast_enemy" and not unit.automatic.returning, "battle selects minimum travel days rather than minimum hex distance and rejects stronger enemies")
	main.army_panel.show_unit(id)
	await capture("army_automatic_battle")
	main.army_panel._open_automatic()
	check(main.army_panel.automatic_houses.has("hojo") and not main.army_panel.automatic_houses.has(unit.house_id), "dialog offers hostile houses and excludes own house")
	check(main.army_panel.automatic_mode.selected == 1, "dialog preserves battle order selection")
	await capture("army_automatic_dialog")
	main.army_panel.automatic_dialog.hide()
	main.army_panel.automatic_dialog.confirmed.emit()
	check(unit.automatic.mode == "battle" and unit.automatic.house_id == "hojo", "confirming the dialog issues the selected mode and house")
	check(session.save_game(main, 1) == OK, "automatic battle order saves to disk")
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty() and saved.armies.units[id].automatic.target_unit == "fast_enemy", "automatic order, target and initial strength round trip")
	var bad := saved.duplicate(true)
	bad.armies.units[id].automatic.mode = "invalid"
	check(not session.validate(bad), "invalid automatic mode rejected")
	unit.automatic = null
	session.pending = saved; session.relations = saved.relations.duplicate(true); session.apply_to(main)
	unit = army.units[id]
	check(unit.automatic.mode == "battle" and unit.automatic.initial_soldiers == 1000, "loading restores active automation")
	army.automation.advance()
	check(unit.automatic.target_unit == "fast_enemy", "restored order continues selecting the specified house")
	unit.site_id = Grid.key(fast); unit.next_site = ""; unit.orders.clear(); unit.progress = 0.0
	army._march_step(0.5)
	check(not army.units.has("fast_enemy") or int(army.units.fast_enemy.soldiers) < 100, "battle automation attacks the enemy after reaching it")
	unit.site_id = unit.origin
	army._arrive(id)
	check(army.units.has(id), "active battle order does not disband when pursuit reaches its own home office")
	place(unit, unit.origin)
	army.units.erase("fast_enemy"); army.units.erase("slow_enemy"); army.units.erase("strong_enemy")
	# Move two real target offices into the controlled patch for consecutive capture.
	for index in 2:
		var target_cell := center + Vector2i(0, 2 + index * 2)
		main.district_office_layer.records[targets[index]].point = [Grid.center(target_cell).x, Grid.center(target_cell).y]
		main.district_office_layer.records[targets[index]].cell = [target_cell.x, target_cell.y]
		main.district_office_layer.cell_districts[target_cell] = targets[index]
		main.governance_registry.districts[targets[index]].defense = 1
	army.automation.invalidate_routes()
	check(army.automation.start(id, "occupy", "hojo") and not unit.automatic.returning, "player can issue occupation automation")
	var destination: String = unit.orders.back() if not unit.orders.is_empty() else unit.next_site
	check(destination == "district:" + targets[0], "occupation selects reachable nearest target office")
	unit.site_id = destination; unit.next_site = ""; unit.orders.clear(); unit.progress = 0.0
	army._arrive(id); army.occupations[targets[0]].progress = 99.0
	army.on_day_advanced(1546, 1, 2)
	check(main.governance_registry.districts[targets[0]].house_id == unit.house_id and unit.next_site.is_empty(), "automatic army captures and remains to stabilize the district")
	check(unit.automatic.status.contains("安定化"), "occupation status explains stabilization")
	main.governance_registry.districts[targets[0]].occupation_stability = 100.0
	army.automation.advance()
	destination = unit.orders.back() if not unit.orders.is_empty() else unit.next_site
	check(destination == "district:" + targets[1], "after stabilization the army proceeds to another office of the same house")
	unit.site_id = "district:" + targets[1]; unit.next_site = ""; unit.orders.clear(); unit.progress = 0.0
	unit.automatic.mode = "battle"
	army._arrive(id); army._advance_occupations()
	check(not army.occupations.has(targets[1]), "battle automation never captures an office it crosses")
	unit.automatic.mode = "occupy"; unit.supply_days = 14
	army.automation.advance()
	check(unit.automatic.returning and not army.may_capture_office(unit), "low supplies trigger return and cease occupation")
	place(unit, "district:" + targets[1])
	main.governance_registry.districts[targets[1]].defense = 1000
	unit.supply_days = 30
	army.automation.start(id, "occupy", "hojo")
	check(unit.automatic.returning, "occupation returns when office defenses require more food than available")
	main.governance_registry.districts[targets[1]].defense = 1
	place(unit, "district:" + targets[0])
	army.automation.start(id, "occupy", "hojo")
	unit.soldiers = 399; army.automation.advance()
	check(unit.automatic.returning, "loss of more than sixty percent of initial troops triggers return")
	place(unit, "district:" + targets[0])
	army.automation.start(id, "occupy", "hojo")
	main.diplomacy.truces[session.pair(unit.house_id, "hojo")] = main.game_clock.elapsed_days + 10
	army.automation.advance()
	check(unit.automatic.returning and not army.automation.start(id, "battle", "hojo"), "truce stops aggression and prevents new automatic orders")
	main.diplomacy.truces.clear()
	place(unit, "district:" + targets[0])
	army.automation.start(id, "occupy", "hojo")
	check(army.order(id, Grid.key(center + Vector2i(0, 1))) and unit.automatic == null, "manual movement overrides automation")
	place(unit, "district:" + targets[0])
	army.automation.start(id, "occupy", "hojo")
	enemy_fixture(army, unit, "danger", Grid.cell_at(army.unit_position(unit)), 5000)
	army.units.danger.next_site = ""; army.units.danger.orders.clear()
	army.automation.advance()
	check(unit.automatic.returning, "overwhelming local opposition triggers retreat")
	army.units.erase("danger")
	place(unit, "district:" + targets[0])
	enemy_fixture(army, unit, "unbeatable", center + Vector2i(-3, 0), 5000)
	army.automation.start(id, "battle", "hojo")
	check(unit.automatic.returning, "battle returns if no enemy can be beaten")
	army.units.erase("unbeatable")
	place(unit, "district:" + targets[0])
	army.automation.start(id, "occupy", "hojo")
	var other_house: String = main.governance_registry.districts[home].house_id
	main.governance_registry.districts[home].house_id = "oda"
	unit.site_id = "district:" + home
	check(not army.may_capture_office(unit), "automatic occupation cannot capture a house other than the specified target")
	main.governance_registry.districts[home].house_id = other_house
	unit.site_id = "district:" + targets[0]
	army.automation.stop(id)
	check(unit.automatic == null and unit.orders.is_empty(), "explicit cancellation removes automation and its remaining route")
	print("Army automatic occupation, battle, fastest travel, retreat, UI and save checks: %d failures" % failures)
	quit(1 if failures else 0)
