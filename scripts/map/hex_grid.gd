extends RefCounted
## Pointy-top axial coordinates, independent of political and district geometry.
const RADIUS := 6.0
const MIN_DRAW_ZOOM := 2.0
const ROOT_3 := 1.7320508075688772
const WORLD := Rect2(0, 0, 8192, 8192)
const NEIGHBORS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]

static func center(cell: Vector2i) -> Vector2:
	return Vector2(ROOT_3 * RADIUS * (cell.x + cell.y * 0.5), RADIUS * 1.5 * cell.y)

static func cell_at(point: Vector2) -> Vector2i:
	var q := (ROOT_3 / 3.0 * point.x - point.y / 3.0) / RADIUS
	var r := point.y * 2.0 / 3.0 / RADIUS
	var s := -q-r
	var x := roundi(q)
	var y := roundi(r)
	var z := roundi(s)
	if absf(x-q) > absf(y-r) and absf(x-q) > absf(z-s): x = -y-z
	elif absf(y-r) > absf(z-s): y = -x-z
	return Vector2i(x,y)

static func key(cell: Vector2i) -> String:
	return "hex:%d:%d" % [cell.x, cell.y]

static func parse(id: String) -> Vector2i:
	return Vector2i(int(id.get_slice(":",1)), int(id.get_slice(":",2)))

static func valid(id: String) -> bool:
	var parts := id.split(":")
	return parts.size() == 3 and parts[0] == "hex" and parts[1].is_valid_int() and parts[2].is_valid_int() and WORLD.has_point(center(parse(id)))

static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a-b
	return maxi(absi(d.x), maxi(absi(d.y), absi(d.x+d.y)))

static func path(a: Vector2i, b: Vector2i) -> Array:
	var result := []
	var count := distance(a,b)
	for i in range(1, count+1):
		result.append(key(cell_at(center(a).lerp(center(b), float(i)/count))))
	return result

static func path_avoiding(a: Vector2i, b: Vector2i, blocked: Dictionary, allowed: Dictionary) -> Array:
	if a == b or blocked.has(b) or (not allowed.is_empty() and (not allowed.has(a) or not allowed.has(b))): return []
	var has_approach := false
	for delta in NEIGHBORS:
		if not blocked.has(b + delta) and WORLD.has_point(center(b + delta)) and (allowed.is_empty() or allowed.has(b + delta)):
			has_approach = true
			break
	if not has_approach: return []
	var frontier: Array = []
	_heap_push(frontier, [distance(a, b), distance(a, b), 0, a])
	var sequence := 1
	var cost: Dictionary = {a: 0}
	var previous: Dictionary = {}
	var closed: Dictionary = {}
	while not frontier.is_empty():
		if closed.size() > maxi(4000, distance(a, b) * 40): return []
		var current: Vector2i = _heap_pop(frontier)[3]
		if closed.has(current): continue
		if current == b:
			var result := []
			while current != a:
				result.push_front(key(current))
				current = previous[current]
			return result
		closed[current] = true
		for delta in NEIGHBORS:
			var neighbor: Vector2i = current + delta
			if closed.has(neighbor) or blocked.has(neighbor) or not WORLD.has_point(center(neighbor)) or (not allowed.is_empty() and not allowed.has(neighbor)): continue
			var next_cost := int(cost[current]) + 1
			if not cost.has(neighbor) or next_cost < int(cost[neighbor]):
				cost[neighbor] = next_cost
				previous[neighbor] = current
				var remaining := distance(neighbor, b)
				_heap_push(frontier, [next_cost + remaining, remaining, sequence, neighbor])
				sequence += 1
	return []

static func _heap_less(a: Array, b: Array) -> bool:
	if a[0] != b[0]: return a[0] < b[0]
	if a[1] != b[1]: return a[1] < b[1]
	return a[2] < b[2]

static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var index := heap.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if not _heap_less(heap[index], heap[parent]): break
		var swap: Array = heap[parent]
		heap[parent] = heap[index]
		heap[index] = swap
		index = parent

static func _heap_pop(heap: Array) -> Array:
	var result: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty(): return result
	heap[0] = last
	var index := 0
	while index * 2 + 1 < heap.size():
		var child := index * 2 + 1
		if child + 1 < heap.size() and _heap_less(heap[child + 1], heap[child]): child += 1
		if not _heap_less(heap[child], heap[index]): break
		var swap: Array = heap[index]
		heap[index] = heap[child]
		heap[child] = swap
		index = child
	return result

static func polygon(cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		points.append(center(cell) + Vector2.from_angle(PI/6.0+i*PI/3.0)*RADIUS)
	return points

static func snap_polyline(raw: Array) -> Array:
	var result := []
	var previous := Vector2i.ZERO
	for point in raw:
		var cell := cell_at(Vector2(float(point[0]), float(point[1])))
		if result.is_empty():
			var p := center(cell)
			result.append([p.x, p.y])
		else:
			for id in path(previous, cell):
				var p := center(parse(id))
				result.append([p.x, p.y])
		previous = cell
	return result
