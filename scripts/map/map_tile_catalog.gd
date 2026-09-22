class_name MapTileCatalog
extends RefCounted

var tiles: Array = []
var last_loaded_tile_ids: Array[String] = []
var detail_tiles: Array = []


func load_manifest(path: String = "res://data/derived/map_images/map_images_manifest.json") -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("tiles"):
		return ERR_PARSE_ERROR
	tiles = parsed["tiles"]
	var detail_path := "res://data/derived/detail_map/manifest.json"
	if FileAccess.file_exists(detail_path):
		var detail: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(detail_path))
		detail_tiles = detail["tiles"]
	return OK

func get_detail_tiles(global_view_rect: Rect2) -> Array:
	var visible: Array = []
	for tile in detail_tiles:
		var b: Array = tile["global_viewport"]
		if Rect2(Vector2(b[0],b[1]),Vector2(b[2]-b[0],b[3]-b[1])).intersects(global_view_rect,true): visible.append(tile)
	return visible


func get_visible_tiles(lod_level: int, global_view_rect: Rect2) -> Array:
	var visible: Array = []
	for tile in tiles:
		if int(tile["lod"]) != lod_level:
			continue
		var bounds: Array = tile["global_viewport"]
		var tile_rect := Rect2(
			Vector2(float(bounds[0]), float(bounds[1])),
			Vector2(float(bounds[2]) - float(bounds[0]), float(bounds[3]) - float(bounds[1]))
		)
		if tile_rect.intersects(global_view_rect, true):
			visible.append(tile)
	return visible


func load_visible_composites(lod_level: int, global_view_rect: Rect2) -> Dictionary:
	var loaded := {}
	last_loaded_tile_ids.clear()
	for tile in get_visible_tiles(lod_level, global_view_rect):
		var image := Image.load_from_file("res://" + str(tile["files"]["composite"]))
		if image.is_empty():
			continue
		var tile_id := str(tile["tile_id"])
		loaded[tile_id] = image
		last_loaded_tile_ids.append(tile_id)
	return loaded
