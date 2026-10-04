extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var layer = load("res://scripts/map/district_layer.gd").new()
	layer.elevation = load("res://scripts/map/elevation_surface.gd").new()
	layer.elevation.enabled = false
	layer.view_zoom = 4.0
	# The eastern label is closer, but this click is inside the western district.
	layer.records = {
		"west": {"parent": "fixture", "label": [5,50]},
		"east": {"parent": "fixture", "label": [110,50]},
	}
	for id in layer.records:
		layer.records[id].rect = Rect2(0 if id == "west" else 100,0,100,100)
		for cell in layer.cells(layer.records[id].rect):
			if not layer.grid.has(cell): layer.grid[cell] = []
			layer.grid[cell].append(id)
	layer.loaded.fixture = {"polygons": {
		"west": [[[ [0,0],[100,0],[100,100],[0,100],[0,0] ]]],
		"east": [[[ [100,0],[200,0],[200,100],[100,100],[100,0] ]]],
	}, "lines": [], "line_grid": {}}
	var failures := 0
	for sample in [[Vector2(99,50), "west"], [Vector2(101,50), "east"], [Vector2(201,50), "east"]]:
		var result: Array = layer.pick(sample[0])
		if result != [sample[1]]:
			failures += 1
			printerr("FAIL: click %s selected %s, expected %s" % [sample[0], result, sample[1]])
	# Clear selection remains supported.
	layer.select_key("")
	if layer.selected_key != "": failures += 1
	layer.free()
	print("District interior picking: %d failures" % failures)
	quit(1 if failures else 0)
