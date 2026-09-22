extends "res://scripts/map/road_geometry.gd"
## Terrain-checked estimated connection geometry and annotations.
var selected_id := ""
var site_connections: Dictionary = {}
var segment_lookup: Dictionary = {}
var anchor_lookup: Dictionary = {}
var crossing_lookup: Dictionary = {}
var drawn_segments := 0
var selected_waypoint_count := 0

func _ready() -> void:
	z_index = 20
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/road_connections/connections_1582.json"))
	for route in data["routes"]: route_lookup[route["id"]] = route
	for segment in data["segments"]:
		segment_lookup[segment["id"]] = segment
		var bounds := Rect2(point(segment["points"][0]),Vector2.ZERO)
		for p in segment["points"]: bounds = bounds.expand(point(p))
		segment["draw_bounds"] = bounds.grow(2)
	for anchor in data["anchors"]: anchor_lookup[anchor["id"]] = anchor
	for crossing in data["crossings"]: crossing_lookup[crossing["id"]] = crossing
	for site in data["site_connections"]: site_connections[site["site_id"]] = site

func select_route(id: String) -> void:
	selected_id = id
	queue_redraw()
	if shared_renderer != null: shared_renderer.queue_redraw()
	if settlements != null: settlements.queue_redraw()

func _draw() -> void:
	drawn_segments = 0
	selected_waypoint_count = 0
	screen_label_rects.clear()
	if data == null: return
	var selected: Dictionary = route_lookup.get(selected_id,{})
	for segment in data["segments"]:
		if not view_rect.intersects(segment["draw_bounds"]): continue
		var active: bool = selected_id in segment["route_ids"]
		if view_zoom < 0.18 and segment["role"] == "site_access" and not active: continue
		# SharedRoads owns strokes; this layer owns route annotations only.
		drawn_segments += 1
	if selected.is_empty(): return
	var font := ThemeDB.fallback_font
	var labels: Array[Rect2] = []
	for waypoint in selected["waypoints"]:
		var ground := point(waypoint["point"])
		if not view_rect.has_point(ground): continue
		var p: Vector2 = elevation.project(ground)
		draw_arc(p,5/view_zoom,0,TAU,16,Color("#9cebdd"),1.5/view_zoom,true)
		var label_text := "%d" % waypoint["order"]
		var label_pos := p
		var found := false
		for offset in [Vector2(7,-7),Vector2(7,22),Vector2(-45,-7),Vector2(-45,22)]:
			var candidate: Vector2=p+offset/view_zoom
			var screen: Vector2=get_global_transform_with_canvas()*candidate
			var rect := Rect2(screen-Vector2(0,17),Vector2(45,21))
			if screen.x < 405 or rect.end.x > get_viewport_rect().size.x-8 or screen.y < 125 or rect.end.y > get_viewport_rect().size.y-8: continue
			var overlaps := false
			for other in labels:
				if rect.intersects(other): overlaps=true;break
			if overlaps: continue
			labels.append(rect);screen_label_rects.append(rect);label_pos=candidate;found=true;break
		if not found: continue
		draw_set_transform(label_pos,0,Vector2.ONE/view_zoom)
		draw_string_outline(font,Vector2.ZERO,label_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,4,Color("#25342d"))
		draw_string(font,Vector2.ZERO,label_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#b5f2df"))
		draw_set_transform(Vector2.ZERO)
		selected_waypoint_count += 1
	for id in selected["crossing_ids"]:
		var crossing: Dictionary = crossing_lookup[id]
		var a: Vector2 = point(anchor_lookup[crossing["bank_anchor_ids"][0]]["point"])
		var b: Vector2 = point(anchor_lookup[crossing["bank_anchor_ids"][1]]["point"])
		if view_rect.has_point((a+b)*0.5):
			draw_arc(elevation.project((a+b)*0.5),6/view_zoom,0,TAU,16,Color("#ffab79"),1.8/view_zoom,true)
	for key in ["from_site","to_site"]:
		var site_id: String = selected[key]
		var connection: Dictionary = site_connections[site_id]
		var arrival: Vector2 = point(anchor_lookup[connection["anchor_id"]]["point"])
		if settlements != null:
			var symbol: Vector2 = point(settlements.lookup[site_id]["point"])
			# Explanation leader only: deliberately distinct from the road graph.
			draw_line(elevation.project(symbol),elevation.project(arrival),Color("#b7d3d8"),1.0/view_zoom,true)
			draw_circle(elevation.project(arrival),3.0/view_zoom,Color("#b7f3d4"))
	if settlements != null: settlements.queue_redraw()
