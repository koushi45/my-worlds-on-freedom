extends SceneTree
const Grid = preload("res://scripts/map/hex_grid.gd")
var failures := 0
var main: Node2D
var session: Node
var homes: Dictionary = {}
var actors := ["uesugi_yamanouchi", "takeda", "hojo", "imagawa"]

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func fixture() -> void:
	main.cpu_controller.work_queue.clear()
	main.cpu_controller.route_budget_active = false
	session.relations.clear()
	main.diplomacy.wars.clear()
	main.diplomacy.envoys.clear()
	main.diplomacy.opinions.clear()
	main.diplomacy.truces.clear()
	main.diplomacy.last_actions.clear()
	main.army_campaign.units.clear()
	main.army_campaign.route_obstacles.clear()
	main.cpu_controller.plans.clear()
	main.cpu_controller.missions.clear()
	main.cpu_controller.route_cache.clear()
	main.cpu_controller.topology_signature = ""
	for record in main.governance_registry.districts.values(): record.sortie_troops = 0
	for house in main.district_economy.house_resources:
		main.district_economy.house_resources[house].provisions = 0
	for house in actors:
		var record: Dictionary = main.governance_registry.districts[homes[house]]
		record.house_id = house
		record.ruler = main.governance_registry.houses[house].ruler.duplicate(true)
		record.governor = null
		record.population = 120000
		record.sortie_troops = 6000
		main.district_economy.house_resources[house] = {"money":1000, "provisions":10000}
		var officer: String = main.retainer_management.ruler_id(house)
		main.retainer_management.officer_districts[officer] = homes[house]
	main.retainer_management.reconcile_officer_placements()
	main.cpu_controller.refresh_world()
	for house in actors:
		for other in main.cpu_controller.nearby.get(house, {}).keys():
			if other not in actors: main.cpu_controller.nearby[house].erase(other)

