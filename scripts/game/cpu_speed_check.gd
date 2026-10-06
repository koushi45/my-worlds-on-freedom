extends Node
## Real rendered benchmark; never advances the clock manually.
var main: Node
var initial_armies := 0

func _ready() -> void: call_deferred("run")

func option(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="): return arg.get_slice("=", 1)
	return fallback

func run() -> void:
	var session: Node = get_tree().root.get_node("GameSession")
	if "--cpu-speed-check" not in OS.get_cmdline_user_args(): session.new_game("uesugi_yamanouchi")
	while get_tree().current_scene == null or not get_tree().current_scene.initialized: await get_tree().process_frame
	main = get_tree().current_scene
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if main.cpu_controller.has_method("reset_profile"):
		main.cpu_controller.profile_enabled = option("profile", "on") == "on"
		main.game_clock.profile_enabled = option("profile", "on") == "on"
	main.game_clock.paused = true
	await get_tree().process_frame
	var snapshot: Dictionary = session.capture(main)
	initial_armies = main.army_campaign.units.size()
	var seconds := float(option("seconds", "60"))
	var repeats := int(option("repeats", "3"))
	var results: Array = []
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for fps in option("fps", "30,60").split(","):
		Engine.max_fps = int(fps)
		for speed_text in option("speeds", "1,2,4,8,16").split(","):
			for repeat in range(repeats):
				session.pending = snapshot.duplicate(true)
				session.apply_to(main)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				main.game_clock.paused = true
				main.cpu_controller.enabled = option("mode", "normal") != "no-ai"
				main.game_clock.diagnostic_draw_wait = option("mode", "normal") == "legacy-draw"
				var until := Time.get_ticks_msec() + 2000
				while Time.get_ticks_msec() < until: await get_tree().process_frame
				main.game_clock.set_speed(int(speed_text))
				main.game_clock._last_tick_usec = Time.get_ticks_usec()
				seed(int(option("seed", "1546")))
				main.game_clock.paused = false
				if main.cpu_controller.has_method("reset_profile"): main.cpu_controller.reset_profile()
				var first: float = float(main.game_clock.elapsed_days) + float(main.game_clock._day_fraction)
				var started := Time.get_ticks_usec()
				var previous := started
				var frame_ms: Array = []
				var active_usec := 0
				var progress_windows: Array = []
				var window_started := 0
				var window_first := first
				while active_usec < seconds * 1000000.0:
					await get_tree().process_frame
					var now := Time.get_ticks_usec()
					var elapsed := now - previous
					previous = now
					if main.game_clock.paused or main.game_clock.suspended or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED: continue
					active_usec += elapsed
					frame_ms.append(float(elapsed) / 1000.0)
					if active_usec - window_started >= 10000000:
						var current_days: float = float(main.game_clock.elapsed_days) + float(main.game_clock._day_fraction)
						var window_seconds := float(active_usec - window_started) / 1000000.0
						progress_windows.append({"seconds":window_seconds, "days_per_second":(current_days - window_first) / window_seconds,
							"backlog_days":main.game_clock.backlog_days, "pending_jobs":main.cpu_controller.work_queue.size(),
							"queued_searches":main.cpu_controller.route_requests.size()})
						window_started = active_usec
						window_first = current_days
				main.game_clock.paused = true
				var duration := float(active_usec) / 1000000.0
				var progressed: float = float(main.game_clock.elapsed_days) + float(main.game_clock._day_fraction) - first
				frame_ms.sort()
				var row := {"fps_limit":int(fps), "speed":int(speed_text), "repeat":repeat, "seconds":duration,
					"cpu_budget_fraction":main.cpu_controller.cpu_budget_fraction, "route_workers":main.cpu_controller.route_worker_limit,
					"wall_seconds":float(previous - started) / 1000000.0,
					"progress_windows":progress_windows,
					"days":progressed, "days_per_second":progressed / duration, "fps":frame_ms.size() / duration,
					"frame_p95_ms":frame_ms[int(frame_ms.size() * 0.95)], "frame_p99_ms":frame_ms[int(frame_ms.size() * 0.99)], "frame_max_ms":frame_ms.back(),
					"armies":main.army_campaign.units.size(), "godot_static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "render_buffer_mib":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, "maximum_cpu_frame_ms":main.cpu_controller.maximum_frame_usec / 1000.0}
				if main.cpu_controller.has_method("profile_report"): row["profile"] = main.cpu_controller.profile_report()
				row["save_valid"] = session.validate(session.capture(main))
				row["indexes_valid"] = indexes_valid()
				if not row.save_valid: printerr("FAIL: benchmark end-state save validation")
				if not row.indexes_valid: printerr("FAIL: benchmark end-state formation indexes")
				results.append(row)
				print("CPU_BENCHMARK fps=", fps, " speed=", speed_text, " repeat=", repeat, " days/sec=", snappedf(row.days_per_second, 0.001), " armies=", row.armies, " frame_p95_ms=", row.frame_p95_ms)
				write_results(results)
	write_results(results)
	get_tree().quit(0 if results.all(func(row: Dictionary): return row.save_valid and row.indexes_valid) else 1)

func indexes_valid() -> bool:
	var cpu: Node = main.cpu_controller
	var army: Node = main.army_campaign
	cpu._refresh_unit_index()
	var deployed := {}
	for unit in army.units.values():
		if unit.id not in cpu.formations.get(unit.house_id, []): return false
		for officer in army.officer_pool(unit): deployed[officer] = true
		var cell := Vector2i(army.unit_position(unit) / 64.0)
		if cpu.unit_cells.get(unit.id) != cell or unit.id not in cpu.army_regions.get(cell, []): return false
	for ids in cpu.formations.values():
		for id in ids:
			if not army.units.has(id): return false
	return deployed == cpu.deployed_officers

func write_results(results: Array) -> void:
	var path := option("output", "res://builds/qa/cpu_thinking_benchmark.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(), "seed":int(option("seed", "1546")), "profile":option("profile", "on"), "initial_armies":initial_armies, "requested_armies":0, "mode":option("mode", "normal"), "scenario":"normal", "results":results}, "\t"))

