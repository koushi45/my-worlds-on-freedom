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
	var blocked := {Vector2i(11, 10): true}
	var detour: Array = Grid.path_avoiding(Vector2i(10, 10), Vector2i(12, 10), blocked, {})
	if not check(detour.size() == 3 and Grid.parse(detour.back()) == Vector2i(12, 10), "route around an impassable hex"): return
	var previous := Vector2i(10, 10)
	for step in detour:
		var next: Vector2i = Grid.parse(step)
		if not check(Grid.distance(previous, next) == 1 and not blocked.has(next), "detour keeps adjacent passable steps"): return
		previous = next
	var surrounded := {}
	for delta in Grid.NEIGHBORS: surrounded[Vector2i(12, 10) + delta] = true
	if not check(Grid.path_avoiding(Vector2i(10, 10), Vector2i(12, 10), surrounded, {}).is_empty(), "inaccessible hex has no route"): return
	var allowed := {Vector2i(10, 10): true, Vector2i(12, 10): true}
	if not check(Grid.path_avoiding(Vector2i(10, 10), Vector2i(12, 10), {}, allowed).is_empty(), "route cannot cross cells outside land coverage"): return
	print("Hex geometry, picking, adjacency and route tests passed")
	quit(0)

func check(value: bool, message: String) -> bool:
	if not value: printerr("FAIL: " + message); quit(1)
	return value
