extends Node2D
## Independent vector water layers, projected onto the same terrain triangles.
var kind := "rivers"
var records: Array = []
var elevation: RefCounted
var view_rect := Rect2()
var view_zoom := 1.0
var initialized := false
var draw_count := 0
var surface_cache: Dictionary = {}
var cache_costs: Dictionary = {}
var cache_bytes := 0
var cpu_jobs: Node
var projection_cache: Dictionary = {}
var projection_jobs: Dictionary = {}
var vector_bytes := 0
var line_nodes: Dictionary = {}
var line_style: ShaderMaterial
var upload_queue: Array = []
const Cache=preload("res://scripts/map/map_cache.gd")

func points(raw: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in raw: result.append(Vector2(float(p[0]),float(p[1])))
	return result

func _ready() -> void:
	z_index = 10 if kind=="rivers" else 9
	line_style=ShaderMaterial.new();line_style.shader=preload("res://scripts/map/line_mesh.gdshader")
	for record in records:
		var b: Array = record["bounds"]
		record["rect"] = Rect2(float(b[0]),float(b[1]),float(b[2])-float(b[0]),float(b[3])-float(b[1])).grow(0.01)
	initialized = true

func invalidate_surface() -> void:
	surface_cache.clear()
	cache_costs.clear();cache_bytes=0
	queue_redraw()

func update_view(rect: Rect2, zoom_value: float) -> void:
	if rect==view_rect and is_equal_approx(zoom_value,view_zoom): return
	view_rect = rect
	view_zoom = zoom_value
	queue_redraw()

func surface_for(record: Dictionary) -> Dictionary:
	var id: String = record["id"]
	if surface_cache.has(id): return Cache.touch(surface_cache,id)
	if cpu_jobs != null:
		var ready: Dictionary=projection_cache.get(elevation.enabled,{}).get(id,{})
		if ready.is_empty():return {}
		if ready.has("vertices"):
			var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=ready.vertices
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
			var value: Dictionary={"mesh":mesh,"rings":ready.rings}
			surface_cache[id]=value
			return value
		return ready
	var result := {}
	if record.has("points"):
		result["line"] = elevation.project_line(points(record["points"]))
	else:
		var vertices := points(record["triangles"])
		for i in range(vertices.size()): vertices[i] = elevation.project(vertices[i])
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		result["mesh"] = mesh
		var rings: Array = []
		for raw in record["rings"]: rings.append(elevation.project_line(points(raw)))
		result["rings"] = rings
	surface_cache[id] = result
	var bytes:=0
	if result.has("line"):bytes=result["line"].size()*8
	else:
		bytes=record["triangles"].size()*8
		for ring in result["rings"]:bytes+=ring.size()*8
	cache_costs[id]=bytes
	cache_bytes=Cache.trim(surface_cache,cache_costs,16*1024*1024)
	return result

func _draw_content() -> void:
	if not initialized: return
	draw_count = 0
	for node in line_nodes.values():node.hide()
	line_style.set_shader_parameter("view_zoom",view_zoom)
	line_style.set_shader_parameter("half_width",0.8 if kind=="rivers" else 0.4)
	line_style.set_shader_parameter("line_color",Color("#459bbb") if kind=="rivers" else Color("#88b7bd"))
	var detail := clampf((view_zoom-0.16)/0.80,0.0,1.0)
	for record in records:
		if not record.get("visible_by_default",true): continue
		if not view_rect.intersects(record["rect"]): continue
		var surface := surface_for(record)
		if surface.is_empty():continue
		draw_count += 1
		var line_key:=str(elevation.enabled)+str(record.id)
		if cpu_jobs!=null:
			if line_nodes.has(line_key):line_nodes[line_key].show()
			if surface.has("mesh"):draw_mesh(surface["mesh"],null,Transform2D.IDENTITY,Color("#377f9b"))
			continue
		if record.has("points"):
			var line: PackedVector2Array = surface["line"]
			if line.size()<2: continue
			var width := lerpf(0.8,1.6,detail)/view_zoom
			if detail>0.45: draw_polyline(line,Color(0.14,0.34,0.42,0.45),(width+0.4/view_zoom),true)
			draw_polyline(line,Color(0.27,0.61,0.73,lerpf(0.80,1.0,detail)),width,true)
		else:
			draw_mesh(surface["mesh"],null,Transform2D.IDENTITY,Color("#377f9b"))
			for ring in surface["rings"]:
				draw_polyline(ring,Color("#88b7bd"),lerpf(0.4,0.85,detail)/view_zoom,true)

func _process(_delta: float) -> void:
	if cpu_jobs == null or not initialized:return
	for mode in [elevation.enabled,not elevation.enabled]:
		var key:=kind+":"+str(mode)
		if projection_cache.has(mode):continue
		if cpu_jobs.is_complete(key):
			var result: Dictionary=cpu_jobs.take(key)
			projection_cache[mode]=result
			for id in result:
				upload_queue.append({"key":str(mode)+str(id),"arrays":result[id].line_arrays})
				result[id].erase("line_arrays")
			for item in result.values():
				if item.has("line"):vector_bytes+=item.line.size()*160
				else:
					vector_bytes+=item.vertices.size()*16 # CPU vertices plus GPU upload.
					for ring in item.rings:vector_bytes+=ring.size()*160
			queue_redraw()
		elif not projection_jobs.has(mode):
			var surface=elevation.snapshot();surface.enabled=mode
			if cpu_jobs.submit(key,preload("res://scripts/map/map_vector_jobs.gd").project_water.bind(records,surface),8*1024*1024):projection_jobs[mode]=true

	var upload_start:=Time.get_ticks_usec()
	while not upload_queue.is_empty():
		var item: Dictionary=upload_queue.pop_front()
		var arrays: Array=item.arrays
		if arrays[Mesh.ARRAY_VERTEX].is_empty():continue
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		var node:=MeshInstance2D.new();node.mesh=mesh;node.material=line_style
		node.hide();add_child(node);line_nodes[item.key]=node
		queue_redraw()
		if Time.get_ticks_usec()-upload_start>1500:break

var last_slow_draw_ms := -1000
func _draw() -> void:
	var start := Time.get_ticks_usec()
	_draw_content()
	var duration := Time.get_ticks_usec()-start
	if duration>10000 and Time.get_ticks_msec()-last_slow_draw_ms>1000:
		last_slow_draw_ms=Time.get_ticks_msec()
		get_node("/root/MapDiagnostics").record("slow_draw", {"layer":get_script().resource_path,"duration_us":duration})
