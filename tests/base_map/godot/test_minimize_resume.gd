extends SceneTree
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func run() -> void:
	root.get_node("GameSession").new_game("uesugi_yamanouchi")
	while current_scene == null or not current_scene.initialized: await process_frame
	var main: Node = current_scene
	var clock: Node = main.game_clock
	clock.set_process(false)
	main.cpu_controller.set_process(false)
	main.cpu_controller.enabled = false
	clock.paused = false
	var before: int = clock.elapsed_days
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	await process_frame
	await process_frame
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED, "real window minimizes")
	main.time_hud._resize()
	main.house_status_hud._resize()
	check(main.time_hud.panel.size.is_finite() and main.house_status_hud.panel.size.is_finite(), "minimized HUD dimensions remain finite")
	clock.backlog_days = 1.0
	clock._last_tick_usec = Time.get_ticks_usec() - 1000000
	clock._sync_elapsed_time()
	check(clock.elapsed_days == before and clock.backlog_days == 0.0, "minimized time does not advance or accumulate")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await process_frame
	await process_frame
	main.time_hud._resize()
	main.house_status_hud._resize()
	check(main.time_hud.panel.size.is_finite() and main.house_status_hud.panel.size.is_finite(), "restored HUD dimensions remain finite")
	clock.set_process(true)
	main.cpu_controller.set_process(true)
	var deadline := Time.get_ticks_msec() + 3000
	while clock.elapsed_days == before and Time.get_ticks_msec() < deadline: await process_frame
	check(clock.elapsed_days > before, "restored game resumes real-time progression")
	print("MINIMIZE_RESUME failures=", failures)
	quit(1 if failures else 0)
