extends SceneTree

const Grid = preload("res://scripts/map/hex_grid.gd")
var failures := 0
var session: Node
var main: Node

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func loot_buttons() -> Array:
	var result: Array = []
	var pending_nodes: Array = [main.army_panel.body]
	while not pending_nodes.is_empty():
		var child: Node = pending_nodes.pop_back()
		if child is Button and child.text == "略奪": result.append(child)
		pending_nodes.append_array(child.get_children())
	return result

func test_looting(army: Node, id: String, target: String) -> void:
	var unit: Dictionary = army.units[id]
	var record: Dictionary = main.governance_registry.districts[target]
	var economy: Node = main.district_economy
	var old_resources: Dictionary = economy.house_resources.duplicate(true)
	var old_devastation: int = record.devastation
	var old_security: int = record.security
	var owner: String = record.house_id
	var pair: String = session.pair(unit.house_id, owner)
	check(economy.income_for(record, "commerce") == 0 and economy.income_for(record, "agriculture") == 0, "enemy office presence blocks both income previews")
	var expected := 0
	for district in main.governance_registry.districts.values():
		if district.house_id == owner and district.id != target: expected += economy.income_for(district, "commerce")
	var before: float = economy.house_resources[owner].money
	economy.collect_income("commerce")
	check(is_equal_approx(float(economy.house_resources[owner].money) - before, expected), "monthly collection actually excludes the blocked district")
	expected = 0
	for district in main.governance_registry.districts.values():
		if district.house_id == owner and district.id != target: expected += economy.income_for(district, "agriculture")
	var provisions_before: int = economy.house_resources[owner].provisions
	economy.collect_income("agriculture")
	check(int(economy.house_resources[owner].provisions) - provisions_before == expected, "annual harvest actually excludes the blocked district")
	var normal: int = economy.potential_income_for(record, "commerce")
	var office_node: String = unit.site_id
	var cell: Vector2i = Grid.cell_at(army.node_point(office_node))
	unit.site_id = Grid.key(cell + Vector2i(1, 0))
	main.army_panel.show_unit(id, true)
	check(economy.income_for(record, "commerce") == normal and loot_buttons().is_empty(), "adjacent army neither blocks income nor exposes loot")
	unit.site_id = office_node
	main.army_panel.refresh()
	check(loot_buttons().is_empty() and army.loot_selected(id).is_empty(), "arrival after earlier selection still requires a new click")
	unit.next_site = Grid.key(cell + Vector2i(1, 0)); unit.progress = 0.1
	check(economy.income_for(record, "commerce") == 0 and not army.loot_unavailable_reason(id).is_empty(), "moving army inside office tile blocks income but cannot loot")
	unit.progress = 0.9
	check(economy.income_for(record, "commerce") == normal, "leaving office tile restores income immediately")
	unit.next_site = ""; unit.progress = 0.0
	session.relations[pair] = "ally"
	check(economy.income_for(record, "commerce") == normal and not army.loot_unavailable_reason(id).is_empty(), "allied office cannot be looted or block income")
	session.relations[pair] = "enemy"
	main.diplomacy.truces[pair] = int(main.game_clock.elapsed_days) + 5
	check(economy.income_for(record, "commerce") == normal and not army.loot_unavailable_reason(id).is_empty(), "truce prevents blockade and looting")
	main.diplomacy.truces.erase(pair)
	economy.house_resources[owner].money = 1000
	economy.house_resources[owner].provisions = 1000
	main.army_panel.show_unit(id)
	check(loot_buttons().is_empty() and army.loot_selected(id).is_empty(), "automatic army panel opening does not authorize loot")
	main.army_panel.show_unit(id, true)
	check(loot_buttons().size() == 1 and not loot_buttons()[0].disabled, "clicking own army on enemy office exposes enabled loot command")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/looting_ready.png")
	var enemy: Dictionary = unit.duplicate(true)
	enemy.house_id = owner; enemy.id = "loot_defender"
	army.units.loot_defender = enemy
	check(not army.loot_unavailable_reason(id).is_empty(), "contested office prevents loot")
	army.units.erase("loot_defender")
	var amount: Dictionary = army.loot_yield(id)
	var actor_before: float = economy.house_resources[unit.house_id].money
	var actor_provisions: int = economy.house_resources[unit.house_id].provisions
	loot_buttons()[0].pressed.emit()
	check(is_equal_approx(float(economy.house_resources[unit.house_id].money) - actor_before, amount.money) and int(economy.house_resources[unit.house_id].provisions) - actor_provisions == int(amount.provisions), "loot button grants predicted resources")
	check(is_equal_approx(float(economy.house_resources[owner].money), 1000 - int(amount.money)) and int(economy.house_resources[owner].provisions) == 1000 - int(amount.provisions), "loot conserves resources by subtracting from enemy stores")
	check(int(record.devastation) == mini(100, old_devastation + 10) and int(record.security) == maxi(0, old_security - 10), "loot damages district conditions")
	check("獲得" in main.army_panel.status.text and loot_buttons()[0].disabled, "loot feedback survives panel refresh and command becomes disabled")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/looting_result.png")
	check(army.loot_selected(id).is_empty() and "あと30日" in army.last_error, "repeated loot is rejected")
	check(session.save_game(main, 3) == OK and int(session.read_save(3).territories.districts[target].loot_available_day) == 30, "loot cooldown round trips through current save")
	var old_day: int = main.game_clock.elapsed_days
	main.game_clock.elapsed_days = 30
	check(army.loot_unavailable_reason(id).is_empty(), "cooldown expires after thirty game days")
	main.game_clock.elapsed_days = old_day
	record.loot_available_day = 0
	economy.house_resources[owner].money = 0
	economy.house_resources[owner].provisions = 0
	check(army.loot_selected(id).is_empty() and "ありません" in army.last_error, "empty stores cannot generate loot from nothing")
	main.army_panel.hide_panel()
	check(army.loot_selected(id).is_empty(), "deselection removes permission to loot")
	economy.house_resources = old_resources
	record.devastation = old_devastation; record.security = old_security

