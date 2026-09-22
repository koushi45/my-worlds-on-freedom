extends Node2D
## District shapes and their country grouping are independent of political lines.
var independent_geometry: RefCounted
const INDEX := "res://data/derived/districts/accepted/index.json"
const REVIEW_INDEX := "res://data/work/districts/stage_f/index.json"
const UNCONFIRMED_INDEX := "res://data/derived/districts/unconfirmed/index.json"
var unconfirmed_mode := OS.has_feature("district_unconfirmed") or (OS.has_feature("editor") and "--district-unconfirmed" in OS.get_cmdline_user_args())
var review_mode := unconfirmed_mode or (OS.has_feature("editor") and "--district-review" in OS.get_cmdline_user_args())
var releases: Dictionary = {}
const CELL := 128.0
const DETAIL := 0.65
var elevation: RefCounted
var asset_stream: Node
var cpu_jobs: Node
var parent_jobs: Dictionary = {}
var pick_workers: Dictionary = {}
var batch_nodes: Dictionary = {}
var wanted_batches: Dictionary = {}
var batch_style: ShaderMaterial
var generation := 0
var compiled_parents: Dictionary = {}
var compiled_fills: Dictionary = {}
var waiting_parents: Dictionary = {}
var settlements: Node2D
var records: Dictionary = {}
var parents: Dictionary = {}
var grid: Dictionary = {}
var loaded: Dictionary = {}
var projected: Dictionary = {}
var view_rect := Rect2()
var view_zoom := 1.0
var boundaries_enabled := true
var selected_key := ""
var selected_mesh: ArrayMesh
var active_keys: Array = []
var initialized := false
var draw_line_count := 0
var label_count := 0 # District names are intentionally not drawn.
var boundary_mesh: Node2D

func rect_for(b: Array) -> Rect2:
	return Rect2(Vector2(b[0],b[1]),Vector2(b[2]-b[0],b[3]-b[1])).grow(0.001)

func points(raw) -> PackedVector2Array:
	if raw is PackedVector2Array: return raw
	var result := PackedVector2Array()
	for p in raw: result.append(Vector2(p[0],p[1]))
	return result

func cells(rect: Rect2) -> Array:
	var result: Array = []
	for y in range(int(floor(rect.position.y/CELL)),int(floor(rect.end.y/CELL))+1):
		for x in range(int(floor(rect.position.x/CELL)),int(floor(rect.end.x/CELL))+1): result.append(Vector2i(x,y))
	return result

func _ready() -> void:
	# District borders sit above political borders; crests use their own overlay.
	z_index = 21
	batch_style = ShaderMaterial.new()
	batch_style.shader = preload("res://scripts/map/line_mesh.gdshader")
	batch_style.set_shader_parameter("dashed",true)
	batch_style.set_shader_parameter("half_width",0.45)
	batch_style.set_shader_parameter("line_color",Color("#746347"))
	boundary_mesh=preload("res://scripts/map/line_mesh_batch.gd").new()
	add_child(boundary_mesh)
	var source: String = REVIEW_INDEX if review_mode else INDEX
	if unconfirmed_mode: source = UNCONFIRMED_INDEX
	if not FileAccess.file_exists(source): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	if independent_geometry == null and unconfirmed_mode and asset_stream!=null and asset_stream.manifest.get("source_index_sha256","")==FileAccess.get_sha256(source):
		compiled_parents=asset_stream.manifest.get("parents",{})
		compiled_fills=asset_stream.manifest.get("districts",{})
	if unconfirmed_mode and data.get("status", "") != "unconfirmed_preview": return
	if not review_mode and not valid_accepted_index(data):
		push_warning("District adoption manifest rejected; held data is not loaded")
		return
	if independent_geometry != null:
		var originals := {}
		for r in data.regions: originals[r.key] = r
		for id in independent_geometry.extra_districts:
			var extra: Dictionary = independent_geometry.extra_districts[id]
			var r: Dictionary = originals[extra.source_id].duplicate(true)
			r.key = id
			r.name = extra.name
			r.sites = []
			data.regions.append(r)
	for r in data["regions"]:
		if independent_geometry != null and not independent_geometry.regions.has(r.key): continue
		if independent_geometry != null and independent_geometry.regions.has(r.key):
			r.bounds = independent_geometry.regions[r.key].bounds
			r.label = independent_geometry.regions[r.key].label
		r["rect"] = rect_for(r["bounds"])
		records[r["key"]] = r
		for cell in cells(r["rect"]):
			if not grid.has(cell): grid[cell] = []
			grid[cell].append(r["key"])
	for p in data["parents"]: parents[p["id"]] = p
	initialized = true
	if unconfirmed_mode: print("UNCONFIRMED DISTRICTS: %d parents, %d regions" % [parents.size(), records.size()])
	visibility_changed.connect(queue_redraw)
	if asset_stream!=null:asset_stream.arrived.connect(_resources_arrived)

