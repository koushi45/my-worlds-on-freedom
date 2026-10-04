extends SceneTree

var failures := 0
var accepted_days := 0.0
var started_days := 0

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func run() -> void:
	var session: Node = root.get_node("GameSession")
	session.save_directory = "user://qa_day_barrier_%d" % OS.get_process_id()
	session.new_game("uesugi_yamanouchi")
	while current_scene == null or not current_scene.initialized: await process_frame
	var main: Node = current_scene
	var clock: Node = main.game_clock
	var cpu: Node = main.cpu_controller
	clock.set_process(false)
	# Initialization may already have started day one; finish it before measuring.
	var initial_day: int = clock.elapsed_days
	while clock.elapsed_days == initial_day:
		clock.advance_real_seconds(1.0)
		await process_frame
	cpu.set_process(false)
	clock.simulation_advanced.connect(func(days: float): accepted_days += days)
	clock.day_started.connect(func(_y, _m, _d): started_days += 1)
	clock.set_speed(8)
	var today: int = clock.elapsed_days
	clock.advance_real_seconds(100.0)
	check(clock.elapsed_days == today and cpu.has_pending_work(), "today stays visible while daily work is pending")
	check(is_equal_approx(accepted_days, 1.0), "long stall moves armies by at most today's remaining time")
	for index in range(4):
		clock.advance_real_seconds(100.0)
		await process_frame
	check(clock.elapsed_days == today and started_days == 1, "CPU delay neither skips dates nor repeats monthly work")
	# Actual controls continue accepting input while CPU work remains queued.
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	root.push_input(key)
	check(clock.speed == 2 and cpu.has_pending_work(), "player can operate speed controls while CPU is pending")
	# Save halfway through work, then resume the exact remaining queue.
	cpu._process(0.0)
	var remaining: Array = cpu.work_queue.duplicate(true)
	check(not remaining.is_empty(), "simulation work is spread across frames")
	check(session.save_game(main, 1) == OK, "save accepts an unfinished current day")
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty() and saved.version == 19, "current save validates queued daily jobs")
	if not saved.is_empty():
		session.pending = saved
		session.apply_to(main)
		check(cpu.work_queue == remaining and clock.elapsed_days == today, "load preserves work and current date")
	clock.paused = true
	cpu._process(0.0)
	check(cpu.work_queue == remaining, "pause suspends queued simulation work")
	clock.paused = false
	cpu.set_process(true)
	var deadline := Time.get_ticks_msec() + 10000
	while cpu.has_pending_work() and Time.get_ticks_msec() < deadline:
		clock.advance_real_seconds(100.0)
		check(clock.elapsed_days == today, "date barrier remains closed while CPU jobs run")
		await process_frame
	check(not cpu.has_pending_work(), "all daily jobs finish")
	clock.advance_real_seconds(100.0)
	check(clock.elapsed_days == today, "completion waits for a display frame")
	for index in range(4):
		await process_frame
		clock.advance_real_seconds(0.001)
		if clock.elapsed_days != today: break
	check(clock.elapsed_days == today + 1 and started_days == 1, "all work and rendering finish before exactly one next day")
	check(is_equal_approx(accepted_days, 1.0), "waiting CPU and drawing time adds no movement or combat")
	check(is_zero_approx(clock._day_fraction), "no accumulated future time survives completion")
	check(session.validate(session.capture(main)), "completed day saves normally")
	print("DAY_BARRIER failures=", failures, " maximum_cpu_frame_ms=", cpu.maximum_frame_usec / 1000.0)
	quit(1 if failures else 0)
