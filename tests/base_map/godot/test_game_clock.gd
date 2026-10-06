extends SceneTree

const Clock = preload("res://scripts/game/game_clock.gd")
var failures := 0
var daily_events := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _initialize() -> void:
	for speed in Clock.SPEEDS:
		var clock = Clock.new()
		clock.set_speed(speed)
		clock.advance_real_seconds(1.0)
		check(clock.elapsed_days == mini(speed, 4), "catch-up is bounded to four completed days per call at speed %d" % speed)
		clock.free()
	var calendar = Clock.new()
	check(calendar.date_text() == "1546年 1月 1日", "initial date")
	calendar.day_advanced.connect(func(_y, _m, _d): daily_events += 1)
	for index in range(30): calendar.advance_real_seconds(1)
	check(calendar.month == 1 and calendar.day == 31, "January end")
	calendar.advance_real_seconds(1)
	check(calendar.month == 2 and calendar.day == 1, "February start")
	for index in range(28): calendar.advance_real_seconds(1)
	check(calendar.month == 3 and calendar.day == 1, "non-leap February")
	for index in range(306): calendar.advance_real_seconds(1)
	check(calendar.date_text() == "1547年 1月 1日", "year rollover")
	for index in range(365 + 59): calendar.advance_real_seconds(1)
	check(calendar.date_text() == "1548年 2月 29日", "leap day")
	calendar.advance_real_seconds(1)
	check(calendar.date_text() == "1548年 3月 1日", "leap day rollover")
	check(daily_events == calendar.elapsed_days, "every day emits exactly one event")
	check(Clock.days_in_month(1600, 2) == 29 and Clock.days_in_month(1700, 2) == 28, "century rules")
	calendar.free()
	var fractional = Clock.new()
	fractional.advance_real_seconds(0.5)
	fractional.set_speed(4)
	fractional.advance_real_seconds(0.125)
	check(fractional.elapsed_days == 1, "partial day survives speed switch")
	var stalled = Clock.new()
	stalled.speed = 4
	stalled.advance_real_seconds(2.5)
	check(stalled.elapsed_days == 4 and stalled.backlog_days == 4.0, "long frame retains a bounded backlog and limits work per call")
	stalled.advance_real_seconds(0.0)
	check(stalled.elapsed_days == 8 and is_zero_approx(stalled.backlog_days), "retained time drains without losing calendar days")
	stalled.free()
	var measured = Clock.new()
	measured.profile_enabled = true
	measured.speed = 8
	measured.advance_real_seconds(2.0)
	var measured_report: Dictionary = measured.profile_report()
	check(is_equal_approx(measured_report.discarded_backlog_days, 8.0), "profile distinguishes backlog time discarded by the cap")
	check(measured_report.day_events == 4, "profile counts each completed day")
	measured.reset_profile()
	check(measured.profile_report().day_events == 0 and measured.profile_report().discarded_backlog_days == 0.0, "profile reset clears all counters")
	measured.free()
	var sliced = Clock.new()
	sliced.speed = 8
	check(is_equal_approx(sliced.simulation_budget_for_elapsed(1.0 / 60.0), 0.5) and is_equal_approx(sliced.simulation_budget_for_elapsed(1.0 / 30.0), 1.0), "30 FPS catch-up can finish one date without an extra movement frame")
	sliced.advance_real_seconds(0.125, Clock.MAX_LIVE_SIMULATION_DAYS)
	check(is_equal_approx(sliced._day_fraction, 0.4) and sliced.elapsed_days == 0, "live catch-up limits movement per frame without advancing the date early")
	sliced.advance_real_seconds(0.0, Clock.MAX_LIVE_SIMULATION_DAYS)
	sliced.advance_real_seconds(0.0, Clock.MAX_LIVE_SIMULATION_DAYS)
	check(sliced.elapsed_days == 1 and is_zero_approx(sliced.backlog_days), "sliced catch-up consumes the full day without dropping simulation time")
	sliced.free()
	var accelerated = Clock.new()
	var accelerated_dates: Array = []
	accelerated.day_advanced.connect(func(y: int, m: int, d: int): accelerated_dates.append([y, m, d]))
	accelerated.set_speed(16)
	check(is_equal_approx(accelerated.simulation_budget_for_elapsed(1.0 / 60.0), 1.0), "16x allows a full-date live slice at 60 FPS")
	for index in range(4): accelerated.advance_real_seconds(0.25)
	check(accelerated.elapsed_days == 16 and is_zero_approx(accelerated.backlog_days), "16x processes every date in one second without dropping time")
	check(accelerated_dates.size() == 16 and accelerated_dates[0] == [1546, 1, 2] and accelerated_dates.back() == [1546, 1, 17], "16x emits all sixteen daily events in order")
	accelerated.free()
	fractional.set_speed(3)
	fractional.advance_real_seconds(-1)
	check(fractional.speed == 4 and fractional.elapsed_days == 1, "invalid input ignored")
	fractional.advance_real_seconds(0.125)
	fractional.toggle_paused()
	fractional.set_speed(8)
	fractional.advance_real_seconds(100)
	check(fractional.elapsed_days == 1 and fractional.paused, "speed changes preserve pause")
	fractional.toggle_paused()
	fractional.advance_real_seconds(0.0625)
	check(fractional.elapsed_days == 2, "resume retains partial day without paused time")
	fractional.change_speed(1)
	check(fractional.speed == 16, "acceleration reaches 16x")
	fractional.change_speed(1)
	check(fractional.speed == 16, "upper speed limit")
	fractional.set_speed(1)
	fractional.change_speed(-1)
	check(fractional.speed == 1, "lower speed limit")
	fractional.free()
	call_deferred("integration")


