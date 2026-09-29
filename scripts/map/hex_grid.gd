extends RefCounted
## Pointy-top axial coordinates, independent of political and district geometry.
const RADIUS := 6.0
const MIN_DRAW_ZOOM := 2.0
const ROOT_3 := 1.7320508075688772
const WORLD := Rect2(0, 0, 8192, 8192)

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