func pending_resource_paths() -> Array:
	var paths: Array=[]
	for id in waiting_parents:paths.append(compiled_parents.get(id,""))
	if not selected_key.is_empty():paths.append(compiled_fills.get(selected_key+("_tilt" if elevation.enabled else "_flat"),""))
	paths.append_array(wanted_batches.keys())
	return paths

func _resources_arrived() -> void:
	for id in waiting_parents.keys():load_parent(id)
	queue_redraw()

func valid_accepted_index(data: Dictionary) -> bool:
	if data.get("status","") != "accepted_registry": return false
	var accepted: Dictionary = {}
	for p in data.get("parents",[]):
		if p.get("adoption_status","") != "accepted": return false
		var prefix: String = "res://data/derived/districts/accepted/releases/"+p["id"]+"/"+p.get("release_id","")+"/"
		if ".." in prefix: return false
		if p.get("file","") != prefix+"geometry.json": return false
		if data.get("active_releases",{}).get(p["id"],{}).get("revision","") != p["release_id"]: return false
		accepted[p["id"]] = prefix
	for r in data.get("regions",[]):
		if not accepted.has(r.get("parent","")): return false
		if r.get("adoption_status","") not in ["accepted_game_estimate","accepted_unresolved_area"]: return false
		if not str(r.get("mesh_file","")).begins_with(accepted[r["parent"]]): return false
		if ".." in r["mesh_file"]: return false
	return true

func query(rect: Rect2) -> Array:
	var result: Dictionary = {}
	for cell in cells(rect):
		for key in grid.get(cell,[]):
			if records[key]["rect"].intersects(rect): result[key] = true
	return result.keys()

func load_parent(id: String) -> void:
	if loaded.has(id): return
	if independent_geometry != null:
		loaded[id] = independent_geometry.parent_data(id)
		return
	waiting_parents[id] = true
	if parent_jobs.has(id): return
	if compiled_parents.has(id):
		var path: String = compiled_parents[id]
		if asset_stream.failed.has(path) or asset_stream.denied.has(path):
			waiting_parents.erase(id)
			return
		var compiled: Resource = asset_stream.fetch(path)
		if compiled == null: return
		if compiled.data.has("line_grid"):
			loaded[id] = compiled.data # Immutable, build-time indices; no deep copy.
			waiting_parents.erase(id)
			return
		if cpu_jobs != null:
			var data: Dictionary = compiled.data
			if cpu_jobs.submit("parent:"+id,preload("res://scripts/map/map_line_geometry.gd").prepare_parent.bind(data),4*1024*1024,generation):
				parent_jobs[id]=null
		return
	if cpu_jobs == null:
		_load_legacy_parent(id)
		waiting_parents.erase(id)
		return
	# Source-only development / accepted releases: validation and parsing on an
	# exclusively owned detached object. It never touches nodes in the live tree.
	var worker = get_script().new()
	worker.parents=parents
	worker.records=records
	worker.review_mode=review_mode
	worker.elevation=elevation.snapshot()
	if cpu_jobs.submit("parent:"+id,worker.prepare_legacy.bind(id),8*1024*1024,generation):
		parent_jobs[id]=worker
	else: worker.free()

func prepare_legacy(id: String) -> Dictionary:
	_load_legacy_parent(id)
	if loaded.has(id):
		for line in loaded[id]["lines"]:
			elevation.enabled=false;line["surface_flat"]=elevation.project_line(line["vector"])
			elevation.enabled=true;line["surface_tilt"]=elevation.project_line(line["vector"])
	return {"data":loaded.get(id,{}),"release":releases.get(id,{})}

