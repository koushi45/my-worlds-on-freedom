extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

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
	var session := root.get_node("GameSession")
	var actor: String = session.player_house
	var target := "takeda"
	var diplomacy: Node = main.diplomacy
	main.game_clock.set_process(false)
	# Keep individual diplomacy commands isolated from autonomous CPU peace decisions.
	main.cpu_controller.enabled = false
	check(diplomacy.opinion(target, actor) == 0, "unknown relation starts neutral")
	main.game_menu.toggle_council()
	main.game_menu.show_diplomacy()
	await process_frame
	check(main.game_menu.diplomacy_panel.visible, "council opens diplomacy")
	check(main.game_menu.diplomacy_panel.house_ids.has(target), "diplomacy lists active houses")
	var panel: Control = main.game_menu.diplomacy_panel
	var other := ""
	for id in panel.house_ids:
		if id != target:
			other = id
			break
	var original_districts: Dictionary = main.governance_registry.districts
	main.governance_registry.districts = {
		"home": {"house_id": actor, "point": [0, 0]},
		"remote_home": {"house_id": actor, "point": [1000, 0]},
		"near_remote": {"house_id": target, "point": [999, 0]},
		"near_home": {"house_id": other, "point": [100, 0]},
	}
	panel._fill_houses()
	check(panel.house_ids == [target, other], "nearest pair across all owned districts determines order")
	main.governance_registry.districts.near_remote.house_id = other
	panel._fill_houses()
	check(panel.house_ids == [other], "list follows ownership changes and excludes landless houses")
	main.governance_registry.districts = original_districts
	panel._fill_houses()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/diplomacy_panel.png")
	main.game_menu.diplomacy_panel.close_panel()
	check(not main.game_menu.council_menu.visible and not paused, "close dismisses council management")
	var target_district := ""
	var own_district := ""
	for id in original_districts:
		if original_districts[id].house_id == target: target_district = id
		if original_districts[id].house_id == actor: own_district = id
	panel.search.text = "該当しない家名"
	var office: Vector2 = main.district_office_layer.office_point(target_district)
	main.camera.position = main.elevation.project(office)
	main.set_map_zoom(2.0)
	for index in 10: await process_frame
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = main.world_to_screen(office)
	root.push_input(right, true)
	deadline = Time.get_ticks_msec() + 15000
	while not panel.visible and Time.get_ticks_msec() < deadline: await process_frame
	check(panel.visible and panel.selected == target and panel.search.text.is_empty(), "right click opens owner diplomacy and clears old search")
	check(panel.house_ids[panel.house_list.get_selected_items()[0]] == target, "right click selects owner in list")
	panel.close_panel()
	# Also cover polygon picking while administrative tiles are hidden at low zoom.
	main.set_map_zoom(1.0)
	for index in 10: await process_frame
	await main._select_district_async(main.world_to_screen(office), false, true)
	check(panel.visible and panel.selected == target, "district polygon opens diplomacy below hex display zoom")
	panel.close_panel()
	main._open_district_diplomacy(own_district)
	check(not panel.visible and not paused, "own district does not open foreign diplomacy")
	var previous_owner: String = original_districts[target_district].house_id
	original_districts[target_district].house_id = other
	main._open_district_diplomacy(target_district)
	check(panel.visible and panel.selected == other, "district shortcut follows current owner")
	panel.close_panel()
	original_districts[target_district].house_id = previous_owner
	check(diplomacy.act("ally", actor, target) == ERR_UNAVAILABLE, "alliance needs acceptance")
	check(diplomacy.act("envoy", actor, target) == OK, "envoy assigned")
	diplomacy.on_day_advanced(1546, 2, 1)
	check(diplomacy.opinion(target, actor) == 5, "envoy raises target opinion monthly")
	check(diplomacy.act("recall", actor, target) == OK, "envoy recalled")
	main.district_economy.house_resources[actor].money = 300.0
	check(diplomacy.act("gift", actor, target) == OK, "gift accepted")
	check(diplomacy.opinion(target, actor) == 25, "gift raises target opinion")
	check(is_equal_approx(float(main.district_economy.house_resources[actor].money), 200.0), "gift deducts money")
	check(diplomacy.act("gift", actor, target) == ERR_UNAVAILABLE, "diplomatic cooldown")
	await advance_days(main.game_clock, 30)
	diplomacy.change_opinion(target, actor, 20)
	check(diplomacy.act("ally", actor, target) == OK, "alliance forms above threshold")
	check(session.relation(actor, target) == "ally", "alliance uses map relation")
	var saved: Dictionary = session.capture(main)
	check(session.validate(saved), "diplomacy save validates")
	diplomacy.change_opinion(target, actor, -30)
	diplomacy.restore_state(saved.diplomacy)
	check(diplomacy.opinion(target, actor) == int(saved.diplomacy.opinions[target + ">" + actor]), "diplomacy state restores")
	await advance_days(main.game_clock, 30)
	check(diplomacy.act("break_ally", actor, target) == OK, "alliance can be broken")
	check(session.relation(actor, target) == "neutral", "broken alliance is neutral")
	await advance_days(main.game_clock, 30)
	check(diplomacy.act("war", actor, target) == OK, "war declaration")
	check(session.relation(actor, target) == "enemy", "war is visible as enemy")
	await advance_days(main.game_clock, 30)
	diplomacy.change_opinion(target, actor, 100)
	check(diplomacy.act("peace", actor, target) == OK, "peace succeeds after relations improve")
	check(session.relation(actor, target) == "neutral" and diplomacy.truce_remaining(actor, target) > 0, "peace establishes truce")
	check(diplomacy.act("war", actor, target) == ERR_UNAVAILABLE, "truce blocks war")
	check(session.validate(session.capture(main)), "post-action save validates")
	session.save_directory = "user://qa_diplomacy_%d" % OS.get_process_id()
	check(session.save_game(main, 1) == OK, "diplomacy writes save")
	var loaded: Dictionary = session.read_save(1)
	check(not loaded.is_empty() and int(loaded.diplomacy.opinions[target + ">" + actor]) == diplomacy.opinion(target, actor) and int(loaded.diplomacy.truces[session.pair(actor, target)]) == int(diplomacy.truces[session.pair(actor, target)]), "diplomacy loads from disk")
	test_diplomat_limit(main, session, actor, target, other)
	await test_espionage(main, session, actor, target, other, target_district)
	print("diplomacy failures: %d" % failures)
	quit(1 if failures else 0)

