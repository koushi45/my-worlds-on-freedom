extends Node
## Opt-in packaged-game smoke check; never runs during ordinary play.
var main: Node2D

func _ready() -> void: call_deferred("run")

func run() -> void:
	main.game_clock.set_process(false)
	main.army_campaign.set_process(false)
	var failures: Array = []
	var started := Time.get_ticks_usec()
	for index in range(35):
		var previous_day: int = main.game_clock.elapsed_days
		# Repeated long elapsed-time reports must not bypass queued work or drawing.
		main.game_clock.advance_real_seconds(100.0)
		main.game_clock.advance_real_seconds(100.0)
		if main.game_clock.elapsed_days != previous_day: failures.append("day barrier")
		if index == 0:
			var partial: Dictionary = GameSession.capture(main)
			if not GameSession.validate(partial): failures.append("unfinished-day save")
			else:
				GameSession.pending = JSON.parse_string(JSON.stringify(partial))
				GameSession.apply_to(main)
		while main.game_clock.elapsed_days == previous_day:
			main.game_clock.advance_real_seconds(1.0)
			await get_tree().process_frame
		if index % 7 == 6 and not GameSession.validate(GameSession.capture(main)):
			failures.append("day %d save validation" % (index + 1))
		await get_tree().process_frame
	var directory := "user://qa_cpu_release"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var previous_directory: String = GameSession.save_directory
	GameSession.save_directory = directory
	if GameSession.save_game(main, 1) != OK: failures.append("save")
	var saved: Dictionary = GameSession.read_save(1)
	if saved.is_empty():
		failures.append("read")
	else:
		GameSession.pending = saved
		GameSession.apply_to(main)
		if JSON.parse_string(JSON.stringify(main.cpu_controller.save_state())) != saved.cpu: failures.append("CPU restore")
		if JSON.parse_string(JSON.stringify(main.diplomacy.save_state())) != saved.diplomacy: failures.append("war restore")
	GameSession.save_directory = previous_directory
	if main.cpu_controller.plans.is_empty(): failures.append("no CPU plans")
	if main.army_campaign.units.is_empty(): failures.append("no CPU armies")
	var report := {"ok":failures.is_empty(), "failures":failures, "save_version":19, "game_days":main.game_clock.elapsed_days,
		"cpu_houses":main.cpu_controller.plans.size(), "armies":main.army_campaign.units.size(), "wars":main.diplomacy.wars.size(),
		"maximum_cpu_frame_ms":main.cpu_controller.maximum_frame_usec / 1000.0, "elapsed_ms":(Time.get_ticks_usec() - started) / 1000.0, "executable":OS.get_executable_path()}
	var output := FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	else: failures.append("result file")
	print("CPU_RELEASE_CHECK ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
