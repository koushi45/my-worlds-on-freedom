extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/qa/" + name + ".png")

func run() -> void:
	change_scene_to_file("res://scenes/start/start.tscn")
	await process_frame
	await process_frame
	current_scene.show_houses()
	current_scene.select_house(current_scene.house_ids.find("oda_nobuhide"))
	current_scene.begin()
	var deadline := Time.get_ticks_msec() + 60000
	while (not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized) and Time.get_ticks_msec() < deadline:
		await process_frame
	if current_scene.name != "Main" or not current_scene.initialized:
		check(false, "map loads")
		quit(1)
		return
	var main := current_scene
	main.game_clock.paused = true
	main.game_clock.set_process(false)
	var hud: Node = main.house_status_hud
	var menu: Node = main.game_menu
	for dimensions in [Vector2i(1280,720), Vector2i(1920,1080)]:
		if DisplayServer.get_name() != "headless": root.size = dimensions
		await process_frame
		await process_frame
		hud._resize()
		main.time_hud._resize()
		check(hud.household_panel.get_global_rect().end.x + 40 < main.time_hud.panel.get_global_rect().position.x, "separate corner zones at %s" % dimensions)
		for key in hud.values:
			var container: Control = hud.household_panel if key in hud.HOUSEHOLD else hud.technology_panel
			check(container.get_global_rect().encloses(hud.values[key].get_global_rect()), "value %s stays in own frame" % key)
		check(hud.values.size() == 10 and hud.council_button.text.is_empty(), "all ten metrics and icon-only council")
		var money_before: float = main.district_economy.house_resources[root.get_node("GameSession").player_house].money
		main.district_economy.house_resources[root.get_node("GameSession").player_house].money = 12345.6
		hud.invalidate()
		await process_frame
		check(hud.values.money.text == "12345.6", "HUD follows live resource updates")
		main.district_economy.house_resources[root.get_node("GameSession").player_house].money = money_before
		hud.invalidate()
		await capture("compact_hud_%d" % dimensions.x)
		menu.toggle_council()
		check(paused and menu.council_menu.visible and menu.retainer_panel.visible, "council directly opens retainers and pauses game")
		var council_rect: Rect2 = menu.council_menu.get_global_rect()
		check(council_rect.position.x <= hud.panel.get_global_rect().position.x + 1, "council starts at the left HUD edge")
		check(council_rect.position.y >= hud.technology_panel.get_global_rect().end.y, "council stays below header")
		check(council_rect.end.x <= hud.household_panel.get_global_rect().end.x and council_rect.end.y <= main.get_viewport_rect().end.y, "council stays inside requested left-side area")
		check(menu.council_tabs.size() == 3, "three direct management tabs")
		for index in range(3):
			menu.council_tabs[index].pressed.emit()
			check(menu.council_tab == index and menu.council_tabs[index].button_pressed, "management tab switches page")
			await process_frame
			var panels: Array = [menu.retainer_panel, menu.diplomacy_panel, menu.technology_panel]
			for i in range(panels.size()):
				if not is_instance_valid(panels[i]): continue
				check(panels[i].visible == (i == index), "only active management page is visible")
				check(council_rect.encloses(panels[i].get_global_rect()), "management page is inside council frame")
			await capture("council_direct_%d_%d" % [index, dimensions.x])
		menu._select_council_tab(0)
		await capture("compact_council_%d" % dimensions.x)
		menu._open_council_role("軍師")
		check(menu.retainer_panel.visible and menu.retainer_panel.selected_role == "軍師", "role value opens real assignment screen")
		menu.retainer_panel.close_panel()
		check(not paused and not menu.council_menu.visible, "closing management closes council and resumes tree")
	main.queue_free()
	await process_frame
	await process_frame
	print("Compact corner HUD: %d failures" % failures)
	quit(1 if failures else 0)



