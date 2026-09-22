extends Node2D
## Approved political vectors only. No reference raster or click-mask outlines.
const REGISTRY := "res://data/derived/political/approved_western/political_registry.json"
var data: Dictionary = {}
var coast_points: Dictionary = {}
var boundary_points: Dictionary = {}
var coast_arcs: Dictionary = {}
var boundary_arcs: Dictionary = {}
var click_polygons: Dictionary = {}
var region_names: Dictionary = {}
var unresolved_region_ids: Array[String] = []
var selected_id := ""
var initialized := false
var view_zoom := 1.0
var world_bounds := Rect2()
var elevation: RefCounted
var surface_lines: Dictionary = {}
var cpu_jobs: Node
var projection_cache: Dictionary = {}
var projection_jobs: Dictionary = {}
var vector_bytes := 0
var coast_batch := PackedVector2Array()
var border_batch := PackedVector2Array()
var coast_mesh: Node2D
var border_mesh: Node2D

func append_segments(line: PackedVector2Array, target: PackedVector2Array) -> void:
	for i in range(line.size()-1):
		target.append(line[i])
		target.append(line[i+1])

func invalidate_surface() -> void:
	surface_lines.clear()
	coast_batch.clear()
	border_batch.clear()
	queue_redraw()

func display_line(line: PackedVector2Array) -> PackedVector2Array:
	if elevation == null: return line
	if cpu_jobs != null:
		return projection_cache.get(elevation.enabled,{}).get(line,PackedVector2Array())
	if not surface_lines.has(line): surface_lines[line] = elevation.project_line(line)
	return surface_lines[line]

func _ready() -> void:
	z_index = 20
	coast_mesh=preload("res://scripts/map/line_mesh_batch.gd").new()
	border_mesh=preload("res://scripts/map/line_mesh_batch.gd").new()
	add_child(coast_mesh);add_child(border_mesh)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	if not parsed is Dictionary or parsed.get("status", "") != "approved":
		push_error("Approved political registry is missing")
		return
	data = parsed
	var bounds: Array = data["bounds"]
	world_bounds = Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2])-float(bounds[0]), float(bounds[3])-float(bounds[1]))
	for id in data["coastlines"]:
		coast_points[id] = to_points(data["coastlines"][id])
	for boundary in data["boundaries"]:
		boundary_points[boundary["boundary_id"]] = to_points(boundary["points"])
	for reference in data["coastline_references"]:
		coast_arcs[reference["arc_id"]] = resolve_coast_arc(reference)
	for reference in data.get("boundary_references",[]):
		for boundary in data["boundaries"]:
			if boundary["boundary_id"]==reference["boundary_id"]:
				boundary_arcs[reference["arc_id"]]=resolve_line_arc(boundary["points"],reference)
	for region in data["regions"]:
		var polygons: Array = []
		for polygon in region["polygons"]:
			polygons.append(to_points(polygon))
		click_polygons[region["region_id"]] = polygons
		region_names[region["region_id"]] = region["name_ja"]
		if region.get("name_status", "") == "unconfirmed":
			unresolved_region_ids.append(str(region["region_id"]))
	initialized = true
	queue_redraw()

