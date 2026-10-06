extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var session: Node = root.get_node("GameSession")
	session.save_directory = "user://qa_commerce_%d" % OS.get_process_id()
	check(session.new_game("takeda") == OK, "new game starts")
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.name == "Main" and current_scene.initialized: break
	if not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized:
		check(false, "map initializes before timeout")
		quit(1)
		return
	var main: Node = current_scene
	main.game_clock.set_process(false)
	var tree: Node = main.technology_tree
	var economy: Node = main.district_economy
	var buildings: Node = main.district_buildings
	var retainers: Node = main.retainer_management
	var ids: Array = []
	for id in main.governance_registry.districts:
		if main.governance_registry.districts[id].house_id == "takeda": ids.append(id)
	var id: String = ids[0]
	var record: Dictionary = main.governance_registry.districts[id]
	var other_id: String = ids[1]
	economy.house_resources.takeda.money = 10000
	retainers.technology.takeda.governance = 0.0
	check(tree.research("takeda", "commerce", "市場整備") == ERR_UNAVAILABLE, "insufficient points rejected")
	check(tree.research("takeda", "commerce", "商人保護") == ERR_INVALID_PARAMETER, "prerequisite required")
	check(buildings.start_construction(other_id, "workshop", "takeda", 1546, 1, 1) == OK, "workshop begins before research")
	var original_construction: Dictionary = buildings.state[other_id].construction.duplicate(true)
	retainers.technology.takeda.governance = 10000.0
	main.game_menu.show_technology()
	var panel: Control = main.game_menu.technology_panel
	panel.branch_buttons.commerce.pressed.emit()
	check(panel.technology_buttons.size() == 8, "eight commerce cards displayed")
	check(not panel.technology_buttons["市場整備"].disabled and panel.technology_buttons["商人保護"].disabled, "only next research clickable")
	panel.technology_buttons["市場整備"].pressed.emit()
	check(tree.completed("takeda", "市場整備") and retainers.technology.takeda.governance == 9000.0, "UI researches and deducts shared points")
	check(buildings.cost_for(id, "market") == 85 and buildings.cost_for(id, "workshop") == 150, "market discount is targeted")
	check(tree.research("takeda", "commerce", "市場整備") == ERR_INVALID_PARAMETER, "research cannot repeat")
	for technology_id in tree.BRANCHES.commerce.slice(1):
		check(tree.research("takeda", "commerce", technology_id) == OK, "research " + technology_id)
	check(retainers.technology.takeda.governance == 2000.0 and tree.next_technology("takeda", "commerce").is_empty(), "eight studies consume 8000 points and finish branch")
	check(panel.branch_state.text == "この系統は研究完了", "UI displays completed branch")
	check(is_equal_approx(tree.modifiers("takeda").money, 1.20), "commerce income bonuses add to twenty percent")
	check(is_equal_approx(tree.modifiers("takeda").provisions, 1.0), "agriculture unaffected")
	check(buildings.cost_for(id, "workshop") == 128 and buildings.months_for(id, "workshop") == 13, "workshop costs round once and duration shortens")
	check(buildings.cost_for(id, "temple") == 120 and buildings.months_for(id, "market") == 12, "other costs and durations unaffected")
	check(buildings.state[other_id].construction == original_construction, "research preserves work already in progress")
	var progress_record: Dictionary = record.duplicate(true)
	progress_record.commerce_progress = 0.0
	progress_record.commerce_development = 1
	progress_record.commerce_developer_id = null
	economy.develop(progress_record, "commerce")
	check(progress_record.commerce_progress == 0.0, "no development without officer")
	var officer_id: String = retainers.house_members.takeda[0]
	progress_record.commerce_developer_id = officer_id
	var expected := float(economy.politics_for(officer_id)) * 1.30
	economy.develop(progress_record, "commerce")
	check(is_equal_approx(progress_record.commerce_progress, expected), "assigned officer gets additive thirty percent development boost")
	progress_record.commerce_progress = economy.PROGRESS_TO_MAX - 1.0
	economy.develop(progress_record, "commerce")
	check(progress_record.commerce_progress <= economy.PROGRESS_TO_MAX and progress_record.commerce_development <= 30, "development stays capped")
	check(buildings.effect_for(id, "market") == "金銭収入 +20%", "market UI describes current effect")
	var preview: int = economy.income_for(record, "commerce", "market")
	buildings.state[id].built.append("market")
	check(is_equal_approx(buildings.income_multiplier(id, "commerce"), 1.20), "market adds ten percentage points to facility effect")
	check(economy.income_for(record, "commerce") == preview, "preview matches completed market income")
	var money: int = economy.income_for(record, "commerce")
	record.house_id = "hojo"
	check(is_equal_approx(buildings.income_multiplier(id, "commerce"), 1.10), "market follows current owner's research")
	check(buildings.cost_for(id, "workshop") == 150 and buildings.months_for(id, "workshop") == 15, "cost and duration follow current owner")
	record.house_id = "takeda"
	check(economy.income_for(record, "commerce") == money, "restored owner restores income")
	check(buildings.start_construction(id, "workshop", "takeda", 1546, 1, 1) == OK, "discounted workshop starts")
	check(buildings.state[id].construction.months == 13 and buildings.state[id].construction.finish_month == 2, "duration fixed at construction start")
	check(session.save_game(main, 1) == OK, "save commerce and both workshop durations")
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty(), "current save validates")
	if saved.is_empty():
		printerr(session.last_error)
		quit(1)
		return
	check(saved.research.takeda.commerce.size() == 8, "all commerce research saved")
	check(saved.buildings[id].construction.months == 13 and saved.buildings[other_id].construction.months == 15, "original and shortened duration saved")
	var wrong: Dictionary = saved.duplicate(true)
	wrong.buildings[id].construction.months = 12
	check(not session.validate(wrong), "invalid workshop duration rejected")
	wrong = saved.duplicate(true)
	wrong.buildings[id].construction.finish_month = 3
	check(not session.validate(wrong), "incorrect completion date rejected")
	wrong = saved.duplicate(true)
	wrong.research.takeda.commerce = ["商人保護"]
	check(not session.validate(wrong), "research skipping prerequisites rejected on load")
	tree.researched.takeda.commerce = []
	buildings.state[id].construction = null
	session.pending = saved
	session.apply_to(main)
	check(tree.researched.takeda.commerce.size() == 8 and economy.income_for(main.governance_registry.districts[id], "commerce") == money, "load restores research and income")
	check(buildings.state[id].construction.months == 13, "load restores shortened construction duration")
	for field in original_construction:
		check(buildings.state[other_id].construction[field] == original_construction[field], "load restores original construction field: " + str(field))
	var balance: float = float(economy.house_resources.takeda.money)
	check(buildings.cancel_construction(id, "takeda") == OK and economy.house_resources.takeda.money == balance + 128, "loaded discounted work refunds actual payment")
	check(buildings.start_construction(id, "workshop", "takeda", 1546, 1, 1) == OK, "restart shortened workshop")
	buildings.on_day_advanced(1547, 1, 1)
	check(buildings.state[id].construction != null, "shortened workshop does not finish early")
	buildings.on_day_advanced(1547, 2, 1)
	check(buildings.state[id].built.has("workshop") and buildings.state[other_id].construction != null, "shortened workshop finishes before original workshop")
	buildings.on_day_advanced(1547, 4, 1)
	check(buildings.state[other_id].built.has("workshop"), "original workshop retains fifteen month schedule")
	retainers.technology.takeda.governance = 10000.0
	for technology_id in tree.BRANCHES.governance.slice(0, 4):
		check(tree.research("takeda", "governance", technology_id) == OK, "research governance prerequisite " + technology_id)
	check(tree.cost_for("takeda", "市場整備") == 950, "town system discounts commerce research")
	check(tree.research("takeda", "governance", "楽市") == OK and is_equal_approx(tree.modifiers("takeda").money, 1.25), "free market stacks additively with commerce")
	tree.researched.hojo.commerce = []
	retainers.technology.hojo.governance = 1000.0
	economy.house_resources.hojo = {"money":0, "provisions":1000}
	main.cpu_controller.manage_research("hojo")
	check(tree.completed("hojo", "市場整備"), "CPU prioritizes commerce when money is low")
	if DisplayServer.get_name() != "headless":
		panel.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/commerce_technology.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.path_for(1)))
	print("Commerce technology tests: %d failures" % failures)
	quit(0 if failures == 0 else 1)
