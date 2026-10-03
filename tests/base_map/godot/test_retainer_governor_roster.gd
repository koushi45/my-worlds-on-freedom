extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := root.get_node("GameSession")
	session.save_directory = "user://qa_governor_roster_%d" % OS.get_process_id()
	check(session.new_game("oda_nobuhide") == OK, "Oda game starts")
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.name == "Main" and current_scene.initialized: break
	if not is_instance_valid(current_scene) or current_scene.name != "Main" or not current_scene.initialized:
		check(false, "map initializes")
		quit(1)
		return
	var main := current_scene
	main.game_menu.show_retainers()
	await process_frame
	var panel: Control = main.game_menu.retainer_panel
	for officer_id in ["officer_q171411", "officer_q707587"]:
		check(panel.officer_buttons.has(officer_id), "governor has selectable retainer row: " + officer_id)
		if panel.officer_buttons.has(officer_id):
			panel.officer_buttons[officer_id].pressed.emit()
			check(panel.selected_officer_id == officer_id and not panel.wage_button.disabled, "governor row supports selection")
	check(session.save_game(main, 1) == OK, "current game saves")
	var saved: Dictionary = session.read_save(1)
	check(not saved.is_empty(), "current save loads and validates")
	if not saved.is_empty():
		session.pending = saved
		session.apply_to(main)
		panel.refresh()
		for officer_id in ["officer_q171411", "officer_q707587"]:
			check(panel.officer_buttons.has(officer_id), "loaded roster retains governor row: " + officer_id)
	DirAccess.remove_absolute(session.path_for(1))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session.save_directory))
	print("Governor retainer roster failures: ", failures)
	quit(0 if failures == 0 else 1)
