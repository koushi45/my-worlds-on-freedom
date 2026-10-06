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

func click_control(control: Control) -> void:
	click_at(control.get_global_rect().get_center())

func click_at(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	root.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)

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
	for tab_index in range(3):
		for sample in [Vector2(0.5, 0.5), Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.1, 0.9), Vector2(0.9, 0.9)]:
			main.game_menu.toggle_council()
			main.game_menu._select_council_tab(tab_index)
			await process_frame
			await process_frame
			var close_rect: Rect2 = main.game_menu.council_menu.get_node("CouncilClose").get_global_rect()
			click_at(close_rect.position + close_rect.size * sample)
			check(not main.game_menu.shade.visible and not paused, "close button responds across its visible bounds on tab %d at %s" % [tab_index, sample])
			main.game_menu._close_all()
	main.game_menu.council_tab = 0
	main.house_status_hud.council_button.pressed.emit()
	check(main.game_menu.council_menu.visible and main.game_menu.shade.visible and main.game_menu.retainer_panel.visible, "council icon directly opens retainers")
	await capture("council_menu")
	main.game_menu.show_retainers()
	await process_frame
	check(main.game_menu.retainer_panel.visible, "council opens retainer management")
	var retainers: Control = main.game_menu.retainer_panel
	var house_id: String = root.get_node("GameSession").player_house
	var members: Array = main.retainer_management.house_members[house_id]
	check(not members.is_empty(), "preview has eligible officers")
	if not members.is_empty():
		var officer_id: String = members[0]
		var original_wage: float = main.retainer_management.stipend_for(house_id, officer_id)
		retainers._select_role("軍師")
		retainers._select_officer(officer_id)
		await process_frame
		check(retainers.stipend_after.text == "任命後 2.0 / 月", "senior preview uses actual twenty-times stipend")
		check(retainers.stipend_delta.text == "増減 +1.9 / 月", "preview shows difference from current wage")
		check(retainers.effect_value.text.contains("軍事") and retainers.effect_value.text.contains("→"), "selected officer shows actual growth preview")
		check(main.retainer_management.role_of(house_id, officer_id) == "直臣" and is_equal_approx(main.retainer_management.stipend_for(house_id, officer_id), original_wage), "preview does not mutate appointments or wages")
		var frame_rect: Rect2 = main.game_menu.council_menu.get_global_rect()
		for tab in main.game_menu.council_tabs:
			check(tab.get_global_rect().end.y <= frame_rect.position.y, "council tab is outside frame")
		check(retainers.left.get_global_rect().end.x <= retainers.roster_scroll.get_global_rect().position.x, "preview and roster split horizontally")
		check(not retainers.wage_dialog.visible, "wage dialog only opens on amount action")
		click_control(retainers.officer_buttons[officer_id].get_node("Contents/Identity/StipendButton"))
		check(retainers.wage_dialog.visible, "current amount opens wage editor")
		escape()
		await process_frame
		check(not retainers.wage_dialog.visible and retainers.visible and paused, "Escape dismisses wage editor and leaves council open")
		retainers._open_wage(officer_id)
		retainers.wage_input.value = 0.2
		retainers.wage_dialog.confirmed.emit()
		retainers.wage_dialog.hide()
		check(retainers.stipend_after.text == "任命後 4.0 / 月", "wage edit refreshes preview")
		retainers._appoint()
		check(main.retainer_management.role_of(house_id, officer_id) == "軍師", "preview appoint action applies chosen role")
		check(retainers.stipend_delta.text == "増減 +0.0 / 月", "appointed wage is reflected in preview")
		if members.size() > 1:
			retainers._select_officer(members[1])
			check(retainers.appoint_button.disabled, "occupied senior position disables appointment")
		main.retainer_management.assign_role(house_id, officer_id, "直臣")
		main.retainer_management.set_base_stipend(house_id, officer_id, 0.1)
		retainers._select_officer(officer_id)
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
