extends SceneTree

const Grid = preload("res://scripts/map/hex_grid.gd")
var failures := 0
var main: Node
var session: Node

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/qa/" + name + ".png")

func run() -> void:
	session = root.get_node("GameSession")
	session.player_house = "hojo"
	session.save_directory = "user://qa_merge_%d" % OS.get_process_id()
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized): await process_frame
	if current_scene == null or not current_scene.initialized: printerr("FAIL: map initialization"); quit(1); return
	main = current_scene; main.game_clock.paused = true
	main.cpu_controller.enabled = false; main.cpu_controller.work_queue.clear()
	var army: Node = main.army_campaign
	var home := ""
	for district_id in main.district_office_layer.records:
		if main.governance_registry.districts[district_id].house_id == session.player_house: home = district_id; break
	var ids: Array = main.retainer_management.house_members[session.player_house].duplicate()
	var ruler: String = main.retainer_management.ruler_id(session.player_house)
	if ruler not in ids: ids.append(ruler)
	check(ids.size() >= 6 and not home.is_empty(), "six officer fixture available")
	if ids.size() < 6 or home.is_empty(): quit(1); return
	ids = ids.slice(0, 6)
	for officer_id in ids: main.retainer_management.place_officer(session.player_house, officer_id, home)
	main.governance_registry.districts[home].sortie_troops = 20000
	main.governance_registry.districts[home].population = 200000
	main.district_economy.house_resources[session.player_house].provisions = 100000
	var first: String = army.dispatch(home, ids.slice(0, 3), 25, false, false)
	var second: String = army.dispatch(home, ids.slice(3, 6), 25, false, false)
	if first.is_empty() or second.is_empty(): printerr("FAIL: dispatch: " + army.last_error); quit(1); return
	var unit: Dictionary = army.units[first]
	var other: Dictionary = army.units[second]
	unit.soldiers = 100; unit.supply_days = 30
	other.soldiers = 301; other.supply_days = 90
	unit.horses = true; unit.horse_count = 20
	other.guns = true; other.gun_count = 60
	var old_origin: String = unit.origin
	var cell := Grid.cell_at(army.unit_position(unit))
	check(not army.merge(first, first), "cannot merge a unit with itself")
	other.house_id = "uesugi_yamanouchi"
	check(not army.merge(first, second), "cannot merge another house's army")
	other.house_id = unit.house_id
	other.next_site = Grid.key(cell + Vector2i(1, 0))
	check(not army.merge(first, second), "cannot merge a moving army")
	other.next_site = ""; other.site_id = Grid.key(cell + Vector2i(1, 0))
	check(not army.merge(first, second), "cannot merge armies on different tiles")
	other.site_id = Grid.key(cell)
	var enemy: Dictionary = unit.duplicate(true)
	enemy.id = "defender"; enemy.house_id = "uesugi_yamanouchi"
	army.units.defender = enemy
	session.relations[session.pair(unit.house_id, "uesugi_yamanouchi")] = "enemy"
	check(not army.merge(first, second), "cannot merge during melee")
	army.units.erase("defender")
	unit.orders = [Grid.key(cell + Vector2i(1, 0))]
	unit.automatic = {"mode":"occupy", "house_id":"uesugi_yamanouchi", "initial_soldiers":100, "returning":false, "target_unit":"", "status":"test"}
	main.army_panel.show_unit(first)
	main.army_panel._open_merge()
	check(main.army_panel.merge_ids == [second], "merge dialog offers the colocated stationary unit")
	await capture("army_merge_selection")
	main.army_panel.merge_dialog.hide()
	main.army_panel.merge_dialog.confirmed.emit()
	check(army.units.has(first) and not army.units.has(second), "merge keeps selected army and removes partner")
	check(unit.soldiers == 401 and is_equal_approx(float(unit.supply_days) * 401.0, 30090.0), "merge conserves soldiers and fractional soldier-days of food")
	check(unit.horse_count == 20 and unit.gun_count == 60, "mixed equipment does not create additional horses or guns")
	check(unit.origin == old_origin and unit.automatic == null and unit.orders.is_empty(), "merge preserves return destination and clears previous orders")
	check(army.officer_pool(unit).size() == 6 and unit.officers.size() == 3, "all six officers remain in pool while three hold command")
	var top_command := 0.0
	for officer_id in ids: top_command = maxf(top_command, army.score(officer_id))
	check(is_equal_approx(army.score(unit.officers[0]), top_command), "general automatically chosen by command ability")
	var deputy_min := minf(float(main.officer_registry.ability(unit.officers[1], "tactics")), float(main.officer_registry.ability(unit.officers[2], "tactics")))
	for officer_id in ids:
		if officer_id not in unit.officers: check(float(main.officer_registry.ability(officer_id, "tactics")) <= deputy_min, "deputies automatically selected by valor")
	check(main.army_panel.commanders_dialog.visible, "successful merge immediately opens commander editing")
	await capture("army_merge_commanders")
	var before: Array = unit.officers.duplicate()
	var unselected := ""
	for officer_id in ids:
		if officer_id not in unit.officers: unselected = officer_id; break
	main.army_panel.commander_choices[0].item_selected.emit(main.army_panel.commander_pool.find(unselected))
	check(unit.officers[0] == unselected, "player can promote an accompanying officer")
	var deputy: String = unit.officers[1]
	main.army_panel.commander_choices[0].item_selected.emit(main.army_panel.commander_pool.find(deputy))
	check(unit.officers[0] == deputy and unit.officers[1] == unselected, "choosing a current deputy swaps roles without duplication")
	check(not army.set_commanders(first, [deputy, deputy]) and not army.set_commanders(first, ["invalid"]), "invalid or duplicated commanders rejected")
	for officer_id in ids:
		check(officer_id not in army.available_officers(home), "accompanying officers cannot dispatch in another army")
		check(main.retainer_management.place_officer(unit.house_id, officer_id, "") == ERR_BUSY, "accompanying officers cannot be moved out of the army")
	main.army_panel.commanders_dialog.hide()
	unit.supply_days = 75.25
	check(session.save_game(main, 1) == OK, "merged unit saves with fractional food and officer pool")
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty() and saved.version == 30 and saved.armies.units[first].officer_pool.size() == 6, "current save contains merged army")
	var bad: Dictionary = saved.duplicate(true)
	bad.armies.units[first].officer_pool.append(ids[0])
	check(not session.validate(bad), "duplicate accompanying officer rejected")
	unit.officers = before
	session.pending = saved; session.relations = saved.relations.duplicate(true); session.apply_to(main)
	unit = army.units[first]
	check(unit.officers[0] == deputy and is_equal_approx(float(unit.supply_days), 75.25) and unit.horse_count == 20 and unit.gun_count == 60, "load restores edited roles, exact food and mixed equipment")
	main.army_panel.show_unit(first)
	main.army_panel._open_commanders()
	check(main.army_panel.commander_pool.size() == 6, "full merged pool remains editable after loading")
	main.army_panel.commanders_dialog.hide()
	var stock: Dictionary = main.district_economy.house_resources[unit.house_id]
	var horses_before: int = stock.get("horses", 0)
	var guns_before: int = stock.get("guns", 0)
	check(army.return_home(first) and not army.units.has(first), "merged army returns and disbands normally")
	check(stock.horses == horses_before + 20 and stock.guns == guns_before + 60, "return refunds only actual mixed equipment")
	for officer_id in ids: check(officer_id in army.available_officers(home), "return releases all accompanying officers")
	print("Army merge, automatic commanders, editing, conservation, restrictions and save checks: %d failures" % failures)
	quit(1 if failures else 0)
