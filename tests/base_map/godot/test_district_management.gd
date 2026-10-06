extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + message)
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
	var deadline := Time.get_ticks_msec() + 45000
	while (not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized) and Time.get_ticks_msec() < deadline: await process_frame
	if not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized:
		check(false, "main initialized")
		quit(1)
		return
	var main := current_scene
	var session := root.get_node("GameSession")
	var house: String = session.player_house
	check(main.house_status_hud.district_management_button.position.x > main.house_status_hud.council_button.position.x, "bulk icon to right of council")
	main.house_status_hud.district_management_button.pressed.emit()
	var panel: Control = main.game_menu.district_management_panel
	check(panel.visible and paused, "menu pauses simulation")
	main.game_menu._resize_council()
	check(panel.position.is_equal_approx(main.game_menu.council_menu.position), "bulk and council share HUD position")
	check(panel.size.is_equal_approx(main.game_menu.council_menu.size), "bulk and council share native frame size")
	check(main.game_menu.shade.color.a == 0, "bulk uses council transparent backdrop")
	for i in range(panel.tabs.size()):
		var button: Button = panel.tabs[i]
		check(button.position.y < 0 and button.position.y + button.size.y <= 0, "tab above window")
		check(button.get_child(0).texture.resource_path.contains(panel.TAB_ICONS[i]), "dedicated tab artwork")
	check(panel.district_ids.size() > 1, "owned district roster")
	var ids: Array = panel.district_ids.duplicate()
	panel._select_index(0)
	var r: Dictionary = main.governance_registry.districts[ids[0]]
	var base: int = main.district_economy.income_for(r, "commerce")
	var security: int = main.technology_tree.security_for(r)
	panel._select_tab(3)
	panel.tax_rate = 60
	panel._apply("tax")
	check(r.tax_rate == 60 and main.governance_registry.districts[ids[1]].tax_rate == 40, "tax only changes selected district")
	check(main.district_economy.income_for(r, "commerce") >= base and main.technology_tree.security_for(r) == maxi(0, security-20), "higher tax increases income and reduces security")
	panel.tax_rate = 40
	panel._apply("tax")
	check(main.technology_tree.security_for(r) == security, "returning to standard restores security without cumulative penalty")
	await process_frame
	click_control(panel.tax_increase_button)
	await process_frame
	check(r.tax_rate == 50 and panel.tax_value.text == "税率 50%" and not panel.choices.visible, "plus click immediately raises tax ten points without selector")
	click_control(panel.tax_increase_button)
	await process_frame
	check(r.tax_rate == 60 and panel.tax_increase_button.disabled, "plus disables at sixty percent")
	click_control(panel.tax_increase_button)
	await process_frame
	check(r.tax_rate == 60, "disabled plus cannot exceed upper bound")
	for expected in [50, 40, 30, 20]:
		click_control(panel.tax_decrease_button)
		await process_frame
		check(r.tax_rate == expected, "minus click lowers tax ten points")
	check(panel.tax_decrease_button.disabled, "minus disables at twenty percent")
	click_control(panel.tax_decrease_button)
	await process_frame
	check(r.tax_rate == 20 and main.governance_registry.districts[ids[1]].tax_rate == 40, "lower bound and selected-district scope preserved")
	click_control(panel.tax_increase_button)
	await process_frame
	var today: int = main.technology_orders.today()
	main.technology_orders.districts[ids[0]] = {"kind":"negotiation", "house":house, "officer":main.retainer_management.ruler_id(house), "ready":today, "end":today+90, "applied":true}
	panel._select_tab(3)
	await process_frame
	check(panel.tax_increase_button.disabled, "negotiation promise disables increase at thirty percent")
	panel._change_tax(10)
	check(r.tax_rate == 30, "direct handler respects negotiation cap")
	click_control(panel.tax_decrease_button)
	await process_frame
	check(r.tax_rate == 20 and not panel.tax_increase_button.disabled, "negotiation still permits decrease and return to thirty")
	main.technology_orders.districts.erase(ids[0])
	panel.tax_rate = 40
	panel._apply("tax")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/bulk_tax_icons.png")
	var foreign := ""
	for id in main.governance_registry.districts:
		if main.governance_registry.districts[id].house_id != house: foreign = id; break
	check(main.district_actions.set_tax_rate(foreign, house, 60) == ERR_UNAUTHORIZED, "foreign orders rejected")
	check(main.district_actions.set_tax_rate(ids[0], house, 45) == ERR_INVALID_PARAMETER, "invalid tax rejected")
	panel.selected = foreign
	check(panel.targets().is_empty(), "foreign selection cannot be edited")
	panel._select_index(0)
	panel._select_index(1)
	check(panel.selected == ids[1] and panel.tax_rate == 40, "switching district loads its current tax")
	panel._select_index(0)
	panel.search.text = "存在しない郡"
	panel._refresh_roster()
	check(panel.targets().is_empty(), "empty search has no edit target")
	panel.search.clear()
	panel._refresh_roster()
	panel._select_index(panel.district_ids.find(ids[0]))
	main.district_economy.house_resources[house].money = 10000
	panel._apply("upgrade")
	check(r.infrastructure == 2, "bulk infrastructure")
	panel._apply("build")
	check(main.district_buildings.state[ids[0]].construction != null, "bulk construction")
	panel._apply("cancel")
	check(main.district_buildings.state[ids[0]].construction == null, "bulk cancel")
	panel._select_tab(0)
	await process_frame
	check(not panel.facility_picker.visible, "building candidates open only from an empty slot")
	click_control(panel.slot_grid.get_node("Facility_plus"))
	await process_frame
	await process_frame
	check(panel.facility_picker.visible and not panel.choices.visible, "empty slot opens inline icon candidates without dropdown")
	check(panel.facility_choices.get_child_count() == main.district_buildings.DEFINITIONS.size() + 1, "all facilities have candidate cards")
	check(panel.facility_picker.get_global_rect().position.x >= panel.left.get_parent().get_global_rect().end.x, "candidates appear to right of slots")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/bulk_facility_candidates.png")
	var money_before: float = main.district_economy.house_resources[house].money
	var price: int = main.district_buildings.cost_for(ids[0], "market")
	click_control(panel.facility_choices.find_child("Build_market", true, false))
	await process_frame
	check(main.district_buildings.state[ids[0]].construction != null, "candidate icon starts construction")
	check(main.district_economy.house_resources[house].money == money_before - price, "candidate construction deducts cost")
	check(not panel.facility_picker.visible, "construction closes candidate list")
	check(main.district_buildings.state[ids[1]].construction == null, "construction affects only selected district")
	click_control(panel.slot_grid.get_node("Facility_construction"))
	await process_frame
	check(main.district_buildings.state[ids[0]].construction == null and main.district_economy.house_resources[house].money == money_before, "construction icon cancels and refunds")
	panel._build_facility("market")
	var job: Dictionary = main.district_buildings.state[ids[0]].construction
	main.district_buildings.on_day_advanced(job.finish_year, job.finish_month, 1)
	panel._select_tab(0)
	await process_frame
	click_control(panel.slot_grid.get_node("Facility_market"))
	await process_frame
	check(not main.district_buildings.state[ids[0]].built.has("market"), "completed icon demolishes facility")
	panel._open_facility_picker()
	main.game_menu._cancel_topmost()
	check(not panel.facility_picker.visible and panel.visible and paused, "Escape closes candidate list first")
	panel._open_facility_picker()
	panel._select_index(1)
	check(not panel.facility_picker.visible, "switching districts closes candidate list")
	panel._select_index(0)
	panel.officer_id = main.retainer_management.officers_for_house(house)[0]
	panel._apply("governor")
	check(r.governor.officer_id == panel.officer_id, "bulk governor appointment")
	panel._select_tab(1)
	await process_frame
	await process_frame
	click_control(panel.governor_district_buttons[ids[1]])
	await process_frame
	check(panel.selected == ids[1], "left governor row selects district")
	click_control(panel.governor_district_buttons[ids[0]])
	await process_frame
	check(panel.selected == ids[0], "left row returns to original district")
	var governor_id: String = panel.officer_id
	var governor_button: Button = panel.governor_buttons[governor_id]
	check(panel.governor_district_buttons[ids[0]].find_child("GovernorName", true, false).text == "郡代：" + r.governor.name, "left roster shows district and governor")
	check(panel.governor_district_buttons[ids[0]].find_child("Portrait", true, false).texture == panel._officer_texture(governor_id), "left roster uses governor portrait")
	check(governor_button.find_child("Portrait", true, false).texture == panel._officer_texture(governor_id), "right officer row uses same portrait")
	check(not panel.choices.visible and panel.governor_buttons.size() == main.retainer_management.officers_for_house(house).size(), "all house officers listed directly without dropdown")
	var other_governor: Variant = main.governance_registry.districts[ids[1]].governor
	click_control(governor_button)
	await process_frame
	await process_frame
	check(r.governor == null and not main.retainer_management.district_governors.has(ids[0]), "current governor click removes assignment and tracking")
	check(main.governance_registry.districts[ids[1]].governor == other_governor, "removal affects only selected district")
	check(panel.governor_district_buttons[ids[0]].find_child("GovernorName", true, false).text.contains("未任命"), "left roster updates after removal")
	var unassigned: Dictionary = session.capture(main)
	check(session.validate(unassigned), "save validates with unassigned governor")
	click_control(panel.governor_buttons[governor_id])
	await process_frame
	check(r.governor.officer_id == governor_id, "officer click appoints selected district governor")
	session.pending = unassigned
	session.apply_to(main)
	check(r.governor == null, "save reload preserves governor removal")
	panel._select_tab(1)
	await process_frame
	click_control(panel.governor_buttons[governor_id])
	await process_frame
	check(main.retainer_management.clear_district_governor(house, foreign) == ERR_UNAUTHORIZED, "cannot remove foreign governor")
	for child in panel.left.get_children():
		check(not (child is Button and (child.text.contains("農業担当") or child.text.contains("商業担当"))), "agriculture and commerce controls removed")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/bulk_governor_assignment.png")
	panel._apply("agriculture")
	check(r.agriculture_developer_id == panel.officer_id, "bulk officer development")
	panel._apply("clear_agriculture")
	check(r.agriculture_developer_id == null, "clear development")
	panel.tax_rate = 50
	panel._apply("tax")
	var data: Dictionary = session.capture(main)
	check(data.territories.districts[ids[0]].tax_rate == 50 and session.validate(data), "current save validates with tax rates")
	session.pending = data
	r.tax_rate = 40
	session.apply_to(main)
	check(r.tax_rate == 50, "save reload restores tax rate")
	for i in range(panel.TABS.size()):
		click_control(panel.tabs[i])
		await process_frame
		await process_frame
		check(panel.tab == i, "clicking top icon switches tab")
		check(panel.district_list.get_global_rect().end.x <= panel.left.get_global_rect().position.x, "roster is left of editor")
		check(panel.left.get_parent().get_global_rect().end.y <= panel.get_global_rect().end.y, "editor remains inside window")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://builds/qa/bulk_%d.png" % i)
	panel._show_choices("officer")
	main.game_menu._cancel_topmost()
	check(not panel.choices.visible and panel.visible and paused, "Escape closes selector first")
	main.game_menu._cancel_topmost()
	check(not panel.visible and not paused, "Escape closes bulk and resumes")
	# Let the final UI click sound finish before tearing down the audio server.
	await create_timer(0.5, true).timeout
	print("BULK MANAGEMENT CHECKS: ", failures)
	quit(0 if failures == 0 else 1)
