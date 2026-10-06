extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func run() -> void:
	var session := root.get_node("GameSession")
	session.player_house = "hojo"
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized): await process_frame
	if current_scene == null or not current_scene.initialized: printerr("FAIL: map initialization"); quit(1); return
	var main := current_scene
	main.game_clock.paused = true
	main.cpu_controller.enabled = false; main.cpu_controller.work_queue.clear()
	var army: Node = main.army_campaign
	var panel: Node = main.army_panel
	var home := ""
	for district_id in main.district_office_layer.records:
		if main.governance_registry.districts[district_id].house_id == session.player_house: home = district_id; break
	var members: Array[String] = main.retainer_management.officers_for_house(session.player_house)
	if members.size() < 4 or home.is_empty(): printerr("FAIL: officer fixture"); quit(1); return
	for officer_id in main.retainer_management.officers_in_district(session.player_house, home):
		main.retainer_management.place_officer(session.player_house, officer_id, "")
	var ids := members.slice(0, 4)
	for index in ids.size():
		main.retainer_management.place_officer(session.player_house, ids[index], home)
		var scores: Dictionary = main.officer_registry.lookup[ids[index]].assessment.scores
		scores.command = [30, 20, 15, 10][index]
		scores.tactics = [10, 30, 25, 5][index]
	check(army.recommended_officers("missing").is_empty(), "unknown district has no recommendations")
	check(army.recommended_officers(home) == ids.slice(0, 3), "general uses command; deputies maximize average valor")
	main.technology_orders.districts[home] = {"house": session.player_house, "officer": ids[0], "kind": "patrol", "ready": main.technology_orders.today() + 30, "end": main.technology_orders.today() + 120}
	check(ids[0] not in army.recommended_officers(home), "officers on technology assignments are excluded")
	main.technology_orders.districts.erase(home)
	var recommendation: Array[String] = army.recommended_officers(home)
	var best_valor: float = army.unit_valor({"officers": recommendation})
	for first in ["", ids[1], ids[2], ids[3]]:
		for second in ["", ids[1], ids[2], ids[3]]:
			if not first.is_empty() and first == second: continue
			var lineup: Array = [ids[0]]
			if not first.is_empty(): lineup.append(first)
			if not second.is_empty(): lineup.append(second)
			check(best_valor >= army.unit_valor({"officers": lineup}), "recommendation is optimal among all deputy subsets")
	panel.show_district(home)
	check(panel.selected_officers == recommendation and not panel.right_panel.visible, "opening sortie preselects officers without opening the roster")
	panel._choose_officer(1, "")
	panel.refresh()
	check(panel.selected_officers == [ids[0], "", ids[2]], "manual empty deputy survives refresh")
	panel._choose_officer(1, ids[3])
	panel.refresh()
	check(panel.selected_officers == [ids[0], ids[3], ids[2]], "manual replacement survives refresh")
	panel.show_district(home)
	check(panel.selected_officers == recommendation, "reopening sortie recalculates recommendations")
	main.officer_registry.lookup[ids[0]].assessment.scores.tactics = 30
	check(army.recommended_officers(home) == [ids[0]], "deputies that cannot improve average valor remain unselected")
	main.officer_registry.lookup[ids[0]].assessment.scores.tactics = 10
	main.officer_registry.lookup[ids[1]].assessment.scores.tactics = null
	check(army.recommended_officers(home) == [ids[0], ids[2]], "unknown valor uses the combat default and weak deputies are skipped")
	main.officer_registry.lookup[ids[1]].assessment.scores.tactics = 30
	main.officer_registry.lookup[ids[1]].assessment.scores.command = 30
	check(army.recommended_officers(home) == [ids[1]], "equal command prefers the general with higher valor")
	main.officer_registry.lookup[ids[1]].assessment.scores.command = 20
	main.governance_registry.districts[home].sortie_troops = 20000
	main.governance_registry.districts[home].population = 200000
	main.district_economy.house_resources[session.player_house].provisions = 100000
	panel.show_district(home)
	panel._dispatch()
	check(panel.mode == "unit" and not panel.unit_id.is_empty(), "preselected officers can dispatch immediately")
	check(army.units.size() == 1, "automatic selection dispatches exactly one unit on request")
	if not panel.unit_id.is_empty():
		check(army.units[panel.unit_id].officers == recommendation, "dispatch uses the recommended lineup")
	panel.show_district(home)
	check(panel.selected_officers == [ids[3], "", ""], "subsequent sortie excludes all deployed officers")
	main.retainer_management.place_officer(session.player_house, ids[3], "")
	panel.show_district(home)
	check(panel.selected_officers == ["", "", ""], "no eligible officers leaves every slot empty")
	print("SORTIE_RECOMMENDATION_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)