func _load_legacy_parent(id: String) -> void:
	if loaded.has(id): return
	if not review_mode:
		var path: String = str(parents[id]["file"]).get_base_dir()+"/release.json"
		if not FileAccess.file_exists(path): return
		var release: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		if release.get("status","") != "accepted" or release.get("parent","") != id: return
		if release.get("release_id","") != parents[id].get("release_id",""): return
		var expected_count := 0
		for key in records:
			if records[key]["parent"] == id: expected_count += 1
		if release.get("metadata",[]).size() != expected_count: return
		for r in release.get("metadata",[]):
			if not records.has(r["key"]): return
			var actual: Dictionary = records[r["key"]].duplicate()
			actual.erase("rect")
			if actual != r: return
		if FileAccess.get_sha256(parents[id]["file"]) != release.get("files",{}).get("geometry.json",""): return
		releases[id] = release
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(parents[id]["file"]))
	var polygons: Dictionary = {}
	var line_grid: Dictionary = {}
	for r in d["regions"]: polygons[r["key"]] = r["polygons"]
	for i in range(d["lines"].size()):
		var line: Dictionary = d["lines"][i]
		line["rect"] = rect_for(line["bounds"])
		line["vector"] = points(line["points"])
		for cell in cells(line["rect"]):
			if not line_grid.has(cell): line_grid[cell] = []
			line_grid[cell].append(i)
	d["polygons"] = polygons
	d["line_grid"] = line_grid
	loaded[id] = d

func resident_resource_paths() -> Array:
	var paths: Array=[]
	for id in loaded:
		if compiled_parents.has(id):paths.append(compiled_parents[id])
	for path in batch_nodes:paths.append(path)
	if not selected_key.is_empty():paths.append(compiled_fills.get(selected_key+("_tilt" if elevation.enabled else "_flat"),""))
	return paths

func has_pending_batches() -> bool:
	for path in wanted_batches:
		if not batch_nodes.has(path) and not asset_stream.failed.has(path) and not asset_stream.denied.has(path): return true
	return false

func _plan_batches() -> void:
	if independent_geometry != null: return
	if asset_stream == null: return
	batch_style.set_shader_parameter("view_zoom",view_zoom)
	wanted_batches.clear()
	if visible and boundaries_enabled and view_zoom>=DETAIL:
		var inverse := get_global_transform_with_canvas().affine_inverse()
		var display := Rect2(inverse*Vector2.ZERO,Vector2.ZERO).expand(inverse*get_viewport_rect().size).grow(8.0/view_zoom)
		for id in asset_stream.manifest.get("boundary_batches",{}):
			for batch in asset_stream.manifest.boundary_batches[id]:
				if bool(batch.tilt)==elevation.enabled and rect_for(batch.bounds).intersects(display):wanted_batches[batch.path]=true
	for path in batch_nodes.keys():
		if not wanted_batches.has(path):
			batch_nodes[path].queue_free();batch_nodes.erase(path)

func _process(_delta: float) -> void:
	if cpu_jobs != null:
		for id in parent_jobs.keys():
			if not cpu_jobs.is_complete("parent:"+id):continue
			var result = cpu_jobs.take("parent:"+id)
			var worker = parent_jobs[id]
			if waiting_parents.has(id):
				if worker != null:
					if not result.data.is_empty():loaded[id]=result.data
					else:get_node("/root/MapDiagnostics").record("parent_prepare_failed", {"parent":id,"generation":generation})
					if not result.release.is_empty():releases[id]=result.release
				else:loaded[id]=result
				waiting_parents.erase(id)
			if worker != null:worker.free()
			parent_jobs.erase(id)
			queue_redraw()
	for id in waiting_parents.keys():load_parent(id)
	var start := Time.get_ticks_usec()
	for path in wanted_batches:
		if batch_nodes.has(path):continue
		var resource: Resource=asset_stream.fetch(path)
		if resource == null:continue
		var node := MeshInstance2D.new()
		node.mesh=resource.mesh;node.material=batch_style
		add_child(node);batch_nodes[path]=node
		if Time.get_ticks_usec()-start>1500:break

func _exit_tree() -> void:
	# Pool drains before detached worker objects are freed.
	for id in parent_jobs:
		var key: String="parent:"+id
		if cpu_jobs.jobs.has(key):
			cpu_jobs.drain(key)
		if parent_jobs[id]!=null:parent_jobs[id].free()
	for key in pick_workers:
		cpu_jobs.drain(key)
		pick_workers[key].free()

func nearby_lines(id: String, rect: Rect2) -> Array:
	var result: Dictionary = {}
	for cell in cells(rect):
		for i in loaded[id]["line_grid"].get(cell,[]):
			if loaded[id]["lines"][i]["rect"].intersects(rect): result[i] = true
	return result.keys()

