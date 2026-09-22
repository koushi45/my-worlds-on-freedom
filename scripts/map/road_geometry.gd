extends Node2D
## Shared geometry utilities for estimated connections.
var elevation: RefCounted
var settlements: Node2D
var data: Dictionary
var view_zoom := 1.0
var view_rect := Rect2()
var surface_cache: Dictionary = {}
var cache_costs: Dictionary = {}
var cache_bytes := 0
var cpu_jobs: Node
var projection_cache: Dictionary = {}
var projection_jobs: Dictionary = {}
var vector_bytes := 0
const Cache=preload("res://scripts/map/map_cache.gd")
var route_lookup: Dictionary = {}
var screen_label_rects: Array[Rect2] = []
var shared_renderer: Node2D

func invalidate_surface() -> void:
	surface_cache.clear()
	cache_costs.clear();cache_bytes=0
	queue_redraw()

func update_view(rect: Rect2, zoom_value: float) -> void:
	if rect == view_rect and is_equal_approx(zoom_value,view_zoom): return
	view_rect = rect
	view_zoom = zoom_value
	queue_redraw()

func point(raw: Array) -> Vector2:
	return Vector2(float(raw[0]),float(raw[1]))

func surface_for(route: Dictionary) -> PackedVector2Array:
	if cpu_jobs != null:return projection_cache.get(elevation.enabled,{}).get(route["id"],PackedVector2Array())
	if surface_cache.has(route["id"]):return Cache.touch(surface_cache,route["id"])
	var vertices := PackedVector2Array()
	for p in route["points"]: vertices.append(point(p))
	var result:PackedVector2Array=elevation.project_line(vertices)
	surface_cache[route["id"]]=result;cache_costs[route["id"]]=result.size()*8
	cache_bytes=Cache.trim(surface_cache,cache_costs,8*1024*1024)
	return result


func _process(_delta: float) -> void:
	if cpu_jobs == null or data == null:return
	var entries: Array=data.get("strokes",[])
	for mode in [elevation.enabled,not elevation.enabled]:
		var key := "roads:"+str(get_instance_id())+":"+str(mode)
		if projection_cache.has(mode):continue
		if cpu_jobs.is_complete(key):
			var result: Dictionary=cpu_jobs.take(key)
			projection_cache[mode]=result
			for line in result.values():vector_bytes+=line.size()*8
			queue_redraw()
		elif not projection_jobs.has(mode):
			var lines := {}
			for entry in entries:
				var points:=PackedVector2Array()
				for p in entry.points:points.append(point(p))
				lines[entry.id]=points
			var surface=elevation.snapshot();surface.enabled=mode
			if cpu_jobs.submit(key,preload("res://scripts/map/map_vector_jobs.gd").project_lines.bind(lines,surface),2*1024*1024):projection_jobs[mode]=true