func test_diplomat_limit(main: Node, session: Node, actor: String, target: String, other: String) -> void:
	var d: Node = main.diplomacy
	var before: Dictionary = d.save_state()
	d.envoys.clear()
	d.spies.clear()
	d.spy_networks.clear()
	d.opinions.clear()
	check(d.act("envoy", actor, target) == OK and d.act("envoy", actor, other) == OK, "two improvement diplomats can work together")
	check(d.act("build_spy_network", actor, target) == OK and d.diplomats_used(actor) == 3, "improvement and spies share three slots")
	check(d.act("build_spy_network", actor, other) == ERR_UNAVAILABLE and not d.has_spy(actor, other), "fourth diplomat blocked without replacing assignments")
	check(d.act("recall", actor, other) == OK and d.act("build_spy_network", actor, other) == OK, "recall frees shared slot for espionage")
	d.on_day_advanced(1546, 2, 1)
	check(d.spy_value(actor, target) == 5 and d.spy_value(actor, other) == 5 and d.opinion(target, actor) == 5, "all three assignments advance each month")
	check(d.act("envoy", actor, other) == ERR_UNAVAILABLE, "full espionage slots also block improvement")
	check(d.act("envoy", actor, target) == ERR_UNAVAILABLE and d.diplomats_used(actor) == 3, "duplicate assignment does not consume slot")
	var saved: Dictionary = session.capture(main)
	check(session.validate(saved), "mixed three diplomat save validates")
	check(session.save_game(main, 3) == OK, "three diplomat assignments saved to disk")
	var loaded: Dictionary = session.read_save(3)
	d.envoys.clear()
	d.spies.clear()
	d.restore_state(loaded.diplomacy)
	check(d.diplomats_used(actor) == 3 and d.has_spy(actor, other) and d.has_envoy(actor, target), "three diplomat assignments restored from disk")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.diplomacy.envoys[actor].append(other)
	check(not session.validate(malformed), "save exceeding shared limit rejected")
	malformed = saved.duplicate(true)
	malformed.diplomacy.spies[actor].append(target)
	check(not session.validate(malformed), "duplicate diplomat save rejected")
	d.opinions[target + ">" + actor] = 95
	d.on_day_advanced(1546, 3, 1)
	check(d.diplomats_used(actor) == 2 and not d.has_envoy(actor, target), "completed improvement releases diplomat")
	check(d.act("envoy", actor, other) == OK, "released diplomat can begin new improvement")
	d.restore_state(before)

