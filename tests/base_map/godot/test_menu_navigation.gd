extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)

func right_click() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(10, 10)
	root.push_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/qa/" + name + ".png")

func run() -> void:
	change_scene_to_file("res://scenes/start/start.tscn")
	await process_frame
	await process_frame
	current_scene.show_houses()
	current_scene.select_house(current_scene.house_ids.find("uesugi_yamanouchi"))
	current_scene.begin()
	var deadline := Time.get_ticks_msec() + 45000
	while (not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized:
		check(false, "main scene loads")
		quit(1)
		return
	var main := current_scene
	check(main.house_status_hud.council_button != null, "council icon is in the header")
	main.house_status_hud.council_button.pressed.emit()
	check(main.game_menu.council_menu.visible and main.game_menu.shade.visible and main.game_menu.retainer_panel.visible, "council icon directly opens retainers")
	await capture("council_menu")
	main.game_menu.show_retainers()
	await process_frame
	check(main.game_menu.retainer_panel.visible, "council opens retainer management")
	await capture("council_retainers")
	main.game_menu.council_tabs[2].pressed.emit()
	await process_frame
	check(main.game_menu.technology_panel.visible and not main.game_menu.retainer_panel.visible and main.game_menu.council_menu.visible, "tab directly switches to technology tree")
	await capture("council_technology")
	main.retainer_management.technology[root.get_node("GameSession").player_house].governance = 1000.0
	main.game_menu.technology_panel.refresh()
	check(not main.game_menu.technology_panel.technology_buttons["分国法"].disabled, "available research card lights up")
	await capture("council_technology_ready")
	main.retainer_management.technology[root.get_node("GameSession").player_house].governance = 0.0
	main.game_menu.technology_panel.refresh()
	escape()
	await process_frame
	check(not main.game_menu.shade.visible and not main.game_menu.technology_panel.visible and not paused, "Escape closes technology management and resumes game")
	main.game_menu.show_retainers()
	main.game_menu.retainer_panel.close_panel()
	check(not main.game_menu.shade.visible and not paused, "retainer close closes council")
	main.game_menu.show_technology()
	main.game_menu.technology_panel.close_panel()
	check(not main.game_menu.shade.visible and not paused, "technology close closes council")
	var district_id: String = main.governance_registry.districts.keys()[0]
	main.show_district_info(district_id)
	main.district_info.building_dialog.popup_centered()
	escape()
	await process_frame
	check(main.district_info.panel.visible and not main.district_info.building_dialog.visible and not main.game_menu.shade.visible, "Escape closes district subdialog first")
	escape()
	await process_frame
	check(not main.district_info.panel.visible and not main.game_menu.shade.visible, "Escape closes district menu first")
	escape()
	await process_frame
	check(main.game_menu.modal.visible and main.game_menu.shade.visible, "Escape opens game menu from clear map")
	await capture("unified_game_menu")
	escape()
	await process_frame
	check(not main.game_menu.shade.visible and not paused, "Escape closes game menu")
	main.show_district_info(district_id)
	main.district_info.building_dialog.popup_centered()
	right_click()
	await process_frame
	check(main.district_info.panel.visible and main.district_info.building_dialog.visible and not main.game_menu.shade.visible, "right click leaves district subdialog open")
	escape()
	await process_frame
	right_click()
	await process_frame
	check(main.district_info.panel.visible and not main.game_menu.shade.visible, "right click leaves district panel open")
	escape()
	await process_frame
	right_click()
	await process_frame
	check(not main.game_menu.shade.visible, "right click does not open game menu")
	escape()
	await process_frame
	right_click()
	await process_frame
	check(main.game_menu.modal.visible and main.game_menu.shade.visible, "right click leaves game menu open")
	print("menu navigation failures: ", failures)
	quit(1 if failures > 0 else 0)