func run() -> void:
	session = root.get_node("GameSession")
	session.player_house = actors[0]
	session.save_directory = "user://qa_cpu_%d" % OS.get_process_id()
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized): await process_frame
	check(current_scene != null and current_scene.initialized, "map initializes with CPU")
	if current_scene == null or not current_scene.initialized: quit(1); return
	main = current_scene
	main.game_clock.set_process(false)
	main.army_campaign.set_process(false)
	main.cpu_controller.enabled = false
	var cpu: Node = main.cpu_controller
	var army: Node2D = main.army_campaign
	var diplomacy: Node = main.diplomacy
	# Use four actual nearby passable offices, preserving real terrain/pathfinding.
	var locations: Array = []
	for district_id in main.governance_registry.districts:
		var node: String = "district:" + district_id
		var anchor: Vector2 = army.node_point(node)
		if not main.hex_tile_layer.can_enter(Grid.cell_at(anchor)): continue
		var group: Array = [district_id]
		for candidate in main.governance_registry.districts:
			if candidate == district_id: continue
			var point: Vector2 = army.node_point("district:" + candidate)
			if point.distance_to(anchor) > 60 or not main.hex_tile_layer.can_enter(Grid.cell_at(point)): continue
			if army.route(node, "district:" + candidate).is_empty(): continue
			group.append(candidate)
			if group.size() == 4: break
		if group.size() == 4: locations = group; break
	check(locations.size() == 4, "four connected frontier offices found")
	if locations.size() != 4: quit(1); return
	for i in range(actors.size()): homes[actors[i]] = locations[i]
	fixture()
	diplomacy._set_relation("takeda", "hojo", "ally")
	diplomacy._set_relation("hojo", "imagawa", "ally")
	check(diplomacy.act("war", actors[0], "takeda") == OK, "player declares war")
	check(session.relation(actors[0], "hojo") == "enemy", "defender calls direct CPU ally into war")
	check(session.relation(actors[0], "imagawa") == "neutral", "alliance requests do not recursively cascade")
	check(cpu.plan_for("takeda").objective == "defend", "declaration triggers immediate defense purpose")
	cpu.refresh_world()
	cpu.choose_strategy("takeda")
	cpu.choose_strategy("hojo")
	army.selected_id = "player_selection"
	var supplies: int = main.district_economy.house_resources.hojo.provisions
	cpu.command_armies("takeda")
	cpu.command_armies("hojo")
	var defender_unit := ""
	var ally_unit := ""
	for unit in army.units.values():
		if unit.house_id == "takeda": defender_unit = unit.id
		if unit.house_id == "hojo": ally_unit = unit.id
	check(not defender_unit.is_empty() and not ally_unit.is_empty(), "defender and ally both dispatch real armies")
	if ally_unit.is_empty(): quit(1); return
	check(main.district_economy.house_resources.hojo.provisions < supplies, "CPU departure pays provisions")
	check(army.selected_id == "player_selection", "CPU commands preserve player selection")
	check(not army.order(ally_unit, "district:" + homes[actors[0]]), "player cannot issue orders to CPU army")
	var before: Vector2 = army.unit_position(army.units[ally_unit])
	army._march_step(0.5)
	check(army.unit_position(army.units[ally_unit]).distance_to(before) > 0, "allied army actually marches")
	army.units[ally_unit].supply_days = 1
	cpu.refresh_world()
	cpu.command_armies("hojo")
	check(cpu.missions[ally_unit].returning, "supply shortage orders withdrawal")
	var saved: Dictionary = session.capture(main)
	check(session.validate(saved), "current CPU/war save validates")
	check(session.save_game(main, 1) == OK, "CPU game saves")
	var loaded: Dictionary = session.read_save(1)
	check(not loaded.is_empty(), "CPU game reads")
	var formations_before: int = army.units.size()
	session.pending = loaded
	session.apply_to(main)
	check(cpu.save_state() == saved.cpu and diplomacy.save_state() == saved.diplomacy, "plans missions requests and war participants restore exactly")
	check(army.units.size() == formations_before, "load duplicates no army")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.diplomacy.wars.values()[0].defenders.append("missing_house")
	check(not session.validate(corrupt), "unknown war participants rejected")
	corrupt = saved.duplicate(true)
	corrupt.cpu.plans.takeda.next_strategy = -1
	check(not session.validate(corrupt), "invalid CPU scheduling rejected")
	diplomacy.finish_peace(actors[0], "takeda")
	check(session.relation(actors[0], "hojo") == "neutral", "root peace also ends allied participation")
	fixture()
	main.governance_registry.districts[homes.hojo].sortie_troops = 500
	cpu.refresh_world()
	cpu.choose_strategy("takeda")
	check(session.relation("takeda", "hojo") == "enemy", "strong CPU actively declares war on weaker reachable house")
	cpu.refresh_world()
	cpu.command_armies("takeda")
	check(not army.units.is_empty(), "CPU offensive dispatches and orders an army")
	fixture()
	main.governance_registry.districts[homes.hojo].sortie_troops = 500
	cpu.refresh_world()
	cpu.seek_alliance("hojo")
	var protector: String = cpu.plan_for("hojo").alliance_target
	check(not protector.is_empty() and diplomacy.envoy_target("hojo") == protector, "weak CPU sends envoy to stronger protector")
	check(diplomacy.opinion(protector, "hojo") == 20, "weak CPU pays a gift to improve relations")
	diplomacy.change_opinion(protector, "hojo", 20)
	diplomacy.last_actions.clear()
	cpu.seek_alliance("hojo")
	check(session.relation("hojo", protector) == "ally", "weak CPU forms alliance when requirements are met")
	fixture()
	main.governance_registry.districts[homes.hojo].sortie_troops = 500
	diplomacy._set_relation("hojo", "imagawa", "ally")
	cpu.refresh_world()
	cpu.choose_strategy("takeda")
	check(session.relation("takeda", "hojo") != "enemy", "strong protector deters an attack on its weak ally")
	fixture()
	diplomacy._set_relation("takeda", "hojo", "ally")
	diplomacy._set_relation(actors[0], "hojo", "ally")
	diplomacy.act("war", actors[0], "takeda")
	check(session.relation(actors[0], "hojo") == "enemy" and session.relation("takeda", "hojo") == "ally", "dual ally honors defense and breaks attacker alliance")
	fixture()
	diplomacy._set_relation("takeda", actors[0], "ally")
	check(diplomacy.act("war", "hojo", "takeda") == OK, "CPU attacks player's ally")
	check(not diplomacy.pending_request(actors[0], "takeda").is_empty(), "player receives an actionable defense request")
	check(main.game_menu.assistance_button.visible, "pending player request is visible in game")
	check(session.relation(actors[0], "hojo") == "neutral", "player is not auto-enrolled")
	check(diplomacy.act("join_war", actors[0], "takeda") == OK and session.relation(actors[0], "hojo") == "enemy", "player may accept shared defense request")
	fixture()
	diplomacy._set_relation("takeda", "hojo", "ally")
	diplomacy.truces[session.pair(actors[0], "hojo")] = int(main.game_clock.elapsed_days) + 1
	diplomacy.act("war", actors[0], "takeda")
	check(diplomacy.pending_request("hojo", "takeda") != "" and session.relation(actors[0], "hojo") != "enemy", "truce delays CPU ally participation")
	await advance_days(main.game_clock, 1)
	diplomacy.on_day_advanced(main.game_clock.year, main.game_clock.month, main.game_clock.day)
	check(session.relation(actors[0], "hojo") == "enemy", "CPU ally joins when truce expires")
	fixture()
	main.retainer_management.technology.takeda.governance = 1000.0
	cpu.refresh_world()
	cpu.manage_house("takeda")
	check(main.district_buildings.state[homes.takeda].construction != null, "CPU starts paid construction")
	check(not main.technology_tree.researched.takeda.governance.is_empty(), "CPU researches using shared points and prerequisites")
	main.district_economy.house_resources.takeda.provisions = 0
	check(army.dispatch_for_house("takeda", homes.takeda, army.available_officers(homes.takeda).slice(0, 1), 25, false, false).is_empty(), "CPU cannot dispatch without supplies")
	if DisplayServer.get_name() != "headless" and "--capture" in OS.get_cmdline_user_args():
		fixture()
		diplomacy._set_relation("takeda", actors[0], "ally")
		diplomacy.act("war", "hojo", "takeda")
		main.game_menu._open_menu(false)
		main.game_menu.show_diplomacy()
		main.game_menu.diplomacy_panel.selected = "takeda"
		main.game_menu.diplomacy_panel._fill_houses()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/cpu_diplomacy.png")
	print("CPU_CONTROLLER_TEST failures=", failures)
	quit(1 if failures else 0)

func advance_days(clock: Node, count: int) -> void:
	for index in range(count):
		var previous: int = clock.elapsed_days
		while clock.elapsed_days == previous:
			clock.advance_real_seconds(1.0 / clock.speed)
			await process_frame