func run() -> void:
	session = root.get_node("GameSession")
	session.player_house = "uesugi_yamanouchi"
	session.save_directory = "user://qa_occupation_%d" % OS.get_process_id()
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized): await process_frame
	if current_scene == null or not current_scene.initialized: printerr("FAIL: map initialization"); quit(1); return
	main = current_scene
	main.game_clock.paused = true
	main.cpu_controller.enabled = false
	main.cpu_controller.work_queue.clear()
	var army: Node = main.army_campaign
	var home := ""
	var target := ""
	for district_id in main.district_office_layer.records:
		var record: Dictionary = main.governance_registry.districts[district_id]
		if record.house_id == session.player_house and not army.available_officers(district_id).is_empty(): home = district_id
		if record.house_id == "hojo": target = district_id
	if home.is_empty() or target.is_empty(): printerr("FAIL: occupation fixtures"); quit(1); return
	var officer: String = army.available_officers(home)[0]
	var id: String = army.dispatch(home, [officer], 25, false, false)
	if id.is_empty(): printerr("FAIL: dispatch fixture: " + army.last_error); quit(1); return
	var unit: Dictionary = army.units[id]
	unit.soldiers = 1000
	unit.site_id = "district:" + target
	var record: Dictionary = main.governance_registry.districts[target]
	record.defense = 1
	main.district_buildings.state[target].built.clear()
	session.relations[session.pair(unit.house_id, record.house_id)] = "enemy"
	army._arrive(id)
	await test_looting(army, id, target)
	check(army.occupations.has(target) and float(army.occupations[target].progress) == 0.0, "arrival starts control without immediate capture")
	var rate: float = army.occupation_rate(target)
	check(rate >= 15.0 and rate <= 25.0, "1000 troops capture in about five days")
	army.on_day_advanced(1546, 1, 2)
	check(is_equal_approx(float(army.occupations[target].progress), rate) and int(unit.soldiers) == 1000, "one daily control tick and no artificial attrition")
	var progress: float = army.occupations[target].progress
	var save: Dictionary = session.capture(main)
	check(session.validate(save), "partial control save validates")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		main.army_panel.show_unit(id)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/occupation_control.png")
		main.army_panel.hide_panel()
	check(session.save_game(main, 1) == OK, "partial control writes to disk")
	var loaded: Dictionary = session.read_save(1)
	check(not loaded.is_empty() and is_equal_approx(float(loaded.armies.occupations[target].progress), progress), "partial control reads from disk")
	var bad: Dictionary = save.duplicate(true)
	bad.armies.occupations[target].progress = 100.0
	check(not session.validate(bad), "completed progress cannot remain pending")
	bad = save.duplicate(true)
	bad.territories.districts[target].occupation_stability = -1.0
	check(not session.validate(bad), "invalid stability rejected")
	bad = save.duplicate(true)
	bad.armies.occupations[target].house_id = "unknown_house"
	check(not session.validate(bad), "unknown claimant rejected")
	var enemy: Dictionary = unit.duplicate(true)
	enemy.id = "enemy_fixture"; enemy.house_id = record.house_id
	var cell: Vector2i = Grid.cell_at(army.node_point(unit.site_id))
	enemy.site_id = Grid.key(cell + Vector2i(1, 0))
	army.units.enemy_fixture = enemy
	army.on_day_advanced(1546, 1, 3)
	check(is_equal_approx(float(army.occupations[target].progress), progress), "adjacent enemy pauses control")
	enemy.site_id = unit.site_id
	army.on_day_advanced(1546, 1, 4)
	check(is_equal_approx(float(army.occupations[target].progress), progress), "contested office cannot be captured before field battle resolves")
	army.units.erase("enemy_fixture")
	var reinforcement: Dictionary = unit.duplicate(true)
	reinforcement.id = "reinforcement_fixture"
	army.units.reinforcement_fixture = reinforcement
	var doubled_rate: float = army.occupation_rate(target)
	army.on_day_advanced(1546, 1, 5)
	check(is_equal_approx(float(army.occupations[target].progress), progress + doubled_rate), "reinforcements aggregate into one district tick")
	check(doubled_rate > rate and doubled_rate < rate * 2.0, "diminishing returns for army splitting")
	army.units.erase("reinforcement_fixture")
	unit.soldiers = 100000
	check(army.occupation_rate(target) <= 50.0, "large armies cannot capture instantly")
	unit.soldiers = 1000
	progress = army.occupations[target].progress
	unit.site_id = unit.origin
	army._advance_occupations()
	check(is_equal_approx(float(army.occupations[target].progress), maxf(0.0, progress - 10.0)), "withdrawal decays progress")
	unit.site_id = "district:" + target
	army._advance_occupations()
	check(float(army.occupations[target].progress) > progress - 10.0, "return resumes the same claimant's progress")
	army.occupations[target].progress = 95.0
	army.on_day_advanced(1546, 1, 6)
	check(record.house_id == session.player_house and not army.occupations.has(target), "completed control transfers ownership once")
	check(float(record.occupation_stability) == 0.0 and int(record.sortie_troops) == 0, "capture begins unstable without inherited levy reserves")
	for site_id in record.site_ids: check(main.governance_registry.sites[site_id].house_id == session.player_house, "district buildings transfer with control")
	var unstable_income: int = main.district_economy.income_for(record, "commerce")
	record.occupation_stability = 100.0
	var normal_income: int = main.district_economy.income_for(record, "commerce")
	check(absi(unstable_income * 2 - normal_income) <= 1, "occupation income is halved with integer rounding")
	record.occupation_stability = 0.0
	record.sortie_troops = 1000
	check(main.district_actions.sortie_available(record) == 0, "unstable district blocks available troops")
	check(army.dispatch(target, [officer], 25, false, false).is_empty() and "統治" in army.last_error, "dispatch rejects unstable holdings")
	main.district_actions.on_day_advanced(1546, 2, 1)
	check(int(record.sortie_troops) == 1000, "monthly levy recovery pauses during instability")
	record.sortie_troops = 0
	check(is_equal_approx(army.stability_rate(target), 100.0 / 30.0), "garrison stabilizes in thirty days")
	unit.soldiers = 99
	check(is_equal_approx(army.stability_rate(target), 100.0 / 60.0), "token garrison does not accelerate stabilization")
	unit.soldiers = 1000
	var politics: int = main.district_economy.politics_for(officer)
	record.governor = {"officer_id":officer}
	check(is_equal_approx(army.stability_rate(target), (100.0 / 60.0) * (2.0 + float(politics) / 30.0)), "governor politics accelerates stabilization")
	record.governor = null
	army.units.enemy_fixture = enemy
	check(army.stability_rate(target) == 0.0, "enemy pressure pauses garrison stabilization")
	unit.site_id = unit.origin
	check(army.stability_rate(target) == -2.0, "enemy pressure worsens ungarrisoned governance")
	record.occupation_stability = 1.0
	army._advance_stability()
	check(float(record.occupation_stability) == 0.0 and record.house_id == session.player_house, "unrest is bounded and does not cause an unimplemented rebellion")
	army.units.erase("enemy_fixture")
	unit.site_id = "district:" + target
	for day in 30: army._advance_stability()
	check(float(record.occupation_stability) == 100.0, "garrison completes stabilization exactly after thirty days")
	main.district_actions.on_day_advanced(1546, 3, 1)
	check(main.district_actions.sortie_available(record) > 0 and main.district_economy.income_for(record, "commerce") == normal_income, "stability restores income and monthly recruitment")
	record.occupation_stability = 25.0
	var original_house: String = session.player_house
	var original_origin: String = unit.origin
	session.player_house = "takeda"
	unit.origin = unit.site_id # Safe return distance isolates the CPU garrison decision.
	main.cpu_controller.refresh_world()
	main.cpu_controller.missions[id] = {"target":unit.site_id, "initial_soldiers":1000, "returning":false}
	main.cpu_controller.command_armies(original_house)
	check(unit.next_site.is_empty() and unit.orders.is_empty() and not main.cpu_controller.missions[id].returning, "CPU holds a newly conquered office to stabilize it")
	session.player_house = original_house
	unit.origin = original_origin
	main.cpu_controller.plans.erase(original_house)
	check(session.save_game(main, 2) == OK, "unstable governance writes to disk")
	loaded = session.read_save(2)
	check(not loaded.is_empty() and float(loaded.territories.districts[target].occupation_stability) == 25.0, "unstable governance reads from disk")
	record.occupation_stability = 100.0
	session.pending = loaded
	session.apply_to(main)
	check(float(record.occupation_stability) == 25.0, "loading restores ongoing stabilization")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		main.district_info.set_district(target)
		main.district_info.show_district(record.name)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/occupation_stability.png")
	loaded = session.read_save(1)
	session.pending = loaded
	session.apply_to(main)
	check(army.occupations.has(target) and army.occupations[target].house_id == session.player_house, "partial control restores a pending claimant")
	var restored_progress: float = loaded.armies.occupations[target].progress
	check(is_equal_approx(float(army.occupations[target].progress), restored_progress), "loading restores exact partial control")
	army.on_day_advanced(1546, 1, 7)
	check(float(army.occupations[target].progress) > restored_progress, "loaded army resumes control")
	main.diplomacy.truces[session.pair(session.player_house, record.house_id)] = int(main.game_clock.elapsed_days) + 10
	army._advance_occupations()
	check(not army.occupations.has(target), "truce cancels control")
	main.diplomacy.truces.clear()
	session.relations[session.pair(session.player_house, record.house_id)] = "ally"
	army._arrive(id)
	army._advance_occupations()
	check(not army.occupations.has(target), "allied office cannot be occupied")
	loaded = session.read_save(3)
	session.relations = loaded.relations.duplicate(true)
	session.pending = loaded
	session.apply_to(main)
	check(int(record.loot_available_day) == 30 and army.loot_unavailable_reason(id).contains("あと30日"), "load restores ongoing loot cooldown")
	check(main.army_panel.loot_context_id.is_empty(), "loading requires selecting the office army again")
	# Unrecorded rulers are legitimate catalog data, including conquering CPU houses.
	var new_owner := "takeda"
	var old_ruler: Variant = main.governance_registry.houses[new_owner].ruler
	main.governance_registry.houses[new_owner].ruler = null
	army._capture_district(target, new_owner)
	check(record.house_id == new_owner and record.ruler == null and record.governor == null, "house without a ruler completes district capture")
	var borders: Node = main.territory_borders
	check(borders.projected[target].house_id == new_owner, "logical ownership is reflected before deferred geometry work")
	var geometry_size: int = borders.fade_geometry.size()
	borders._flush_band_updates()
	check(borders.fade_geometry.size() == geometry_size, "capture reuses projected geometry instead of reloading regions")
	check(borders.pending_district_houses.is_empty(), "coalesced ownership display refresh drains changed houses")
	for site_id in record.get("site_ids", []):
		check(main.governance_registry.sites[site_id].house_id == new_owner and main.governance_registry.sites[site_id].ruler == null, "unknown ruler also transfers district sites")
	main.governance_registry.houses[new_owner].ruler = old_ruler
	print("Occupation control, contest, retreat, income, levy, stabilization, CPU and save checks: %d failures" % failures)
	quit(1 if failures else 0)
