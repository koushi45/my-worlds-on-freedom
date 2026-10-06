extends SceneTree
var failures := 0
var main: Node
var orders: Node
var session: Node
var house: String
var officer: String
var record: Dictionary

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func reset() -> void:
	for id in orders.districts.keys(): orders.finish(id)
	orders.drills.clear()
	main.army_campaign.units.clear()
	record.occupation_stability = 100.0
	record.autonomy = 0
	record.devastation = 0
	record.security = 50
	record.tax_rate = 40
	record.sortie_troops = main.district_actions.sortie_capacity(record)
	main.retainer_management.technology[house] = {"governance":10000.0,"diplomacy":10000.0,"military":10000.0}
	main.district_economy.house_resources[house].money = 10000
	main.district_economy.house_resources[house].provisions = 100000
func days(count: int) -> void:
	for i in count:
		main.game_clock.day += 1
		if main.game_clock.day > main.game_clock.days_in_month(main.game_clock.year,main.game_clock.month):
			main.game_clock.day = 1
			main.game_clock.month += 1
			if main.game_clock.month > 12:
				main.game_clock.month = 1
				main.game_clock.year += 1
		main.game_clock.elapsed_days += 1
	orders.advance()
func click_control(control: Control) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = control.get_global_rect().get_center()
	root.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)