func line_surface(line: Dictionary) -> PackedVector2Array:
	if line.has("surface_flat"):return line["surface_tilt"] if elevation.enabled else line["surface_flat"]
	if not projected.has(line["id"]): projected[line["id"]] = elevation.project_line(line["vector"])
	return projected[line["id"]]

func invalidate_surface() -> void:
	projected.clear()
	selected_mesh = null
	_plan_batches()
	queue_redraw()

func set_enabled(value: bool) -> void:
	visible = value
	var previous := view_rect
	view_rect = Rect2()
	update_view(previous,view_zoom)

func update_view(rect: Rect2, zoom_value: float) -> void:
	if rect == view_rect and is_equal_approx(view_zoom,zoom_value): return
	view_rect = rect
	view_zoom = zoom_value
	boundaries_enabled = zoom_value > 2.0
	generation += 1
	_plan_batches()
	active_keys = query(rect) if zoom_value >= DETAIL and visible and boundaries_enabled else []
	var wanted: Dictionary = {}
	for key in active_keys: wanted[records[key]["parent"]] = true
	for id in waiting_parents.keys():
		if not wanted.has(id):waiting_parents.erase(id)
	for id in wanted: load_parent(id)
	for id in loaded.keys():
		if not wanted.has(id):
			for line in loaded[id]["lines"]: projected.erase(line["id"])
			loaded.erase(id)
	queue_redraw()

func contains_point(key: String, p: Vector2) -> bool:
	load_parent(records[key]["parent"])
	if not loaded.has(records[key]["parent"]): return false
	for polygon in loaded[records[key]["parent"]]["polygons"][key]:
		if not Geometry2D.is_point_in_polygon(p,points(polygon[0])): continue
		var in_hole := false
		for i in range(1,polygon.size()):
			if Geometry2D.is_point_in_polygon(p,points(polygon[i])): in_hole = true
		if not in_hole: return true
	return false

func pick(p: Vector2, tolerance_px := 6.0) -> Array:
	var radius := tolerance_px/view_zoom
	# Conservative source-space bound includes the full permitted relief shift;
	# the final tolerance is still measured against projected lines in screen pixels.
	var source_radius: float = radius*2.0+4000.0*elevation.height_scale if elevation.enabled else radius
	var search_rect := Rect2(p,Vector2.ZERO).grow(source_radius+0.01)
	var candidates := query(search_rect)
	var result: Dictionary = {}
	var seen: Dictionary = {}
	var display: Vector2 = elevation.project(p)
	for key in candidates:
		var pid: String = records[key]["parent"]
		load_parent(pid)
		if not loaded.has(pid): continue
		if contains_point(key,p): result[key] = true
		if seen.has(pid): continue
		seen[pid] = true
		for i in nearby_lines(pid,search_rect):
			var line: Dictionary = loaded[pid]["lines"][i]
			var vector := line_surface(line)
			for n in range(vector.size()-1):
				if Geometry2D.get_closest_point_to_segment(display,vector[n],vector[n+1]).distance_to(display)<=radius:
					for owner in line["owners"]: result[owner] = true
					break
	# Also include districts across a parent boundary by polygon ring tolerance.
	for key in candidates:
		if result.has(key): continue
		if not loaded.has(records[key]["parent"]): continue
		for polygon in loaded[records[key]["parent"]]["polygons"][key]:
			for ring in polygon:
				var line: PackedVector2Array = elevation.project_line(points(ring))
				for i in range(line.size()-1):
					if Geometry2D.get_closest_point_to_segment(display,line[i],line[i+1]).distance_to(display)<=radius:
						result[key] = true
						break
	var keys: Array = []
	for key in result:
		if records.has(key): keys.append(key)
	keys.sort()
	if keys.size() <= 1: return keys
	# Border tolerance can include both neighbours. Always resolve that ambiguity
	# to one district, preferring the district whose label is closest to the click.
	var selected: String = keys[0]
	var selected_distance: float = INF
	for key in keys:
		var label: Array = records[key]["label"]
		var distance: float = elevation.project(Vector2(label[0],label[1])).distance_squared_to(display)
		if distance < selected_distance:
			selected = key
			selected_distance = distance
	return [selected]

func select_key(key: String) -> void:
	if not key.is_empty() and not review_mode:
		load_parent(records[key]["parent"])
		if not loaded.has(records[key]["parent"]): return
	selected_key = key
	selected_mesh = null
	queue_redraw()

