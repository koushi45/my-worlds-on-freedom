extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	while main.district_buildings == null or main.game_menu == null:
		await process_frame
	main.game_clock.set_process(false)
	var session: Node = root.get_node("/root/GameSession")
	session.player_house = "takeda"
	var id := ""
	for district_id in main.governance_registry.districts:
		if main.governance_registry.districts[district_id].house_id == "takeda" and (id.is_empty() or int(main.governance_registry.districts[district_id].population) > int(main.governance_registry.districts[id].population)):
			id = district_id
	check(not id.is_empty(), "test district found")
	var record: Dictionary = main.governance_registry.districts[id]
	record.population = maxi(100000, int(record.population))
	var buildings: Node = main.district_buildings
	var economy: Node = main.district_economy
	var actions: Node = main.district_actions
	check(int(record.infrastructure) == 1 and int(record.defense) == 1, "district levels begin at one")
	check(actions.upgrade(id, "hojo") == ERR_UNAUTHORIZED, "other house cannot upgrade")
	economy.house_resources.takeda.money = 100
	check(actions.upgrade(id, "takeda") == OK and int(record.infrastructure) == 2 and economy.house_resources.takeda.money == 0, "upgrade pays once and raises level")
	record.devastation = 5
	economy.house_resources.takeda.money = 10
	check(actions.repair(id, "takeda") == OK and int(record.devastation) == 0, "repair clears devastation for money")
	var initial_troops: int = int(record.sortie_troops)
	record.sortie_troops = maxi(0, initial_troops - 100)
	actions.on_day_advanced(1546, 2, 1)
	check(int(record.sortie_troops) > initial_troops - 100, "district sortie pool recovers monthly")
	main.show_district_info(id)
	main.district_info._refresh_buildings()
	check(main.district_info.building_rows.get_child_count() > 0, "district construction UI builds")
	check(buildings.slot_capacity(record) >= 2, "initial construction slots")
	check(buildings.completion_date(1546, 1, 1, 12) == {"year":1547,"month":1,"day":1}, "twelve-month finish date")
	check(buildings.completion_date(1546, 1, 2, 12) == {"year":1547,"month":2,"day":1}, "mid-month finish date")
	check(buildings.start_construction(id, "market", "takeda", 1546, 1, 1) == ERR_UNAVAILABLE, "insufficient money")
	economy.house_resources.takeda.money = 300
	var base_income: int = economy.income_for(record, "commerce")
	check(buildings.start_construction(id, "market", "takeda", 1546, 1, 1) == OK, "start market")
	check(economy.house_resources.takeda.money == 200 and buildings.slots_used(id) == 1 + buildings.existing_facilities(id).size(), "single payment and slot reservation")
	check(buildings.start_construction(id, "market", "takeda", 1546, 1, 1) == ERR_UNAVAILABLE, "duplicate order rejected")
	check(economy.income_for(record, "commerce") == base_income, "construction has no early effect")
	buildings.on_day_advanced(1546, 12, 1)
	check(buildings.state[id].construction != null, "construction not finished early")
	buildings.on_day_advanced(1547, 1, 1)
	check(buildings.state[id].construction == null and buildings.state[id].built == ["market"], "market completes once")
	check(economy.income_for(record, "commerce") > base_income, "completed market increases income")
	buildings.on_day_advanced(1547, 1, 1)
	check(buildings.state[id].built.size() == 1, "completion idempotent")
	main.technology_tree.researched.takeda.agriculture = main.technology_tree.BRANCHES.agriculture.slice(0, 4)
	check(buildings.cost_for(id, "irrigation") == 85, "agricultural research reduces price")
	main.game_clock.year = 1547
	main.game_clock.month = 1
	main.game_clock.day = 2
	main.game_clock.elapsed_days = 366
	check(buildings.start_construction(id, "irrigation", "takeda", 1547, 1, 2) == OK, "start discounted irrigation")
	check(economy.house_resources.takeda.money == 115, "discounted amount paid")
	var old_save_dir: String = session.save_directory
	session.save_directory = "user://tests_buildings"
	check(session.save_game(main, 5) == OK, "current-format save")
	var saved: Dictionary = session.read_save(5)
	check(not saved.is_empty() and saved.buildings[id].construction.paid_cost == 85 and saved.building_history.size() == 3, "current-format load includes construction and payment history")
	check(saved.territories.districts[id].infrastructure == 2 and saved.territories.districts[id].sortie_troops == record.sortie_troops, "district orders survive save and load")
	check(buildings.cancel_construction(id, "takeda") == OK, "cancel construction")
	check(economy.house_resources.takeda.money == 200 and buildings.state[id].construction == null, "refund exact paid amount")
	session.pending = saved
	session.apply_to(main)
	check(buildings.state[id].construction != null and economy.house_resources.takeda.money == 115 and buildings.history.size() == 3, "loaded construction, balance and history restored")
	check(buildings.cancel_construction(id, "takeda") == OK and economy.house_resources.takeda.money == 200, "loaded construction refunds correctly")
	var before_food: int = economy.income_for(record, "agriculture")
	check(buildings.start_construction(id, "irrigation", "takeda", 1547, 1, 2) == OK, "restart irrigation")
	buildings.on_day_advanced(1548, 1, 1)
	check(economy.income_for(record, "agriculture") == before_food, "irrigation does not affect harvest early")
	buildings.on_day_advanced(1548, 2, 1)
	check(economy.income_for(record, "agriculture") > before_food, "completed irrigation increases harvest")
	var other_id := ""
	for district_id in main.governance_registry.districts:
		if district_id != id and main.governance_registry.districts[district_id].house_id == "takeda":
			other_id = district_id
			break
	check(not other_id.is_empty(), "second district found")
	var other: Dictionary = main.governance_registry.districts[other_id]
	var before_security: int = main.technology_tree.security_for(other)
	check(buildings.start_construction(other_id, "office", "takeda", 1548, 2, 1) == OK, "start office")
	other.house_id = "oda"
	buildings.reconcile_owners()
	check(buildings.state[other_id].construction == null and economy.house_resources.takeda.money == 115, "ownership change refunds payer")
	other.house_id = "takeda"
	check(buildings.start_construction(other_id, "office", "takeda", 1548, 2, 1) == OK, "restart office")
	buildings.on_day_advanced(1549, 2, 1)
	check(main.technology_tree.security_for(other) == mini(100, before_security + 5), "completed office adds security")
	main.show_district_info(id)
	main.district_info._slot_pressed("market", false)
	check(main.district_info.building_confirmation.visible, "built slot opens demolition confirmation")
	main.district_info.building_confirmation.confirmed.emit()
	check("market" not in buildings.state[id].built, "building is demolished from its slot")
	var expansion_id := ""
	for district_id in main.governance_registry.districts:
		if district_id != id and district_id != other_id and main.governance_registry.districts[district_id].house_id == "takeda":
			expansion_id = district_id
			break
	check(not expansion_id.is_empty(), "expansion district found")
	if not expansion_id.is_empty():
		var expansion: Dictionary = main.governance_registry.districts[expansion_id]
		expansion.agriculture_development = 30
		expansion.commerce_development = 30
		expansion.population = maxi(100000, int(expansion.population))
		economy.house_resources.takeda.money = 3000
		var original_money: int = economy.income_for(expansion, "commerce")
		var original_food: int = economy.income_for(expansion, "agriculture")
		var original_levy: int = actions.sortie_capacity(expansion)
		for building_id in ["workshop", "temple", "farm_estate", "barracks", "fort"]:
			check(buildings.start_construction(expansion_id, building_id, "takeda", 1550, 1, 1) == OK, "start " + building_id)
			buildings.on_day_advanced(1552, 1, 1)
			check(buildings.state[expansion_id].built.has(building_id), "complete " + building_id)
		check(economy.income_for(expansion, "commerce") > original_money, "new production and taxation buildings increase money")
		check(economy.income_for(expansion, "agriculture") > original_food, "farm estate increases provisions")
		check(actions.sortie_capacity(expansion) > original_levy, "barracks increases sortie capacity")
		check(buildings.defense_bonus(expansion_id) == 3, "fort increases battle defense")
		check(session.save_game(main, 4) == OK, "expanded buildings save")
		var expansion_save: Dictionary = session.read_save(4)
		check(not expansion_save.is_empty() and expansion_save.buildings[expansion_id].built.size() == 5, "expanded buildings load")
		var expansion_path: String = ProjectSettings.globalize_path(session.path_for(4))
		if FileAccess.file_exists(expansion_path): DirAccess.remove_absolute(expansion_path)
	var test_path: String = ProjectSettings.globalize_path(session.path_for(5))
	if FileAccess.file_exists(test_path): DirAccess.remove_absolute(test_path)
	session.save_directory = old_save_dir
	print("District buildings tests: %d failures" % failures)
	quit(0 if failures == 0 else 1)