func to_points(raw: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in raw: result.append(Vector2(float(p[0]), float(p[1])))
	return result

func resolve_coast_arc(reference: Dictionary) -> PackedVector2Array:
	return resolve_line_arc(data["coastlines"][reference["coastline_id"]],reference)

func resolve_line_arc(raw: Array, reference: Dictionary) -> PackedVector2Array:
	# Compute distances from original double JSON coordinates, not float Vector2
	# cumulative lengths. Both normal and selected lines reference the same ring.
	var ranges: Array = [[float(reference["start_distance"]), float(reference["end_distance"])]]
	if reference["wrap"]:
		ranges = [[float(reference["start_distance"]), INF], [0.0, float(reference["end_distance"])]]
	var result := PackedVector2Array()
	for interval in ranges:
		var along := 0.0
		for i in range(raw.size()-1):
			var ax := float(raw[i][0])
			var ay := float(raw[i][1])
			var dx := float(raw[i+1][0])-ax
			var dy := float(raw[i+1][1])-ay
			var length := sqrt(dx*dx+dy*dy)
			var start := maxf(along,float(interval[0]))
			var end := minf(along+length,float(interval[1]))
			if end>start and length>0:
				var a := Vector2(ax+dx*(start-along)/length,ay+dy*(start-along)/length)
				var b := Vector2(ax+dx*(end-along)/length,ay+dy*(end-along)/length)
				if result.is_empty() or result[-1]!=a: result.append(a)
				result.append(b)
			along += length
	return result

func update_view(rect: Rect2, zoom_value: float) -> void:
	visible = zoom_value <= 2.0 and rect.intersects(world_bounds)
	if not is_equal_approx(view_zoom,zoom_value):
		view_zoom = zoom_value
		queue_redraw()

func hit_test(point: Vector2) -> String:
	if not initialized or not world_bounds.has_point(point): return ""
	for id in click_polygons:
		for polygon in click_polygons[id]:
			if Geometry2D.is_point_in_polygon(point,polygon): return id
	return ""

func select_at(point: Vector2) -> String:
	selected_id = hit_test(point)
	queue_redraw()
	return str(region_names.get(selected_id,""))

func selection_lines(id: String) -> Array:
	var result: Array = []
	for boundary in data.get("boundaries",[]):
		if id in [boundary["region_a"],boundary["region_b"]]:
			result.append(boundary_points[boundary["boundary_id"]])
	for reference in data.get("coastline_references",[]):
		if reference["region_id"]==id: result.append(coast_arcs[reference["arc_id"]])
	for reference in data.get("boundary_references",[]):
		if reference["region_id"]==id: result.append(boundary_arcs[reference["arc_id"]])
	return result

func _draw_content() -> void:
	if not initialized: return
	# Explicitly unresolved names receive a red fill underneath all border lines.
	for id in unresolved_region_ids:
		for polygon in click_polygons[id]:
			var projected := display_line(polygon)
			if projected.size()>2:draw_colored_polygon(projected, Color("#e34b4b"))
	# Draw only owned coast intervals, not the entire Honshu canonical ring.
	if coast_batch.is_empty():
		for line in coast_arcs.values(): append_segments(display_line(line),coast_batch)
	if border_batch.is_empty():
		for line in boundary_points.values(): append_segments(display_line(line),border_batch)
	if not coast_batch.is_empty(): coast_mesh.configure(coast_batch,1.3,Color("#42382e"),view_zoom)
	if not border_batch.is_empty(): border_mesh.configure(border_batch,1.5,Color("#42382e"),view_zoom)

func _process(_delta: float) -> void:
	if cpu_jobs == null or not initialized:return
	for mode in [elevation.enabled,not elevation.enabled]:
		var key := "political:"+str(mode)
		if projection_cache.has(mode):continue
		if cpu_jobs.is_complete(key):
			var result: Dictionary=cpu_jobs.take(key)
			projection_cache[mode]=result
			for line in result.values():vector_bytes+=line.size()*8
			invalidate_surface()
		elif not projection_jobs.has(mode):
			var lines := {}
			for line in coast_arcs.values()+boundary_points.values()+boundary_arcs.values():lines[line]=line
			for id in unresolved_region_ids:
				for line in click_polygons[id]:lines[line]=line
			var surface=elevation.snapshot();surface.enabled=mode
			if cpu_jobs.submit(key,preload("res://scripts/map/map_vector_jobs.gd").project_lines.bind(lines,surface),4*1024*1024):projection_jobs[mode]=true

var last_slow_draw_ms := -1000
func _draw() -> void:
	var start := Time.get_ticks_usec()
	_draw_content()
	var duration := Time.get_ticks_usec()-start
	if duration>10000 and Time.get_ticks_msec()-last_slow_draw_ms>1000:
		last_slow_draw_ms=Time.get_ticks_msec()
		get_node("/root/MapDiagnostics").record("slow_draw", {"layer":get_script().resource_path,"duration_us":duration})