func test_espionage(main: Node, session: Node, actor: String, target: String, other: String, district_id: String) -> void:
	var d: Node = main.diplomacy
	d.last_actions.clear()
	d.truces.clear()
	session.relations[session.pair(actor, target)] = "neutral"
	check(d.act("fabricate_claim", actor, target, district_id) == ERR_UNAVAILABLE and d.spy_value(actor, target) == 0, "insufficient espionage cannot create claim")
	check(d.act("build_spy_network", actor, target) == OK, "spy dispatched")
	d.advance_spy_month()
	check(d.spy_value(actor, target) == 5, "active network gains five per month")
	for month in 21: d.advance_spy_month()
	check(d.spy_value(actor, target) == 100, "active network builds and caps at 100")
	check(d.act("recall_spy", actor, target) == OK, "spy recalled")
	d.advance_spy_month()
	check(d.spy_value(actor, target) == 98, "inactive network decays")
	check(d.act("fabricate_claim", actor, target) == ERR_UNAVAILABLE and d.spy_value(actor, target) == 98, "claim requires explicit district without spending")
	var panel: Control = main.game_menu.diplomacy_panel
	main.game_menu.show_diplomacy()
	panel.selected = target
	panel._refresh()
	for frame in 3: await process_frame
	panel.details.get_parent().scroll_vertical = int(panel.details.get_parent().get_v_scroll_bar().max_value)
	for frame in 3: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/espionage_panel.png")
	panel._act("fabricate_claim")
	check(panel.claim_dialog.visible and panel.claim_ids.has(district_id), "claim action opens district selector")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/espionage_claim_dialog.png")
	panel.claim_choice.select(panel.claim_ids.find(district_id))
	panel._confirm_claim()
	panel.claim_dialog.hide()
	panel.close_panel()
	check(d.spy_value(actor, target) == 78 and d.claim_remaining(actor, district_id) == 1825, "confirmed claim costs 20 and lasts 1825 days")
	d.last_actions.clear()
	check(d.act("fabricate_claim", actor, target, district_id) == ERR_UNAVAILABLE and d.spy_value(actor, target) == 78, "duplicate claim cannot spend points")
	var previous_prestige: float = main.house_prestige.value_for(actor)
	check(d.act("war", actor, target) == OK and main.house_prestige.value_for(actor) == previous_prestige, "claim justifies war without prestige loss")
	var old_owner: String = main.governance_registry.districts[district_id].house_id
	main.governance_registry.districts[district_id].house_id = other
	check(not d.has_claim_against(actor, target) and d.has_claim_against(actor, other), "claim follows current ownership")
	main.governance_registry.districts[district_id].house_id = actor
	check(not d.has_claim_against(actor, target), "acquired district cannot justify war against former owner")
	main.governance_registry.districts[district_id].house_id = old_owner
	var record: Dictionary = main.governance_registry.districts[district_id]
	var base_income: int = main.district_economy.potential_income_for(record, "commerce")
	var base_food: int = main.district_economy.potential_income_for(record, "agriculture")
	for action in ["sow_discontent", "sabotage_reputation", "sabotage_recruitment", "slander_merchants"]:
		d.last_actions.clear()
		d.spy_networks[actor + ">" + target] = 100
		check(d.act(action, actor, target) == OK and d.spy_value(actor, target) == 100 - int(d.SPY_COSTS[action]), "working espionage spends " + action)
		check(d.act(action, actor, target) == ERR_UNAVAILABLE, "cooldown blocks " + action)
		d.last_actions.clear()
		check(d.act(action, actor, target) == ERR_UNAVAILABLE, "active effect blocks duplicate " + action)
	var previous_security: int = record.security
	d.advance_spy_month()
	check(record.security == maxi(0, previous_security - 3), "discontent lowers district security")
	check(main.district_economy.potential_income_for(record, "commerce") == roundi(base_income * 0.75), "merchant slander reduces actual commerce income")
	check(main.district_economy.potential_income_for(record, "agriculture") == base_food, "merchant slander leaves provisions alone")
	var capacity: int = main.district_actions.sortie_capacity(record)
	record.sortie_troops = 0
	main.district_actions.on_day_advanced(1546, 2, 1)
	check(record.sortie_troops == floori(maxi(1, ceili(capacity * 0.01)) * 0.8), "recruitment sabotage reduces real recovery")
	d.opinions[other + ">" + target] = 50
	check(d.opinion(other, target) == 30, "reputation changes effective opinion")
	d.change_opinion(other, target, 5)
	check(d.opinions[other + ">" + target] == 55 and d.opinion(other, target) == 35, "opinion edits preserve temporary reputation modifier")
	d.last_actions.clear()
	d.spy_networks[actor + ">" + target] = 100
	check(d.act("counterespionage", actor, target) == ERR_UNAVAILABLE, "counterespionage needs hostile network")
	d.spy_networks[target + ">" + actor] = 15
	check(d.act("counterespionage", actor, target) == OK and d.spy_value(target, actor) == 0 and d.spy_value(actor, target) == 70, "counterespionage deducts cost and floors hostile network")
	d.last_actions.clear()
	session.relations[session.pair(actor, target)] = "ally"
	check(d.act("sow_discontent", actor, target) == ERR_UNAVAILABLE, "hostile work cannot target ally")
	session.relations[session.pair(actor, target)] = "enemy"
	check(d.act("build_spy_network", actor, target) == OK, "spy dispatch available during war")
	var saved: Dictionary = session.capture(main)
	check(session.validate(saved), "espionage save validates")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.diplomacy.spy_networks[actor + ">" + target] = 101
	check(not session.validate(malformed), "out of range network rejected")
	malformed = saved.duplicate(true)
	malformed.diplomacy.claims[actor]["missing_district"] = 100
	check(not session.validate(malformed), "unknown claim district rejected")
	check(session.save_game(main, 2) == OK, "espionage writes disk save")
	var loaded: Dictionary = session.read_save(2)
	d.spy_networks.clear()
	d.claims.clear()
	d.spy_effects.clear()
	d.spies.clear()
	d.restore_state(loaded.diplomacy)
	check(d.spy_value(actor, target) == 70 and d.has_spy(actor, target) and d.has_claim_against(actor, target) and d.effect_active("slander_merchants", target), "networks spies claims and effects restore from disk")
	var elapsed: int = main.game_clock.elapsed_days
	main.game_clock.elapsed_days = elapsed + 360
	check(not d.effect_active("slander_merchants", target) and d.opinion(other, target) == 55 and main.district_economy.potential_income_for(record, "commerce") == base_income, "effects expire and economic opinion modifiers recover")
	main.game_clock.elapsed_days = elapsed + 1825
	check(not d.has_claim_against(actor, target), "claims expire at deadline")
	main.game_clock.elapsed_days = elapsed

func advance_days(clock: Node, count: int) -> void:
	for index in range(count):
		var previous: int = clock.elapsed_days
		while clock.elapsed_days == previous:
			clock.advance_real_seconds(1.0 / clock.speed)
			await process_frame
