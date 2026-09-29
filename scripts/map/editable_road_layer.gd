extends Node2D
const Grid = preload("res://scripts/map/hex_grid.gd")
const Network = preload("res://scripts/map/hex_road_network.gd")
const LineBatch = preload("res://scripts/map/line_mesh_batch.gd")
var main: Node
var network: RefCounted
var editing := false
var edge_editing := false
var outline: Node2D
var stroke: Node2D
var view_rect := Rect2()
var view_zoom := 1.0
var projected_mode := false

func _ready() -> void:
	z_index = 0
	outline = LineBatch.new()
	stroke = LineBatch.new()
	add_child(outline)
	add_child(stroke)
	stroke.z_index = 1
	network.changed.connect(queue_redraw)

func update_view(rect: Rect2, zoom_value: float) -> void:
	if rect == view_rect and is_equal_approx(zoom_value,view_zoom) and projected_mode == main.elevation.enabled: return
	view_rect = rect
	view_zoom = zoom_value
	projected_mode = main.elevation.enabled
	queue_redraw()

func _draw() -> void:
	var segments := PackedVector2Array()
	if view_zoom < Grid.MIN_DRAW_ZOOM:
		outline.hide()
		stroke.hide()
		return
	var padded_view := view_rect.grow(Grid.RADIUS*2)
	for cell in network.cells:
		var center: Vector2 = Grid.center(cell)
		if not padded_view.has_point(center): continue
		var p: Vector2 = main.elevation.project(center)
		if editing:
			var polygon := Grid.polygon(cell)
			for i in polygon.size(): polygon[i] = main.elevation.project(polygon[i])
			draw_colored_polygon(polygon,Color(0.96,0.75,0.3,0.22))
		var connected := false
		for i in 6:
			var neighbor: Vector2i = cell + Network.NEIGHBORS[i]
			if not network.cells.has(neighbor): continue
			if not network.connected(cell,neighbor):
				if editing and edge_editing and i < 3:
					draw_dashed_line(p,main.elevation.project(Grid.center(neighbor)),Color(0.95,0.35,0.3,0.75),1.5/view_zoom,4.0/view_zoom)
				continue
			connected = true
			if i >= 3: continue # Each undirected edge is drawn once.
			segments.append(p)
			segments.append(main.elevation.project(Grid.center(neighbor)))
		if not connected:
			draw_circle(p,3.5/view_zoom,Color("#39362e"))
			draw_circle(p,2.0/view_zoom,Color("#ffe196"))
	outline.configure(segments,3.5,Color("#39362e"),view_zoom)
	stroke.configure(segments,2.0,Color("#ffe196"),view_zoom)