func integration() -> void:
	root.get_node("GameSession").player_house = "uesugi_yamanouchi"
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	while not main.initialized:
		await process_frame
	check(main.time_hud.visible and main.time_hud.date_label.text.begins_with("1546."), "normal game date visible")
	var before: int = main.game_clock.elapsed_days
	var deadline := Time.get_ticks_msec() + 3000
	while main.game_clock.elapsed_days == before and Time.get_ticks_msec() < deadline: await process_frame
	check(main.game_clock.elapsed_days == before + 1, "clock runs automatically without skipping dates")
	for index in range(Clock.SPEEDS.size()):
		press_key(KEY_1 + index)
		check(main.game_clock.speed == Clock.SPEEDS[index], "number key selects speed")
		check(main.time_hud.rate_label.text == "%d×" % Clock.SPEEDS[index], "HUD displays speed")
	check(main.time_hud.speed_buttons[4].button_pressed, "16x lights the highest speed indicator")
	main.time_hud.speed_buttons[4].pressed.emit()
	check(main.game_clock.speed == 16, "16x button")
	var session: Node = root.get_node("GameSession")
	var saved: Dictionary = session.capture(main)
	check(session.validate(saved), "16x save is valid")
	session.pending = JSON.parse_string(JSON.stringify(saved))
	session.apply_to(main)
	check(main.game_clock.speed == 16 and main.time_hud.rate_label.text == "16×", "16x save restores clock and HUD")
	main.time_hud.speed_buttons[2].pressed.emit()
	check(main.game_clock.speed == 4, "deceleration button")
	main.time_hud.speed_buttons[3].pressed.emit()
	check(main.game_clock.speed == 8, "acceleration button")
	press_key(KEY_SPACE)
	check(main.game_clock.paused and main.time_hud.playback_icon.texture.resource_path.contains("play_"), "space pauses and shows play icon")
	before = main.game_clock.elapsed_days
	await create_timer(1.1).timeout
	check(main.game_clock.elapsed_days == before, "paused real time does not advance date")
	press_key(KEY_2)
	check(main.game_clock.paused and main.game_clock.speed == 2, "shortcut changes speed while paused")
	press_key(KEY_SPACE, true)
	check(main.game_clock.paused, "held space ignored")
	main.time_hud.playback_button.pressed.emit()
	check(not main.game_clock.paused and main.time_hud.playback_icon.texture.resource_path.contains("pause_"), "button resumes and shows pause icon")
	press_key(KEY_SPACE)
	press_key(KEY_SPACE)
	check(not main.game_clock.paused, "space resumes")
	press_key(KEY_4)
	main.game_clock.set_process(false)
	before = main.game_clock.elapsed_days
	await advance_days(main.game_clock, 1)
	check(main.game_clock.elapsed_days == before + 1, "HUD 8x still waits for one day at a time")
	check(main.time_hud.date_label.tooltip_text == main.game_clock.date_text(), "HUD date updates")
	await process_frame
	var panel_rect: Rect2 = main.time_hud.panel.get_global_rect()
	check(absf(panel_rect.end.x - (root.get_visible_rect().size.x - 12)) < 2, "HUD anchored at right edge")
	check(panel_rect.position.y == 12, "HUD anchored at top")
	check(main.time_hud.date_label.get_global_rect().end.x <= panel_rect.end.x - 12, "date stays inside time panel")
	check(main.time_hud.speed_buttons.back().get_global_rect().end.x <= panel_rect.end.x - 12, "speed controls stay inside time panel")
	if "--capture" in OS.get_cmdline_user_args():
		press_key(KEY_5)
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://builds/qa")
		root.get_texture().get_image().save_png("res://builds/qa/game_time.png")
	main.queue_free()
	await process_frame
	print("Game clock tests: %d failures" % failures)
	quit(1 if failures else 0)


func press_key(code: int, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event)

func advance_days(clock: Node, count: int) -> void:
	for index in range(count):
		var previous: int = clock.elapsed_days
		while clock.elapsed_days == previous:
			clock.advance_real_seconds(1.0 / clock.speed)
			await process_frame
