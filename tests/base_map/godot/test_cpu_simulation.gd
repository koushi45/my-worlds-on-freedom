extends SceneTree
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func run() -> void:
	var session: Node = root.get_node("GameSession")
	session.new_game("uesugi_yamanouchi")
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and (current_scene == null or not current_scene.initialized): await process_frame
	if current_scene == null or not current_scene.initialized: printerr("FAIL: map initialization"); quit(1); return
	var main: Node2D = current_scene
	main.game_clock.set_process(false)
	main.army_campaign.set_process(false)
	var maximum_usec := 0
	var total_usec := 0
	var dispatched := false
	var marched := false
	for i in range(35):
		var before: Dictionary = {}
		for unit in main.army_campaign.units.values(): before[unit.id] = main.army_campaign.unit_position(unit)
		var start := Time.get_ticks_usec()
		var previous_day: int = main.game_clock.elapsed_days
		while main.game_clock.elapsed_days == previous_day:
			main.game_clock.advance_real_seconds(1.0)
			await process_frame
		var duration := Time.get_ticks_usec() - start
		maximum_usec = maxi(maximum_usec, duration)
		total_usec += duration
		for unit in main.army_campaign.units.values():
			if unit.house_id != session.player_house: dispatched = true
		for unit in main.army_campaign.units.values():
			if before.has(unit.id) and before[unit.id].distance_to(main.army_campaign.unit_position(unit)) > 0: marched = true
		if i % 7 == 6:
			var saved: Dictionary = session.capture(main)
			check(session.validate(saved), "active nationwide simulation produces valid save on day %d" % (i + 1))
			print("CPU_SIMULATION day=", i + 1, " armies=", main.army_campaign.units.size(), " wars=", main.diplomacy.wars.size(), " update_ms=", duration / 1000.0)
		await process_frame
	check(dispatched and marched, "unmodified scenario CPU armies dispatch and march")
	check(not main.cpu_controller.plans.has(session.player_house), "player house is never controlled by CPU")
	for unit in main.army_campaign.units.values(): check(unit.soldiers > 0, "all living units have troops")
	for resources in main.district_economy.house_resources.values(): check(resources.money >= 0 and resources.provisions >= 0, "CPU resources never go negative")
	print("CPU_SIMULATION failures=", failures, " mean_ms=", total_usec / 35000.0, " max_ms=", maximum_usec / 1000.0, " max_cpu_frame_ms=", main.cpu_controller.maximum_frame_usec / 1000.0)
	quit(1 if failures else 0)
