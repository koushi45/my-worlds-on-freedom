extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := root.get_node("GameSession")
	session.save_directory = "user://qa_governor_roster_%d" % OS.get_process_id()
	check(session.new_game("oda_nobuhide") == OK, "Oda game starts")
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.name == "Main" and current_scene.initialized: break
	if not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized:
		check(false, "map initializes")
		quit(1)
		return
	var main := current_scene
	main.game_menu.show_retainers()
	await process_frame
	var panel: Control = main.game_menu.retainer_panel
	for officer_id in ["officer_q171411", "officer_q707587"]:
		check(panel.officer_buttons.has(officer_id), "governor has selectable retainer row: " + officer_id)
		if panel.officer_buttons.has(officer_id):
			panel.officer_buttons[officer_id].pressed.emit()
			check(panel.selected_officer_id == officer_id and panel.officer_buttons[officer_id].has_node("Contents/Identity/StipendButton"), "governor row supports selection and wage editing")
	var management: Node = main.retainer_management
	var house_id: String = session.player_house
	var ruler_id: String = management.ruler_id(house_id)
	check(panel.ruler_name.text.contains(main.officer_registry.lookup[ruler_id].display_name), "council names the current ruler")
	for key in panel.ABILITIES:
		var expected: Variant = main.officer_registry.ability(ruler_id, key)
		check(panel.ruler_values[key].text == ("―" if expected == null else str(expected).trim_suffix(".0")), "council shows actual ruler ability: " + key)
	main.game_menu._close_all()
	main.game_clock.set_process(false)
	main.army_campaign.set_process(false)
	var district_id := ""
	for record in main.governance_registry.districts.values():
		if record.house_id == house_id and main.army_campaign.graph.has("district:" + record.id) and main.district_actions.sortie_available(record) >= 100:
			district_id = record.id
			break
	check(not district_id.is_empty(), "own district supports ruler dispatch")
	var army_id := ""
	if not district_id.is_empty():
		main.show_district_info(district_id)
		main.district_info._open_governor_dialog()
		check(ruler_id in main.district_info.governor_ids, "governor picker includes ruler")
		main.district_info.governor_choice.select(main.district_info.governor_ids.find(ruler_id))
		main.district_info._set_governor()
		main.district_info.governor_dialog.hide()
		main.district_info.hide_info()
		check(management.district_governors.get(district_id) == ruler_id, "governor picker appoints ruler")
		main.army_panel.show_placement(district_id)
		main.army_panel._open_placement_roster()
		var ruler_in_roster := false
		for child in main.army_panel.roster.get_children():
			if child is Button and child.text.contains(main.officer_registry.lookup[ruler_id].display_name): ruler_in_roster = true
		check(ruler_in_roster, "placement roster includes ruler")
		main.army_panel._place_officer(ruler_id, district_id)
		check(ruler_id in main.army_campaign.available_officers(district_id), "placed ruler is available as commander")
		main.army_panel.show_district(district_id)
		main.army_panel._choose_officer(0, ruler_id)
		check(main.army_panel.selected_officers[0] == ruler_id, "ruler can occupy the commander slot")
		main.district_economy.house_resources[house_id].provisions = 100000
		army_id = main.army_campaign.dispatch(district_id, [ruler_id], 100, false, false)
		check(not army_id.is_empty(), "ruler dispatch succeeds")
		if not army_id.is_empty():
			check(main.army_campaign.units[army_id].officers[0] == ruler_id, "ruler is the dispatched commander")
			check(ruler_id not in main.army_campaign.available_officers(district_id), "deployed ruler cannot dispatch twice")
			check(management.place_officer(house_id, ruler_id, "") == ERR_BUSY, "deployed ruler cannot change district placement")
	check(session.save_game(main, 1) == OK, "current game saves")
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty(), "current save loads and validates")
	if not saved.is_empty():
		session.pending = saved
		session.apply_to(main)
		if not district_id.is_empty(): check(management.district_governors.get(district_id) == ruler_id, "ruler governorship survives save and load")
		if not army_id.is_empty(): check(main.army_campaign.units.get(army_id, {}).get("officers", [""])[0] == ruler_id, "ruler command survives save and load")
		panel.refresh()
		for officer_id in ["officer_q171411", "officer_q707587"]:
			check(panel.officer_buttons.has(officer_id), "loaded roster retains governor row: " + officer_id)
	DirAccess.remove_absolute(session.path_for(1))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.save_directory))
	print("Governor retainer roster failures: ", failures)
	quit(0 if failures == 0 else 1)
