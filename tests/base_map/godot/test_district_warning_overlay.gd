extends SceneTree
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var session := root.get_node("GameSession")
	session.player_house = "oda_nobuhide"
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var deadline := Time.get_ticks_msec() + 45000
	while not main.initialized and Time.get_ticks_msec() < deadline: await process_frame
	if not main.initialized: quit(1); return
	check(main.get_node_or_null("DistrictWarningOverlay") == null, "red warning overlay is absent")
	var overlay_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/scenarios/district_warning_overlay_1546.json"))
	check(overlay_data.normal_pairs == 0 and overlay_data.pending_count == 0, "no unresolved overlap remains")
	check(main.governance_registry.districts.size() == session.catalog.district_ids.size(), "governance data remains internal")
	main.queue_free()
	await process_frame
	print("Removed warning overlay tests: %d failures" % failures)
	quit(1 if failures else 0)