func fill_mesh() -> ArrayMesh:
	if independent_geometry != null: return null # Selection uses the independent outline.
	if selected_mesh != null: return selected_mesh
	if selected_key.is_empty():return null
	var compiled_key:=selected_key+("_tilt" if elevation.enabled else "_flat")
	if compiled_fills.has(compiled_key):
		if asset_stream.failed.has(compiled_fills[compiled_key]):return null
		else:
			var chunk:Resource=asset_stream.fetch(compiled_fills[compiled_key])
			if chunk==null:return null
			selected_mesh=chunk.mesh
			return selected_mesh
	if not review_mode:
		var r: Dictionary = records[selected_key]
		var file: String = r["mesh_file"]
		if not releases.has(r["parent"]): load_parent(r["parent"])
		if not releases.has(r["parent"]): return null
		if FileAccess.get_sha256(file) != releases[r["parent"]]["files"].get(file.get_file(),""): return null
	var f := FileAccess.open(records[selected_key]["mesh_file"],FileAccess.READ)
	if f == null: return null
	var vertices := PackedVector2Array()
	while f.get_position()<f.get_length(): vertices.append(elevation.project(Vector2(f.get_float(),f.get_float())))
	if vertices.is_empty(): return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	selected_mesh = ArrayMesh.new()
	selected_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return selected_mesh

func append_dashes(line: PackedVector2Array, segments: PackedVector2Array) -> void:
	var phase := 0.0
	var period := 10.0/view_zoom
	var dash := 6.0/view_zoom
	for i in range(line.size()-1):
		var length := line[i].distance_to(line[i+1])
		if length < 0.000001: continue
		var along := 0.0
		# A tiny remaining segment cannot advance the old loop: resetting phase
		# leaves length-along unchanged forever. Consume it and preserve phase.
		while length-along > 0.000001:
			var drawn := phase<dash
			var step := minf(length-along,(dash if drawn else period)-phase)
			if step < 0.000001:
				phase = dash if drawn else 0.0
				continue
			if drawn:
				segments.append(line[i].lerp(line[i+1],along/length))
				segments.append(line[i].lerp(line[i+1],(along+step)/length))
			along += step
			phase = fmod(phase+step,period)
		phase = fmod(phase+maxf(0.0,length-along),period)

func _draw_content() -> void:
	draw_line_count = 0
	if boundary_mesh!=null:boundary_mesh.visible=false
	if not initialized: return
	if view_zoom >= DETAIL and boundaries_enabled:
		# Production borders are bounded baked chunks; zoom changes only uniforms.
		if independent_geometry != null:
			pass # Independent outlines are drawn above the political layer.
		elif asset_stream == null or asset_stream.manifest.get("boundary_batches",{}).is_empty():
			var boundary_segments := PackedVector2Array()
			for id in loaded:
				for i in nearby_lines(id,view_rect):
					append_dashes(line_surface(loaded[id]["lines"][i]),boundary_segments)
					draw_line_count += 1
			if not boundary_segments.is_empty():boundary_mesh.configure(boundary_segments,0.9,Color("#746347"),view_zoom)
		else:
			draw_line_count = batch_nodes.size()
func pick_async(p: Vector2) -> Array:
	if cpu_jobs == null: return pick(p)
	var worker = get_script().new()
	worker.records=records;worker.parents=parents;worker.grid=grid
	worker.independent_geometry=independent_geometry
	worker.loaded=loaded.duplicate();worker.review_mode=review_mode
	worker.elevation=elevation.snapshot();worker.view_zoom=view_zoom
	var key := "pick:"+str(worker.get_instance_id())
	while not cpu_jobs.submit(key,worker.pick.bind(p),8*1024*1024,generation):
		await get_tree().process_frame
	pick_workers[key]=worker
	while not cpu_jobs.is_complete(key):await get_tree().process_frame
	var result: Array=cpu_jobs.take(key)
	pick_workers.erase(key)
	worker.free()
	return result

var last_slow_draw_ms := -1000
func _draw() -> void:
	var start := Time.get_ticks_usec()
	_draw_content()
	var duration := Time.get_ticks_usec()-start
	if duration>10000 and Time.get_ticks_msec()-last_slow_draw_ms>1000:
		last_slow_draw_ms=Time.get_ticks_msec()
		get_node("/root/MapDiagnostics").record("slow_draw", {"layer":get_script().resource_path,"duration_us":duration})
