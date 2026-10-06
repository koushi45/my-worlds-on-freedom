extends SceneTree
var failures := 0
var accepted_days := 0.0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func run() -> void:
	var session: Node = root.get_node("GameSession")
	session.save_directory = "user://qa_day_barrier_%d" % OS.get_process_id()
	session.new_game("uesugi_yamanouchi")
	while current_scene == null or not current_scene.initialized: await process_frame
	var main: Node = current_scene
	var clock: Node = main.game_clock
	var cpu: Node = main.cpu_controller
	clock.set_process(false)
	cpu.set_process(false)
	cpu.enabled = false
	cpu.work_queue.clear()
	clock.work_started = false
	clock._day_fraction = 0.0
	clock.backlog_days = 0.0
	clock.simulation_advanced.connect(func(days: float): accepted_days += days)
	clock.speed = 8
	var actor: String = session.player_house
	main.house_prestige.values[actor] = 20.125
	main.house_prestige.on_court_rank_granted(actor, 2)
	var target: float = main.house_prestige.baseline_for(actor)
	var today: int = clock.elapsed_days
	clock.advance_real_seconds(100.0)
	check(clock.elapsed_days == today and cpu.has_pending_daily_work(), "mandatory rules hold the date")
	check(accepted_days == 0.0, "movement waits for mandatory state")
	for index in range(4): clock.advance_real_seconds(100.0)
	check(clock.backlog_days == 8.0, "long stalls retain at most eight days")
	check(cpu.work_queue.size() == 8, "waiting never duplicates mandatory rules")
	cpu._process(0.0)
	var remaining: Array = cpu.work_queue.duplicate(true)
	check(session.save_game(main, 1) == OK, "unfinished state saves")
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty() and saved.version == 30, "current save validates backlog and jobs")
	if not saved.is_empty():
		session.pending = saved
		session.apply_to(main)
		check(cpu.work_queue == remaining and clock.backlog_days == 8.0, "load resumes exact work and bounded backlog")
	clock.paused = true
	cpu._process(0.0)
	check(cpu.work_queue == remaining, "pause stops queued work")
	clock.paused = false
	var deadline := Time.get_ticks_msec() + 10000
	while cpu.has_pending_daily_work() and Time.get_ticks_msec() < deadline:
		cpu._process(0.0)
		await process_frame
	check(not cpu.has_pending_daily_work(), "required updates finish")
	check(is_equal_approx(main.house_prestige.value_for(actor), 20.125 + (target - 20.125) * 0.01), "one mandatory day applies exactly one percent prestige drift after save and load")
	check(main.house_prestige.court_ranks[actor] == 2, "court rank survives interrupted daily processing")
	var house: String = cpu.holdings.keys().filter(func(id): return id != session.player_house)[0]
	cpu.queue_job(house, "research", "", 2)
	clock.advance_real_seconds(0.0)
	check(clock.elapsed_days == today + 1, "no fixed rendering wait after required rules")
	check(is_equal_approx(accepted_days, 1.0), "exactly one day's movement precedes next day's rules")
	check(clock.backlog_days == 7.0 and cpu.has_pending_daily_work(), "remaining time waits for next day's required state")
	clock.toggle_paused()
	check(clock.backlog_days == 0.0, "pause drops catch-up time")
	check(session.validate(session.capture(main)), "new boundary saves normally")
	var hud: Node = main.house_status_hud
	hud._refresh()
	hud.icon_hint.touch_mode = true
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	hud.metric_cells.prestige.gui_input.emit(touch)
	check(hud.icon_hint.visible and hud.icon_hint.caption.text == main.house_prestige.description_for(actor), "Android prestige tap shows live baseline and bonuses")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/prestige_baseline_hint.png")
	print("DAY_BARRIER failures=", failures)
	quit(1 if failures else 0)
