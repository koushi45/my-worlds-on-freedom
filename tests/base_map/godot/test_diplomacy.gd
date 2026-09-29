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
	check(diplomacy.opinion(target, actor) == 0, "unknown relation starts neutral")
	main.game_menu.toggle_council()
	main.game_menu.show_diplomacy()
	await process_frame
	check(main.game_menu.diplomacy_panel.visible, "council opens diplomacy")
	check(main.game_menu.diplomacy_panel.house_ids.has(target), "diplomacy lists active houses")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/diplomacy_panel.png")
	main.game_menu.diplomacy_panel.close_panel()
	check(main.game_menu.council_menu.visible, "close returns to council")
	main.game_menu.toggle_council()
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
	main.game_clock.advance_real_seconds(30.0)
	diplomacy.change_opinion(target, actor, 20)
	check(diplomacy.act("ally", actor, target) == OK, "alliance forms above threshold")
	check(session.relation(actor, target) == "ally", "alliance uses map relation")
	var saved: Dictionary = session.capture(main)
	check(session.validate(saved), "diplomacy save validates")
	diplomacy.change_opinion(target, actor, -30)
	diplomacy.restore_state(saved.diplomacy)
	check(diplomacy.opinion(target, actor) == int(saved.diplomacy.opinions[target + ">" + actor]), "diplomacy state restores")
	main.game_clock.advance_real_seconds(30.0)
	check(diplomacy.act("break_ally", actor, target) == OK, "alliance can be broken")
	check(session.relation(actor, target) == "neutral", "broken alliance is neutral")
	main.game_clock.advance_real_seconds(30.0)
	check(diplomacy.act("war", actor, target) == OK, "war declaration")
	check(session.relation(actor, target) == "enemy", "war is visible as enemy")
	main.game_clock.advance_real_seconds(30.0)
	diplomacy.change_opinion(target, actor, 100)
	check(diplomacy.act("peace", actor, target) == OK, "peace succeeds after relations improve")
	check(session.relation(actor, target) == "neutral" and diplomacy.truce_remaining(actor, target) > 0, "peace establishes truce")
	check(diplomacy.act("war", actor, target) == ERR_UNAVAILABLE, "truce blocks war")
	check(session.validate(session.capture(main)), "post-action save validates")
	session.save_directory = "user://qa_diplomacy_%d" % OS.get_process_id()
	check(session.save_game(main, 1) == OK, "diplomacy writes save")
	var loaded: Dictionary = session.read_save(1)
	check(not loaded.is_empty() and int(loaded.diplomacy.opinions[target + ">" + actor]) == diplomacy.opinion(target, actor) and int(loaded.diplomacy.truces[session.pair(actor, target)]) == int(diplomacy.truces[session.pair(actor, target)]), "diplomacy loads from disk")
	print("diplomacy failures: %d" % failures)
	quit(1 if failures else 0)
