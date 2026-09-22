extends Node2D
## Standalone, non-exported review scene. Never loads from the production scene.
const WORK := "res://data/work/political/kyushu_registration/"
var data: Dictionary = {}
var coast_points: Dictionary = {}
var boundary_points: Dictionary = {}
var coast_arcs: Dictionary = {}
var click_polygons: Dictionary = {}
var world_bounds := Rect2()
var zoom_value := 1.0
var offset := Vector2.ZERO
var selected_id := ""
var show_raster := false
var show_borders := true
var raster: Texture2D
var raster_rect := Rect2()
var label: Label
var initialized := false
var dragging := false
var mouse_down := Vector2.ZERO
var moved := false
var raster_toggle: CheckButton
var border_toggle: CheckButton

func points(raw: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in raw:
		result.append(Vector2(float(p[0]), float(p[1])))
	return result

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#203e4b"))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(WORK + "review_layer.json"))
	if not parsed is Dictionary or parsed.get("status", "") != "pending_user_review":
		push_error("Expected an unapproved Kyushu review candidate")
		return
	data = parsed
	var bounds: Array = data["bounds"]
	world_bounds = Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2])-float(bounds[0]), float(bounds[3])-float(bounds[1]))
	for id in data["coastlines"]:
		coast_points[id] = points(data["coastlines"][id])
	for boundary in data["boundaries"]:
		boundary_points[boundary["boundary_id"]] = points(boundary["points"])
	for reference in data["coastline_references"]:
		coast_arcs[reference["arc_id"]] = resolve_coast_arc(reference)
	for region in data["regions"]:
		var polygons: Array = []
		for polygon in region["polygons"]:
			polygons.append(points(polygon))
		click_polygons[region["region_id"]] = polygons
	var image := Image.load_from_file(WORK + "warped_raster.png")
	if image == null or image.is_empty():
		push_error("Registered image missing")
		return
	raster = ImageTexture.create_from_image(image)
	var geo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORK + "raster_georeference.json"))
	var resolution := float(geo["pixels_per_game_unit"])
	# Georeference records pixel CENTRES, Texture2D draws pixel EDGES.
	raster_rect = Rect2(world_bounds.position - Vector2.ONE * 0.5 / resolution, Vector2(image.get_size()) / resolution)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	label = Label.new()
	column.add_child(label)
	raster_toggle = CheckButton.new()
	raster_toggle.text = "変形した画像を重ねる（W）"
	raster_toggle.toggled.connect(func(value: bool): show_raster = value; queue_redraw())
	column.add_child(raster_toggle)
	border_toggle = CheckButton.new()
	border_toggle.text = "抽出した国境線（B）"
	border_toggle.button_pressed = true
	border_toggle.toggled.connect(func(value: bool): show_borders = value; queue_redraw())
	column.add_child(border_toggle)
	get_viewport().size_changed.connect(fit_map)
	initialized = true
	fit_map()
	update_label()

func fit_map() -> void:
	var available := get_viewport_rect().size - Vector2(40, 40)
	zoom_value = minf(available.x / world_bounds.size.x, available.y / world_bounds.size.y)
	offset = get_viewport_rect().size * 0.5 - world_bounds.get_center() * zoom_value
	queue_redraw()

func resolve_coast_arc(reference: Dictionary) -> PackedVector2Array:
	var canonical: PackedVector2Array = coast_points[reference["coastline_id"]]
	var ranges: Array = [[float(reference["start_distance"]), float(reference["end_distance"])]]
	if reference["wrap"]:
		ranges = [[float(reference["start_distance"]), INF], [0.0, float(reference["end_distance"])]]
	var result := PackedVector2Array()
	for interval in ranges:
		var length_so_far := 0.0
		for i in range(canonical.size() - 1):
			var a := canonical[i]
			var b := canonical[i + 1]
			var segment_length := a.distance_to(b)
			var start := maxf(length_so_far, float(interval[0]))
			var end := minf(length_so_far + segment_length, float(interval[1]))
			if end > start and segment_length > 0.0:
				var p := a.lerp(b, (start-length_so_far)/segment_length)
				if result.is_empty() or result[-1].distance_to(p) > 0.0001:
					result.append(p)
				result.append(a.lerp(b, (end-length_so_far)/segment_length))
			length_so_far += segment_length
	return result

func hit_test(world_point: Vector2) -> String:
	for region_id in click_polygons:
		for polygon in click_polygons[region_id]:
			if Geometry2D.is_point_in_polygon(world_point, polygon):
				return region_id
	return ""

func selection_lines(region_id: String) -> Array:
	var result: Array = []
	for boundary in data["boundaries"]:
		if region_id in [boundary["region_a"], boundary["region_b"]]:
			result.append(boundary_points[boundary["boundary_id"]])
	for reference in data["coastline_references"]:
		if reference["region_id"] == region_id:
			result.append(coast_arcs[reference["arc_id"]])
	return result

func _draw() -> void:
	if not initialized:
		return
	draw_set_transform(offset, 0.0, Vector2.ONE * zoom_value)
	for polygon in coast_points.values():
		draw_colored_polygon(polygon, Color("#faf9f5"))
	if show_raster:
		draw_texture_rect(raster, raster_rect, false)
	for line in coast_points.values():
		draw_polyline(line, Color("#ec4784") if show_raster else Color("#332b24"), 1.5 / zoom_value, true)
	if show_borders:
		for line in boundary_points.values():
			draw_polyline(line, Color("#00b9cf") if show_raster else Color("#332b24"), 1.5 / zoom_value, true)
	if not selected_id.is_empty():
		for line in selection_lines(selected_id):
			draw_polyline(line, Color("#eeb02b"), 3.0 / zoom_value, true)
	# click_polygons are never used for drawing outlines.

func _unhandled_input(event: InputEvent) -> void:
	if not initialized:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_W:
			raster_toggle.button_pressed = not show_raster
		elif event.keycode == KEY_B:
			border_toggle.button_pressed = not show_borders
		elif event.keycode == KEY_F:
			fit_map()
		queue_redraw()
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var world: Vector2 = (event.position - offset) / zoom_value
			zoom_value = clampf(zoom_value * (1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 0.2, 5.0)
			offset = event.position - world * zoom_value
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed:
				mouse_down = event.position
				moved = false
			elif not moved:
				selected_id = hit_test((event.position-offset)/zoom_value)
				update_label()
				queue_redraw()
	if event is InputEventMouseMotion and dragging:
		moved = moved or event.position.distance_to(mouse_down) > 4.0
		if moved:
			offset += event.relative
			queue_redraw()

func update_label() -> void:
	var title := "未選択"
	for region in data["regions"]:
		if region["region_id"] == selected_id:
			title = region["name_ja"]
	label.text = "九州本島・未承認レビュー\n%s\nクリック: 国名 / ドラッグ: 移動\nホイール: 拡縮 / F: 全体" % title