func run() -> void:
	change_scene_to_file("res://scenes/start/start.tscn")
	await process_frame
	await process_frame
	current_scene.show_houses()
	current_scene.select_house(current_scene.house_ids.find("uesugi_yamanouchi"))
	current_scene.begin()
	var deadline := Time.get_ticks_msec()+45000
	while (not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized) and Time.get_ticks_msec()<deadline: await process_frame
	if not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized:
		check(false, "map initializes"); quit(1); return
	main = current_scene
	main.game_clock.set_process(false)
	main.cpu_controller.set_process(false)
	paused = true
	orders = main.technology_orders
	session = root.get_node("GameSession")
	house = session.player_house
	officer = main.retainer_management.officers_for_house(house)[0]
	for r in main.governance_registry.districts.values():
		if r.house_id == house and main.district_actions.sortie_capacity(r) >= 200: record = r; break
	check(not record.is_empty(), "district fixture")
	if record.is_empty(): quit(1); return
	record.governor = null
	reset()
	record.occupation_stability = 10.0
	var base: float = main.army_campaign.stability_rate(record.id)
	check(orders.start(record.id,"integration",house) == OK, "integration accepted without governor or officer")
	check(not orders.districts[record.id].has("officer"), "command state has no officer assignment")
	check(is_equal_approx(main.army_campaign.stability_rate(record.id),base*1.5),"integration accelerates actual stabilization")
	check(main.retainer_management.technology[house].governance == 9880 and main.district_economy.house_resources[house].money == 9940,"costs paid once")
	check(orders.start(record.id,"patrol",house) != OK,"duplicate command rejected")
	main.retainer_management.place_officer(house,officer,record.id)
	check(officer in main.army_campaign.available_officers(record.id),"technology command does not block officer sortie")
	days(90)
	check(not orders.districts.has(record.id) and is_equal_approx(main.army_campaign.stability_rate(record.id),base),"integration expires")
	reset()
	var security: int = main.technology_tree.security_for(record)
	check(orders.start(record.id,"patrol",house) == OK,"patrol accepted")
	check(main.technology_tree.security_for(record) == security,"patrol requires preparation")
	days(30)
	check(main.technology_tree.security_for(record) == security+15,"patrol actual security bonus")
	main.district_actions.set_tax_rate(record.id,house,60)
	check(main.technology_tree.security_for(record) == security-5,"heavy tax still reduces security")
	days(90)
	check(main.technology_tree.security_for(record) == security-20,"patrol expires without permanent security accumulation")
	reset()
	record.agriculture_developer_id = null
	record.commerce_developer_id = null
	check(orders.start(record.id,"development",house) == OK,"development starts with neither field assigned")
	orders.finish(record.id)
	record.agriculture_developer_id = officer
	check(orders.start(record.id,"development",house) == OK,"development accepted")
	var before: float = record.agriculture_progress
	var progress: int = main.district_economy.politics_for(officer)
	main.district_economy.develop(record,"agriculture")
	check(is_equal_approx(float(record.agriculture_progress)-before,progress*1.5),"actual agriculture progress accelerated")
	before = record.commerce_progress
	main.district_economy.develop(record,"commerce")
	check(is_equal_approx(float(record.commerce_progress)-before, main.district_economy.politics_for(main.retainer_management.ruler_id(house))*1.5),"command develops unassigned field with ruler politics")
	record.commerce_developer_id = officer
	before = record.commerce_progress
	main.district_economy.develop(record,"commerce")
	check(is_equal_approx(float(record.commerce_progress)-before,progress*1.5),"commerce progress accelerated")
	record.agriculture_progress = 5399.0
	main.district_economy.develop(record,"agriculture")
	check(record.agriculture_progress <= 5400 and record.agriculture_development <= 30,"development cap preserved")
	reset()
	record.devastation = 80
	var income_before: int = main.district_economy.income_for(record,"agriculture")
	check(orders.start(record.id,"recovery",house) == OK,"recovery accepted")
	check(record.devastation == 80,"recovery not instant")
	days(30)
	check(record.devastation == 60 and main.district_economy.income_for(record,"agriculture") >= income_before,"recovery restores actual production gradually")
	orders.advance()
	check(record.devastation == 60,"same day cannot recover twice")
	days(60)
	check(record.devastation == 20 and not orders.districts.has(record.id),"final recovery tick occurs before expiration")
	reset()
	record.occupation_stability = 10.0
	record.autonomy = 30
	record.tax_rate = 60
	check(orders.start(record.id,"negotiation",house) == OK,"negotiation accepted")
	days(29)
	check(record.tax_rate == 60 and record.occupation_stability == 10,"negotiation is delayed")
	days(1)
	check(record.tax_rate == 30 and record.occupation_stability == 30 and record.autonomy == 10,"negotiation agreement and concessions applied")
	check(main.district_actions.set_tax_rate(record.id,house,40) != OK,"tax promise cannot be violated")
	orders.advance()
	check(record.occupation_stability == 30,"one-time agreement not applied twice")
	days(180)
	check(record.tax_rate == 60 and main.district_actions.set_tax_rate(record.id,house,40) == OK,"tax restored when agreement ends")
	reset()
	check(orders.start(record.id,"defense",house) == OK,"defense accepted")
	check(orders.defense_multiplier(record.id) == 1.0,"defense preparation enforced")
	days(30)
	check(orders.defense_multiplier(record.id) == 1.25,"defense active")
	record.sortie_troops = 0
	var garrisons: Dictionary = main.army_campaign.garrisons.duplicate(true)
	for site in record.get("site_ids",[]): main.army_campaign.garrisons[site] = 0
	check(orders.defense_multiplier(record.id) == 1.0,"defense requires real garrison")
	main.army_campaign.garrisons = garrisons
	reset()
	main.retainer_management.technology[house].governance = 0
	var resources_before: Dictionary = main.district_economy.house_resources[house].duplicate(true)
	check(orders.start(record.id,"patrol",house) != OK and main.district_economy.house_resources[house] == resources_before,"insufficient points do not charge resources")
	reset()
	var id: String = main.army_campaign.dispatch_for_house(house,record.id,[officer],100,false,false)
	check(not id.is_empty(),"training formation created")
	if id.is_empty(): quit(1); return
	var u: Dictionary = main.army_campaign.units[id]
	var food: int = main.district_economy.house_resources[house].provisions
	var combat_before: float = main.army_campaign.melee_power(u,1.0)
	check(orders.start_drill(id,house) == OK,"training accepted")
	check(main.district_economy.house_resources[house].provisions == food-ceili(int(u.soldiers)*0.1),"training consumes food")
	check(orders.combat_multiplier(u) == 1.0 and orders.training(id),"training requires 14 days")
	check(not main.army_campaign.order_for_house(house,id,u.origin),"training blocks movement")
	check(not main.army_campaign.return_home_for_house(house,id),"training blocks disbanding")
	days(14)
	check(is_equal_approx(main.army_campaign.melee_power(u,1.0),combat_before*1.15),"training boosts real combat power")
	check(orders.defense_multiplier(record.id) == 1.0,"training gives no district fortification")
	var other: Dictionary = u.duplicate(true)
	other.id = "army_99999"
	other.officers = [main.retainer_management.officers_for_house(house)[1]]
	other.officer_pool = other.officers.duplicate()
	main.army_campaign.units[other.id] = other
	check(main.army_campaign.merge(id,other.id),"trained and untrained armies merge")
	check(is_equal_approx(orders.combat_multiplier(u),1.075),"untrained reinforcements dilute training")
	# Simultaneous saved preparation, active treaty, and completed training.
	record.occupation_stability = 10
	record.tax_rate = 60
	var diplomat: String = main.retainer_management.officers_for_house(house)[2]
	check(orders.start(record.id,"negotiation",house) == OK,"save fixture treaty starts")
	days(30)
	var second_id := ""
	for r in main.governance_registry.districts.values():
		if r.house_id == house and r.id != record.id and main.district_actions.sortie_capacity(r) >= 100: second_id = r.id; break
	var helper: String = main.retainer_management.officers_for_house(house)[3]
	check(orders.start(second_id,"defense",house) == OK,"save fixture preparation starts")
	var data: Dictionary = session.capture(main)
	check(data.version == 30 and session.validate(data),"current save validates commands and training")
	var bad: Dictionary = data.duplicate(true)
	bad.technology_orders.drills[id].soldiers = -1
	check(not session.validate(bad),"malformed training save rejected")
	session.save_directory = "user://technology_order_qa"
	check(session.save_game(main,1) == OK,"disk save succeeds")
	var loaded: Dictionary = session.read_save(1)
	check(not loaded.is_empty(),"disk load validates")
	orders.districts.clear(); orders.drills.clear()
	session.pending = loaded
	session.apply_to(main)
	check(orders.active(record.id,"negotiation") and record.tax_rate == 30 and is_equal_approx(orders.combat_multiplier(main.army_campaign.units[id]),1.075),"disk reload restores treaty and diluted training")
	check(orders.districts.has(second_id) and not orders.active(second_id,"defense"),"disk reload preserves unfinished preparation")
	days(60)
	check(orders.combat_multiplier(main.army_campaign.units[id]) == 1.0,"training duration expires")
	reset()
	main.game_menu.toggle_district_management()
	var panel: Control = main.game_menu.district_management_panel
	panel.open()
	panel._select_index(panel.district_ids.find(record.id))
	panel._select_tab(4)
	check(panel.tabs.size() == 5,"technology orders tab accessible")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/technology_orders.png")
	check(panel.technology_buttons.size() == 6,"all district commands are inline buttons")
	await process_frame
	var points_before: float = main.retainer_management.technology[house].governance
	var money_before: float = main.district_economy.house_resources[house].money
	click_control(panel.technology_buttons.patrol)
	await process_frame
	check(orders.districts.has(record.id) and orders.districts[record.id].kind == "patrol" and not panel.choices.visible, "one click runs command in selected district without selector")
	check(main.retainer_management.technology[house].governance == points_before-orders.point_cost(house,60) and main.district_economy.house_resources[house].money == money_before-20, "inline command pays correct costs once")
	click_control(panel.technology_buttons.patrol)
	await process_frame
	check(main.district_economy.house_resources[house].money == money_before-20, "disabled duplicate command does not double charge")
	check(not orders.summary(record.id).contains("担当"), "command summary has no officer")
	var officerless: Dictionary = session.capture(main)
	check(session.validate(officerless) and not officerless.technology_orders.districts[record.id].has("officer"), "officerless command saves in current format")
	orders.districts.clear()
	session.pending = officerless
	session.apply_to(main)
	check(orders.valid_job(record.id), "officerless command survives reload")
	await create_timer(0.5, true).timeout
	print("TECHNOLOGY ORDER CHECKS: ",failures)
	quit(0 if failures == 0 else 1)
