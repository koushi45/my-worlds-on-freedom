extends SceneTree
## Bake the 400%-800% texture tier using the approved detail meshes.
const Chunk = preload("res://scripts/map/map_render_chunk.gd")
const RUNTIME := "res://data/derived/map_runtime/"

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUNTIME + "manifest.json"))
	var detail: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/detail_map/manifest.json"))
	var count := 0
	for tile in detail["tiles"]:
		assert(tile["high_density"] == 8)
		var texture_path: String = "res://" + tile["files"]["relief_high"]
		var texture: Texture2D = load(texture_path)
		assert(texture != null and texture.get_size() == Vector2(2064, 2064), texture_path)
		for tilt in [false, true]:
			var key: String = tile["tile_id"] + ("_tilt" if tilt else "_flat")
			var base: Resource = load(manifest["tiles"][key])
			assert(base != null and base.mesh != null)
			var chunk = Chunk.new()
			chunk.mesh = base.mesh
			chunk.coasts = base.coasts
			chunk.textures.append(texture)
			chunk.resident_bytes = base.resident_bytes - 1032 * 1032 * 4 + 2064 * 2064 * 4
			var path: String = RUNTIME + "tiles/" + key + "_high.res"
			assert(ResourceSaver.save(chunk, path, ResourceSaver.FLAG_COMPRESS) == OK, path)
			manifest["tiles"][key + "_high"] = path
			var base_footprint: Dictionary = manifest["footprints"][manifest["tiles"][key]]
			var footprint := {}
			for asset in base_footprint:
				if str(asset).ends_with(":mesh"): footprint[path + ":mesh"] = base_footprint[asset]
				elif str(asset).ends_with(":coasts"): footprint[path + ":coasts"] = base_footprint[asset]
			footprint[texture.resource_path] = texture.get_image().get_data_size()
			manifest["footprints"][path] = footprint
			manifest["file_bytes"][path] = FileAccess.get_file_as_bytes(path).size()
		count += 1
		if count % 25 == 0: print("High detail chunks: ", count, "/", detail["tiles"].size())
	FileAccess.open(RUNTIME + "manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest))
	print("High detail chunks ready: ", count)
	quit()
