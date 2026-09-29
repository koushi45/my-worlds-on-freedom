extends SceneTree
## Regenerate native-resolution HUD icon sets from the original art.

const ICONS := ["koban", "governance", "military", "diplomacy", "security", "people", "spears", "rice", "castle", "fan", "frame"]
const SIZES := [256, 192, 128, 96, 64]
const DIRECTORY := "res://assets/ui/hud/"

func _initialize() -> void:
	var failures := 0
	for name in ICONS:
		var texture := ResourceLoader.load(DIRECTORY + name + ".png", "Texture2D") as Texture2D
		if texture == null:
			printerr("Could not load HUD icon: ", name)
			failures += 1
			continue
		var source := texture.get_image()
		for side in SIZES:
			var output := source.duplicate() as Image
			output.resize(side, side, Image.INTERPOLATE_LANCZOS)
			var result := output.save_png(DIRECTORY + name + "_%d.png" % side)
			if result != OK:
				printerr("Could not save HUD icon: ", name, "_", side)
				failures += 1
	print("HUD icon variants: %d generated, %d failures" % [ICONS.size() * SIZES.size() - failures, failures])
	quit(1 if failures else 0)
