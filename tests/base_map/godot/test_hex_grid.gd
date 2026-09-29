extends SceneTree
const Grid = preload("res://scripts/map/hex_grid.gd")

func _initialize() -> void:
	for cell in [Vector2i(0,0), Vector2i(-40,100), Vector2i(80,25), Vector2i(10,200)]:
		if not check(Grid.cell_at(Grid.center(cell)) == cell, "center picking"): return
		var polygon := Grid.polygon(cell)
		for i in 6:
			if not check(is_equal_approx(polygon[i].distance_to(polygon[(i+1)%6]), Grid.RADIUS), "regular hexagon edges"): return
		for target in [Vector2i(30,60), Vector2i(-20,130), cell]:
			var path := Grid.path(cell, target)
			if not check(path.size() == Grid.distance(cell,target), "shortest tile route"): return
			var previous: Vector2i = cell
			for step in path:
				var next: Vector2i = Grid.parse(step)
				if not check(Grid.distance(previous,next) == 1, "adjacent steps only"): return
				previous = next
			if not check(previous == target, "route destination"): return
	for bad in ["hex:", "hex:cat:1", "hex:1:2:3", "hex:99999:1"]:
		if not check(not Grid.valid(bad), "reject invalid saved cell"): return
	print("Hex geometry, picking, adjacency and route tests passed")
	quit(0)

func check(value: bool, message: String) -> bool:
	if not value: printerr("FAIL: " + message); quit(1)
	return value
