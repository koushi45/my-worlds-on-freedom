extends SceneTree
const Search = preload("res://scripts/game/army_route_search.gd")
const Grid = preload("res://scripts/map/hex_grid.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func cost(_a: Vector2i, b: Vector2i) -> float:
	return 5.0 if b in [Vector2i(1, 0), Vector2i(2, 0)] else 1.0

func _initialize() -> void:
	var land := {}
	for x in range(4):
		for y in range(2): land[Vector2i(x, y)] = true
	var search := Search.new()
	search.setup(Vector2i.ZERO, Vector2i(3, 0), {}, land, cost)
	check(search.advance(1) == "deferred", "one expansion yields and resumes")
	while search.status == "deferred": search.advance(1)
	check(search.status == "found" and search.days == 4.0, "road detour beats fewer slow terrain tiles")
	check(search.result.size() == 4, "weighted route contains adjacent steps")
	var previous := Vector2i.ZERO
	for node in search.result:
		check(Grid.distance(previous, Grid.parse(node)) == 1, "each step is adjacent")
		previous = Grid.parse(node)
	var limited := Search.new()
	limited.setup(Vector2i.ZERO, Vector2i(3, 0), {}, land, cost, 1)
	limited.advance(20)
	check(limited.status == "search_limit" and limited.report().deferred, "limit is distinct from unreachable")
	var island := Search.new()
	island.setup(Vector2i.ZERO, Vector2i(3, 0), {}, {Vector2i.ZERO:true, Vector2i(3, 0):true}, cost)
	island.advance(20)
	check(island.status == "unreachable", "exhausted frontier proves unreachable")
	var terrain := {Vector2i.ZERO:0, Vector2i(1, 0):2, Vector2i(2, 0):0}
	var roads := terrain.duplicate()
	var fast := Search.new()
	fast.setup(Vector2i.ZERO, Vector2i(2, 0), {}, terrain, Callable())
	fast.terrain_costs = true
	fast.road_cells = roads
	fast.advance(20)
	check(fast.status == "found" and fast.days == 2.5, "snapshot costs include river road travel")
	var excluded := Search.new()
	excluded.setup(Vector2i.ZERO, Vector2i(2, 0), {}, terrain, Callable())
	excluded.terrain_costs = true
	excluded.road_cells = roads
	excluded.excluded_edges = {Vector4i(0, 0, 1, 0):true}
	excluded.advance(20)
	check(excluded.days == 6.0, "excluded road edge uses actual terrain travel")
	print("ARMY_ROUTE_SEARCH failures=", failures)
	quit(1 if failures else 0)
