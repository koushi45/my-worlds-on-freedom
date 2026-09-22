extends SceneTree

func _initialize() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var layer = main.district_layer
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layer.INDEX))
	assert(not layer.review_mode)
	assert(layer.initialized)
	assert(layer.records.size() == index["regions"].size())
	assert(layer.parents.size() == index["parents"].size())
	for key in layer.records:
		assert(layer.records[key]["adoption_status"] in ["accepted_game_estimate", "accepted_unresolved_area"])
	if index["parents"].is_empty():
		assert(layer.loaded.is_empty() and layer.records.is_empty())
	print("DEFAULT ACCEPTED-ONLY DISTRICTS: PASS")
	quit(0)
