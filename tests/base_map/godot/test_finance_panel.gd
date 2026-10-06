extends SceneTree
const Finance = preload("res://scripts/game/finance_panel.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func run() -> void:
	change_scene_to_file("res://scenes/start/start.tscn")
	await process_frame
	await process_frame
	current_scene.show_houses()
	current_scene.select_house(current_scene.house_ids.find("uesugi_yamanouchi"))
	current_scene.begin()
	var deadline := Time.get_ticks_msec() + 45000
	while (not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized) and Time.get_ticks_msec() < deadline: await process_frame
	if not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized:
		check(false, "map initializes"); quit(1); return
	var main: Node = current_scene
	main.game_clock.set_process(false)
	main.cpu_controller.set_process(false)
	paused = true
	var house: String = root.get_node("GameSession").player_house
	var economy: Node = main.district_economy
	var retainers: Node = main.retainer_management
	var summary := Finance.summarize(economy, retainers, house)
	check(summary.districts.size() > 0, "owned districts included")
	var before_money: float = economy.house_resources[house].money
	var before_rice: int = economy.house_resources[house].provisions
	economy.collect_income("commerce")
	economy.collect_income("agriculture")
	check(is_equal_approx(economy.house_resources[house].money - before_money, summary.money_income), "monthly income matches actual collection")
	check(economy.house_resources[house].provisions - before_rice == summary.provisions_income, "annual income matches actual collection")
	var wages := 0.0
	for value in summary.wages.values(): wages += value
	check(is_equal_approx(wages, summary.money_expense), "role breakdown matches stipend total")
	economy.house_resources[house].money = 100000
	retainers.on_day_advanced(1546, 2, 1)
	check(is_equal_approx(100000 - economy.house_resources[house].money, summary.money_expense), "expense matches actual monthly wage deduction")
	var owned: Dictionary
	for record in economy.registry.districts.values():
		if record.house_id == house: owned = record; break
	var district_money: int = economy.income_for(owned, "commerce")
	var district_rice: int = economy.income_for(owned, "agriculture")
	owned.house_id = "__other_house"
	var after := Finance.summarize(economy, retainers, house)
	check(after.districts.size() == summary.districts.size() - 1, "ownership changes reflected")
	check(after.money_income == summary.money_income - district_money and after.provisions_income == summary.provisions_income - district_rice, "other houses excluded")
	owned.house_id = house
	main.game_menu.toggle_council()
	main.game_menu._select_council_tab(3)
	var panel: Control = main.game_menu.finance_panel
	check(panel.visible and panel.report.money_income == summary.money_income, "finance tab opens with current data")
	main.game_menu._select_council_tab(0)
	check(not panel.visible, "switching tab hides finances")
	main.game_menu._select_council_tab(3)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://builds/qa/finance_panel.png")
	main.game_menu._close_all()
	check(not panel.visible and not paused, "closing council resumes game")
	print("FINANCE_PANEL_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)
