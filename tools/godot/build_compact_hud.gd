extends SceneTree
## Bake small artwork and complete ornamental frames; never resize them in game.
const SIZES := [64, 96, 128, 192, 256]
const FRAMES := {"identity": Vector2i(120, 86), "house": Vector2i(590, 40), "technology": Vector2i(240, 40), "time": Vector2i(246, 48), "council": Vector2i(320, 310)}
const DIRECTORY := "res://assets/ui/hud/compact/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for name in ["koban", "rice", "people", "spears", "fan", "security", "castle", "governance", "diplomacy", "military"]:
		_bake_icon(name, "res://assets/ui/hud/" + name + ".png")
	for name in ["play", "pause", "slower", "faster"]:
		_bake_icon(name, "res://assets/ui/time/" + name + "_256.png")
	var frame := Image.load_from_file("res://assets/ui/hud/frame_256.png")
	for pixels in SIZES:
		var factor := float(pixels) / 64.0
		for name in FRAMES:
			var dimensions: Vector2i = Vector2i(Vector2(FRAMES[name]) * factor)
			var output := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
			var edge := roundi(10 * factor)
			# The original frame is baked as nine regions at the required output size.
			var source_edges := [0, 52, 204, 256]
			var xs := [0, edge, dimensions.x - edge, dimensions.x]
			var ys := [0, edge, dimensions.y - edge, dimensions.y]
			for y in range(3):
				for x in range(3):
					var piece := frame.get_region(Rect2i(source_edges[x], source_edges[y], source_edges[x+1]-source_edges[x], source_edges[y+1]-source_edges[y]))
					piece.resize(xs[x+1]-xs[x], ys[y+1]-ys[y], Image.INTERPOLATE_LANCZOS)
					output.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(xs[x], ys[y]))
			assert(output.save_png(DIRECTORY + "%s_%d.png" % [name, pixels]) == OK)
	print("Compact HUD: 70 icon PNGs and 25 complete frame PNGs baked")
	quit()

func _bake_icon(name: String, source_path: String) -> void:
	var source := Image.load_from_file(source_path)
	assert(source != null, source_path)
	for pixels in SIZES:
		var art := source.duplicate() as Image
		var art_side := roundi(float(pixels) * 0.375)
		art.resize(art_side, art_side, Image.INTERPOLATE_LANCZOS)
		var output := Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
		output.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i.ONE * ((pixels - art_side) / 2))
		assert(output.save_png(DIRECTORY + "%s_%d.png" % [name, pixels]) == OK)
