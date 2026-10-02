extends SceneTree
## Add close-up detail chunks without rebuilding the established map geometry.
const Chunk = preload("res://scripts/map/map_render_chunk.gd")
const RUNTIME := "res://data/derived/map_runtime/"
const DETAIL := "res://data/derived/detail_map/manifest.json"

func footprint(resource: Resource, path: String) -> Dictionary:
	var result := {}
	var mesh_bytes := 0
	for i in range(resource.mesh.get_surface_count()):
		for array in resource.mesh.surface_get_arrays(i):
			if array != null: mesh_bytes += array.to_byte_array().size()
	result[path + ":mesh"] = mesh_bytes
	var texture: Texture2D = resource.textures[0]
	result[texture.resource_path] = texture.get_image().get_data_size()
	var coast_bytes := 0
	for line in resource.coasts: coast_bytes += line.size() * 8
	if coast_bytes > 0: result[path + ":coasts"] = coast_bytes
	return result

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUNTIME + "manifest.json"))
	var detail: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DETAIL))
	var count := 0
	for tile in detail["tiles"]:
		assert(tile.has("close_density"), "Every detail tile needs a close texture")
		var texture_path: String = "res://" + tile["files"]["relief_close"]
		var close_texture: Texture2D = load(texture_path)
		assert(close_texture != null and close_texture.get_size() == Vector2(1548, 1548), texture_path)
		for tilt in [false, true]:
			var key: String = tile["tile_id"] + ("_tilt" if tilt else "_flat")
			var base_path: String = manifest["tiles"][key]
			var base: Resource = load(base_path)
			assert(base != null and base.mesh != null, base_path)
			var close = Chunk.new()
			close.mesh = base.mesh
			close.coasts = base.coasts
			close.textures.append(close_texture)
			close.resident_bytes = base.resident_bytes - 1032 * 1032 * 4 + 1548 * 1548 * 4
			var path: String = RUNTIME + "tiles/" + key + "_close.res"
			assert(ResourceSaver.save(close, path, ResourceSaver.FLAG_COMPRESS) == OK, path)
			manifest["tiles"][key + "_close"] = path
			manifest["footprints"][path] = footprint(close, path)
			manifest["file_bytes"][path] = FileAccess.get_file_as_bytes(path).size()
		count += 1
		if count % 25 == 0: print("Close terrain chunks: ", count, "/", detail["tiles"].size())
	FileAccess.open(RUNTIME + "manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest))
	print("Close terrain chunks ready: ", count)
	quit()
