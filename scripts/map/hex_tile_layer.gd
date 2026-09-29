extends Node2D
## A separate world-space overlay; no border clipping or boundary-derived cells.
const Grid = preload("res://scripts/map/hex_grid.gd")
const Terrain = preload("res://scripts/map/hex_terrain.gd")
const EDGE_NEIGHBORS := [Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0)]
var visible_cells: Dictionary = {}
var main: Node2D
var bounds := Rect2()
var zoom := 1.0

func _ready() -> void:
	z_index = 23
	visible = false
	var coverage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/detail_map/hex_coverage.json"))
	var terrain: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/detail_map/hex_terrain.json"))
	assert(is_equal_approx(float(coverage.radius), Grid.RADIUS), "Rebuild hex coverage after changing the tile radius")
	assert(is_equal_approx(float(terrain.radius), Grid.RADIUS) and int(terrain.tile_count) == int(coverage.visible_cells), "Rebuild hex terrain after changing coverage")
	for row in coverage.rows:
		var codes: String = terrain.rows[row]
		assert(codes.length() == coverage.rows[row].size(), "Hex terrain row does not match coverage")
		for index in coverage.rows[row].size():
			visible_cells[Vector2i(int(coverage.rows[row][index]), int(row))] = codes.unicode_at(index) - 48

func terrain_for(cell: Vector2i) -> int:
	return int(visible_cells.get(cell, Terrain.PLAIN))

func update_view(rect: Rect2, view_zoom: float) -> void:
	bounds = rect.intersection(Grid.WORLD).grow(Grid.RADIUS * 2.0)
	zoom = view_zoom
	visible = zoom >= Grid.MIN_DRAW_ZOOM
	queue_redraw()

func _draw() -> void:
	if main == null or bounds.size == Vector2.ZERO or zoom < Grid.MIN_DRAW_ZOOM: return
	var alpha := lerpf(0.08, 0.38, smoothstep(5.0, 24.0, Grid.RADIUS * zoom))
	var lines := PackedVector2Array()
	for r in range(floori(bounds.position.y / (Grid.RADIUS*1.5)), ceili(bounds.end.y / (Grid.RADIUS*1.5))+1):
		var left := floori(bounds.position.x / (Grid.ROOT_3*Grid.RADIUS)-r*0.5)
		var right := ceili(bounds.end.x / (Grid.ROOT_3*Grid.RADIUS)-r*0.5)
		for q in range(left, right+1):
			var cell := Vector2i(q,r)
			if not visible_cells.has(cell): continue
			var polygon := Grid.polygon(cell)
			# Shared edges once; all outer edges close the offshore perimeter.
			for edge in 6:
				if edge >= 3 and visible_cells.has(cell + EDGE_NEIGHBORS[edge]): continue
				lines.append(main.elevation.project(polygon[edge]))
				lines.append(main.elevation.project(polygon[(edge+1)%6]))
	if not lines.is_empty(): draw_multiline(lines, Color(0.93,0.86,0.66,alpha), 1.0/zoom, true)
