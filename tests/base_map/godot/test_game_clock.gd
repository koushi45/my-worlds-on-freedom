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
		check(clock.elapsed_days == speed, "one second at speed %d" % speed)
		clock.free()
	var calendar = Clock.new()
	check(calendar.date_text() == "1546年 1月 1日", "initial date")
	calendar.day_advanced.connect(func(_y, _m, _d): daily_events += 1)
	calendar.advance_real_seconds(30)
	check(calendar.month == 1 and calendar.day == 31, "January end")
	calendar.advance_real_seconds(1)
	check(calendar.month == 2 and calendar.day == 1, "February start")
	calendar.advance_real_seconds(28)
	check(calendar.month == 3 and calendar.day == 1, "non-leap February")
	calendar.advance_real_seconds(306)
	check(calendar.date_text() == "1547年 1月 1日", "year rollover")
	calendar.advance_real_seconds(365 + 59)
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
	fractional.advance_real_seconds(2.5)
	check(fractional.elapsed_days == 11, "long frame catches up every day")
	fractional.set_speed(3)
	fractional.advance_real_seconds(-1)
	check(fractional.speed == 4 and fractional.elapsed_days == 11, "invalid input ignored")
	fractional.advance_real_seconds(0.125)
	fractional.toggle_paused()
	fractional.set_speed(8)
	fractional.advance_real_seconds(100)
	check(fractional.elapsed_days == 11 and fractional.paused, "speed changes preserve pause")
	fractional.toggle_paused()
	fractional.advance_real_seconds(0.0625)
	check(fractional.elapsed_days == 12, "resume retains partial day without paused time")
	fractional.change_speed(1)
	check(fractional.speed == 8, "upper speed limit")
	fractional.set_speed(1)
	fractional.change_speed(-1)
	check(fractional.speed == 1, "lower speed limit")
	fractional.free()
	call_deferred("integration")


func integration() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	while not main.initialized:
		await process_frame
	check(main.time_hud.visible and main.time_hud.date_label.text.begins_with("1546年"), "normal game date visible")
	var before: int = main.game_clock.elapsed_days
	await create_timer(1.1).timeout
	check(main.game_clock.elapsed_days - before in [1, 2], "clock runs automatically")
	for index in range(4):
		press_key(KEY_1 + index)
		check(main.game_clock.speed == Clock.SPEEDS[index], "number key selects speed")
		check(main.time_hud.rate_label.text.begins_with("%d倍速" % Clock.SPEEDS[index]), "HUD displays speed")
	check(main.time_hud.faster_button.disabled, "8x disables acceleration")
	main.time_hud.slower_button.pressed.emit()
	check(main.game_clock.speed == 4, "deceleration button")
	main.time_hud.faster_button.pressed.emit()
	check(main.game_clock.speed == 8, "acceleration button")
	press_key(KEY_SPACE)
	check(main.game_clock.paused and main.time_hud.playback_button.text == "再生", "space pauses and shows play")
	before = main.game_clock.elapsed_days
	await create_timer(1.1).timeout
	check(main.game_clock.elapsed_days == before, "paused real time does not advance date")
	press_key(KEY_2)
	check(main.game_clock.paused and main.game_clock.speed == 2, "shortcut changes speed while paused")
	press_key(KEY_SPACE, true)
	check(main.game_clock.paused, "held space ignored")
	main.time_hud.playback_button.pressed.emit()
	check(not main.game_clock.paused and main.time_hud.playback_button.text == "停止", "button resumes and shows stop")
	press_key(KEY_SPACE)
	press_key(KEY_SPACE)
	check(not main.game_clock.paused, "space resumes")
	press_key(KEY_4)
	main.game_clock.set_process(false)
	before = main.game_clock.elapsed_days
	main.game_clock.advance_real_seconds(1)
	check(main.game_clock.elapsed_days == before + 8, "HUD 8x advances eight days")
	check(main.time_hud.date_label.text == main.game_clock.date_text(), "HUD date updates")
	await process_frame
	var panel_rect: Rect2 = main.time_hud.panel.get_global_rect()
	check(absf(panel_rect.end.x - (root.get_visible_rect().size.x - 16)) < 2, "HUD anchored at right edge")
	check(panel_rect.position.y == 16, "HUD anchored at top")
	if "--capture" in OS.get_cmdline_user_args():
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
