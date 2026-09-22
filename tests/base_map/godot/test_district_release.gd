extends SceneTree
class Surface extends RefCounted:
	var enabled := false
	var height_scale := 0.0
	func project(p: Vector2) -> Vector2: return p
	func project_line(p: PackedVector2Array) -> PackedVector2Array: return p

func _initialize() -> void:
	var layer = load("res://scripts/map/district_layer.gd").new()
	layer.elevation = Surface.new()
	root.add_child(layer)
	await process_frame
	assert(not layer.review_mode)
	assert(layer.initialized and layer.records.size()>0)
	for key in layer.records:
		var r: Dictionary = layer.records[key]
		assert(r["adoption_status"] in ["accepted_game_estimate","accepted_unresolved_area"])
		assert(layer.contains_point(key,Vector2(r["label"][0],r["label"][1])))
		layer.select_key(key)
		assert(layer.fill_mesh()!=null)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layer.INDEX))
	manifest["regions"][0]["adoption_status"] = "held"
	assert(not layer.valid_accepted_index(manifest))
	print("ACCEPTED DISTRICT RUNTIME: PASS")
	quit(0)
