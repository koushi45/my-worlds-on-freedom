extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func texts(node: Node) -> String:
	var result := ""
	if node is Label or node is Button: result += node.text + "\n"
	for child in node.get_children(): result += texts(child)
	return result

func run() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized): await process_frame
	if not check(current_scene != null and current_scene.initialized, "map initialized"): return
	var main = current_scene
	var army = main.army_campaign
	var ui = main.army_panel
	var session = root.get_node("GameSession")
	main.game_clock.set_process(false)
	army.set_process(false)
	main.cpu_controller.enabled = false
	var source := ""
	var officer := ""
	for id in main.governance_registry.districts:
		var district: Dictionary = main.governance_registry.districts[id]
		if main.district_actions.sortie_available(district) < 400: continue
		session.player_house = district.house_id
		var available: Array[String] = army.available_officers(id)
		if not available.is_empty(): source = id; officer = available[0]; break
	if not check(not source.is_empty(), "sortie source exists"): return
	var enemy := ""
	for id in main.district_office_layer.records:
		if main.governance_registry.districts[id].house_id != session.player_house: enemy = id; break
	if not check(not enemy.is_empty(), "enemy office exists"): return
	var owner: String = main.governance_registry.districts[enemy].house_id
	session.relations[session.pair(session.player_house, owner)] = "enemy"
	main.district_economy.house_resources[session.player_house].provisions = 100000
	var id: String = army.dispatch(source, [officer], 25, false, false)
	if not check(not id.is_empty(), "dispatch succeeds"): return
	ui.show_unit(id, true)
	if not check(not ui.occupation_panel.visible, "ordinary army has no occupation panel"): return
	var unit: Dictionary = army.units[id]
	unit.site_id = "district:" + enemy; unit.next_site = ""; unit.orders.clear(); unit.soldiers = 1200
	army._arrive(id)
	army.occupations[enemy].progress = 42.0
	ui.show_unit(id, true)
	await process_frame
	if not check(ui.panel.visible and ui.occupation_panel.visible, "selected occupying army opens two panels"): return
	if not check(ui.panel.get_global_rect().end.x < ui.occupation_panel.position.x and ui.occupation_panel.get_global_rect().end.y <= root.get_visible_rect().size.y and ui.occupation_panel.get_global_rect().end.x <= root.get_visible_rect().size.x, "panels fit and do not overlap"): return
	var left := texts(ui.body)
	var right := texts(ui.occupation_body)
	if not check("兵数" in left and "腰兵糧" in left and "目標：" in left and "帰郡" in left and "自動：" in left, "army data and commands remain on left"): return
	if not check("制圧率" not in left and "毎日 +" not in left and "兵数 1200人" not in right and "腰兵糧" not in right and "帰郡" not in right and "自動：" not in right and "目標：" not in right, "no duplicated army data or controls"): return
	if not check("制圧率 42%" in right and army.occupation_display(enemy).rate > 0, "detail uses actual occupation progress"): return
	var marker = main.map_view.markers.army_markers
	main.camera.position = main.elevation.project(main.district_office_layer.office_point(enemy))
	main.set_map_zoom(8.0)
	main.map_view.sync(true)
	var box: Rect2 = marker.occupation_badge_rect(enemy)
	var center: Vector2 = main.map_view.project(main.district_office_layer.office_point(enemy))
	if not check(is_equal_approx(box.get_center().x, center.x) and box.end.y < center.y, "badge is centered directly above office"): return
	main.game_clock.paused = false
	if "--capture" in OS.get_cmdline_user_args():
		for index in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/occupation_ui.png")
	var hostile: Dictionary = unit.duplicate(true)
	hostile.id = "ui_enemy"; hostile.house_id = owner
	army.units[hostile.id] = hostile
	army.changed.emit()
	if not check("敵接近により制圧停止" in texts(ui.occupation_body) and army.occupation_display(enemy).rate == 0, "nearby enemies explain stopped capture"): return
	army.units.erase(hostile.id)
	main.game_clock.toggle_paused()
	if not check("時間停止中" in texts(ui.occupation_body), "pause immediately updates detail"): return
	unit.next_site = "district:" + source
	army.changed.emit()
	if not check(not ui.occupation_panel.visible and army.occupation_display(enemy).badge == "時間停止中", "marching away closes detail"): return
	main.game_clock.paused = false
	if not check(army.occupation_display(enemy).change == "毎日 −10ポイント", "abandoned office reports decay"): return
	unit.next_site = ""
	army.occupations[enemy].progress = 99.99
	army.on_day_advanced(1546, 1, 2)
	if not check(not ui.occupation_panel.visible and army.occupation_display(enemy).is_empty(), "capture completion removes occupation UI"): return
	ui.hide_panel()
	if not check(not ui.panel.visible and not ui.occupation_panel.visible, "deselection hides both panels"): return
	print("PASS: occupation UI states, layout, badge and nonduplicated controls")
	quit(0)
