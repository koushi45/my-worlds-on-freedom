extends Node2D
## One prevalidated administrative tile per district; follows the hex visibility.
const Grid = preload("res://scripts/map/hex_grid.gd")
const DATA_PATH := "res://data/derived/scenarios/district_offices_1546.json"
var main: Node2D
var records: Dictionary = {}
var cell_districts: Dictionary = {}
var view_rect := Rect2()
var view_zoom := 1.0
var drawn_ids: Array[String] = []
var drawn_kamon_houses: Dictionary = {}

func _ready() -> void:
	z_index = 3
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert(is_equal_approx(float(data.radius), Grid.RADIUS), "Rebuild district offices after changing hex size")
	records = data.records
	for id in records:
		var cell: Array = records[id].cell
		cell_districts[Vector2i(int(cell[0]), int(cell[1]))] = id

func update_view(rect: Rect2, zoom_value: float) -> void:
	view_rect = rect
	view_zoom = zoom_value
	queue_redraw()

func office_point(district_id: String) -> Vector2:
	var point: Array = records[district_id].point
	return Vector2(float(point[0]), float(point[1]))

func pick(world: Vector2) -> String:
	if not is_visible_in_tree() or view_zoom < Grid.MIN_DRAW_ZOOM: return ""
	return str(cell_districts.get(Grid.cell_at(world), ""))

func _draw() -> void:
	if main != null and main.map_view != null:
		if main.map_view.get_meta("probe_single_marker_redraw",true): main.map_view.markers.invalidate()
		else: main.map_view.markers.queue_redraw()
	drawn_ids.clear()
	drawn_kamon_houses.clear()
	if main == null or view_zoom < Grid.MIN_DRAW_ZOOM: return
	var font := ThemeDB.fallback_font
	var label_boxes: Array[Rect2] = []
	for id in records:
		var center := office_point(id)
		if not view_rect.has_point(center): continue
		var polygon := Grid.polygon(Grid.cell_at(center))
		for i in polygon.size(): polygon[i] = main.elevation.project(polygon[i])
		var house_id := ""
		if main.governance_registry != null:
			house_id = str(main.governance_registry.districts.get(id, {}).get("house_id", ""))
		var background := Color("#8b7c67")
		if main.territory_borders != null: background = main.territory_borders.theme_color(house_id)
		draw_colored_polygon(polygon, background)
		polygon.append(polygon[0])
		draw_polyline(polygon, Color("#ffe6a0"), 1.5/view_zoom, true)
		drawn_ids.append(str(id))
		if main.map_view != null:
			drawn_kamon_houses[id] = house_id
			continue
		var point: Vector2 = main.elevation.project(center)
		draw_set_transform(point, 0, Vector2.ONE/view_zoom)
		if main.kamon_layer != null and main.governance_registry.districts.has(id):
			var entry: Dictionary = main.kamon_layer.kamon_by_house.get(house_id, {})
			var texture: Texture2D = main.kamon_layer.kamon_textures.get(entry.get("asset", ""))
			if texture != null:
				var size := minf(24.0, Grid.RADIUS * view_zoom * 1.1)
				draw_texture_rect(texture, Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size), false)
				drawn_kamon_houses[id] = house_id
		draw_set_transform(Vector2.ZERO)
		if view_zoom < 3.0: continue
		var text: String = records[id].name
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var offset := Vector2(-width*.5, Grid.RADIUS*view_zoom+16)
		var screen: Vector2 = get_global_transform_with_canvas()*point
		var box := Rect2(screen+offset-Vector2(0,13), Vector2(width,17))
		var overlaps := false
		for other in label_boxes:
			if box.intersects(other): overlaps = true; break
		if overlaps: continue
		label_boxes.append(box)
		draw_set_transform(point, 0, Vector2.ONE/view_zoom)
		draw_string_outline(font, offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("#24180c"))
		draw_string(font, offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fff0bc"))
		draw_set_transform(Vector2.ZERO)

