extends SceneTree

const TileCatalog = preload("res://scripts/map/map_tile_catalog.gd")
const DisplayTransform = preload("res://scripts/map/map_display_transform.gd")


func fail(message: String) -> void:
	printerr("FAIL: " + message)
	quit(1)


func _initialize() -> void:
	var catalog = TileCatalog.new()
	if catalog.load_manifest() != OK:
		fail("map manifest could not be loaded")
		return

	var view := Rect2(100.0, 100.0, 200.0, 200.0)
	var visible := catalog.get_visible_tiles(4, view)
	if visible.size() != 1:
		fail("expected exactly one visible local tile")
		return
	var loaded := catalog.load_visible_composites(4, view)
	if loaded.size() != visible.size() or catalog.last_loaded_tile_ids.size() != visible.size():
		fail("only visible tiles must be loaded")
		return
	for image in loaded.values():
		if image.get_width() != 2048 or image.get_height() != 2048:
			fail("runtime tile dimensions are not portable 2048x2048")
			return

	var outside := catalog.load_visible_composites(4, Rect2(-1000.0, -1000.0, 100.0, 100.0))
	if not outside.is_empty() or not catalog.last_loaded_tile_ids.is_empty():
		fail("offscreen query loaded a tile")
		return

	for point in [Vector2(0, 0), Vector2(4096, 4096), Vector2(8192, 8192), Vector2(1234.5, 6789.25)]:
		var oblique = DisplayTransform.top_down_to_oblique(point)
		var restored = DisplayTransform.oblique_to_top_down(oblique)
		if restored.distance_to(point) > 0.001:
			fail("top-down/oblique inverse transform error")
			return

	print("Godot map runtime tests passed")
	quit(0)
