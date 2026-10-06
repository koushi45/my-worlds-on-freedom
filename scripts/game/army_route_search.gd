extends RefCounted
## Deterministic, resumable weighted A*. CPU limits concurrent instances.
const Grid = preload("res://scripts/map/hex_grid.gd")
var start: Vector2i
var goal: Vector2i
var blocked: Dictionary
var allowed: Dictionary
var edge_cost: Callable
var road_cells: Dictionary = {}
var excluded_edges: Dictionary = {}
var terrain_costs := false
const OFF_ROAD = [1.5, 2.5, 5.0, INF, INF]
const ON_ROAD = [1.0, 1.5, 1.5, INF, INF]
var frontier: Array = []
var costs: Dictionary = {}
var previous: Dictionary = {}
var closed: Dictionary = {}
var sequence := 0
var limit := 24000
var status := "deferred"
var result: Array = []
var days := INF
var worker_started_usec := 0
var worker_finished_usec := 0

func advance_worker(node_budget: int) -> void:
	worker_started_usec = Time.get_ticks_usec()
	advance(node_budget)
	worker_finished_usec = Time.get_ticks_usec()

func setup(a: Vector2i, b: Vector2i, obstacles: Dictionary, land: Dictionary, cost: Callable, node_limit := 24000) -> void:
	start = a
	goal = b
	blocked = obstacles
	allowed = land
	edge_cost = cost
	limit = node_limit
	if a == b:
		status = "found"
		days = 0.0
	elif blocked.has(b) or not allowed.has(a) or not allowed.has(b):
		status = "unreachable"
	else:
		costs[a] = 0.0
		Grid._heap_push(frontier, [float(Grid.distance(a, b)), Grid.distance(a, b), sequence, a])

func advance(node_budget := 256) -> String:
	var expanded := 0
	while status == "deferred" and not frontier.is_empty() and expanded < node_budget:
		var cell: Vector2i = Grid._heap_pop(frontier)[3]
		if closed.has(cell): continue
		if cell == goal:
			status = "found"
			days = float(costs[cell])
			while cell != start:
				result.append(Grid.key(cell))
				cell = previous[cell]
			result.reverse()
			break
		if closed.size() >= limit:
			status = "search_limit"
			break
		closed[cell] = true
		expanded += 1
		for offset in Grid.NEIGHBORS:
			var neighbor: Vector2i = cell + offset
			if closed.has(neighbor) or blocked.has(neighbor) or not allowed.has(neighbor): continue
			var step: float
			if terrain_costs:
				var road := road_cells.has(cell) and road_cells.has(neighbor)
				if road and not excluded_edges.is_empty():
					var a := cell
					var b := neighbor
					if a.y > b.y or (a.y == b.y and a.x > b.x): a = neighbor; b = cell
					road = not excluded_edges.has(Vector4i(a.x, a.y, b.x, b.y))
				step = ON_ROAD[int(allowed[neighbor])] if road else OFF_ROAD[int(allowed[neighbor])]
			else:
				step = float(edge_cost.call(cell, neighbor))
			if not is_finite(step): continue
			var next := float(costs[cell]) + step
			if not costs.has(neighbor) or next < float(costs[neighbor]):
				costs[neighbor] = next
				previous[neighbor] = cell
				sequence += 1
				var remaining := Grid.distance(neighbor, goal)
				Grid._heap_push(frontier, [next + remaining, remaining, sequence, neighbor])
	if status == "deferred" and frontier.is_empty(): status = "unreachable"
	return status

func report() -> Dictionary:
	return {"status":status, "reachable":status == "found", "days":days, "path":result.duplicate(), "expanded":closed.size(), "deferred":status in ["deferred", "search_limit"]}
