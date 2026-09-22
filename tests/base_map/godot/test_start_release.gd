extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	change_scene_to_file("res://scenes/start/start.tscn")
	await process_frame
	await process_frame
	if current_scene.name != "StartScreen" or ResourceLoader.has_cached("res://scenes/main/main.tscn"):
		printerr("Release title isolation failed"); quit(1); return
	var session := root.get_node("GameSession")
	if session.new_game("oda_nobuhide") != OK: quit(1); return
	var deadline := Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.name == "Main" and current_scene.initialized:
			if current_scene.territory_borders.projected.is_empty() or current_scene.game_menu == null: quit(1); return
			if current_scene.get_node_or_null("GovernancePanel") != null: quit(1); return
			print("Packaged title, new game, ownership borders, and menu: PASS")
			quit(0); return
	printerr("Packaged game startup timed out")
	quit(1)
