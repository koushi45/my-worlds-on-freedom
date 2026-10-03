extends SceneTree
## In-memory profiling only; packed scripts and production files remain unchanged.
var main: Node
var output := ""
var variants: Array[String] = ["baseline"]
var fps_limit := 60
var seconds := 10.0
var instrument := false
var rows: Array = []
var collector: Node
var scripts_kept: Array[Script] = []
var shaders: Dictionary = {}
var center := Vector2(4480,5504)

class Collector extends Node:
	var enabled := false
	var stack: Array = []
	var totals: Dictionary = {}
	var frame: Dictionary = {}
	var worker_us: Array = []
	var window_begin := 0
	func record_worker(started: int, ended: int) -> void:
		if enabled and started>=window_begin: worker_us.append(ended-started)
	func begin(label: String) -> void:
		if enabled: stack.append({"label":label,"start":Time.get_ticks_usec(),"children":0})
	func end() -> void:
		if not enabled: return
		var ended := Time.get_ticks_usec()
		var item: Dictionary = stack.pop_back()
		var us: int = ended-int(item.start)
		if not stack.is_empty(): stack[-1].children += us
		var label: String = item.label
		if not totals.has(label): totals[label] = {"calls":0,"inclusive_us":0,"self_us":0,"max_call_us":0}
		var row: Dictionary = totals[label]
		row.calls += 1; row.inclusive_us += us; row.self_us += us-int(item.children)
		row.max_call_us = maxi(row.max_call_us,us)
		frame[label] = frame.get(label,0)+us-int(item.children)
	func reset() -> void:
		totals.clear(); frame.clear(); stack.clear(); worker_us.clear()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--variants="): variants.assign(arg.trim_prefix("--variants=").split(","))
		if arg.begins_with("--fps-limit="): fps_limit = int(arg.trim_prefix("--fps-limit="))
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		if arg == "--instrument": instrument = true
	call_deferred("run")

func instrument_script(path: String, methods: Dictionary, object: Object) -> bool:
	var script: GDScript = object.get_script()
	var original := script.source_code
	if original.is_empty(): original = FileAccess.get_file_as_string(path)
	if not original.begins_with("extends"):
		printerr("FAIL: no script source: ",path); return false
	var changed := original
	for method in methods:
		var signature := ""
		for line in original.split("\n"):
			if line.begins_with("func "+method+"("): signature = line; break
		if signature.is_empty(): printerr("FAIL: missing method ",path," ",method); return false
		changed = changed.replace("func "+method+"(","func _qa_original_"+method+"(")
		var label: String = path.get_file().trim_suffix(".gd")+"."+method
		if path.ends_with("water_layer.gd"): label = "water_layer:"+str(object.get("kind"))+"."+method
		var body: String = "\n"+signature+"\n\tvar qa_collector = Engine.get_main_loop().root.get_node(\"ProcessingProfiler\")\n\tqa_collector.begin(\""+label+"\")\n"
		if signature.contains("-> void"):
			body += "\t_qa_original_"+method+"("+methods[method]+")\n\tqa_collector.end()\n"
		else:
			body += "\tvar qa_result = _qa_original_"+method+"("+methods[method]+")\n\tqa_collector.end()\n\treturn qa_result\n"
		changed += body
	if path.ends_with("editable_road_layer.gd"):
		changed = changed.replace("\tfor cell in network.cells:","\tvar qa_road_collector = Engine.get_main_loop().root.get_node(\"ProcessingProfiler\")\n\tqa_road_collector.begin(\"editable_road_layer.scan_and_project\")\n\tfor cell in network.cells:")
		changed = changed.replace("\toutline.configure(segments,","\tqa_road_collector.end()\n\toutline.configure(segments,")
	if path.ends_with("map_cpu_jobs.gd"):
		changed = changed.replace("\tthreads[work.thread_id] = true","\tthreads[work.thread_id] = true\n\tEngine.get_main_loop().root.get_node(\"ProcessingProfiler\").record_worker(work.started,work.ended)")
	if path.ends_with("map_screen_markers.gd"):
		changed += "\nvar qa_width_hits := 0\nvar qa_width_misses := 0\nvar qa_width_miss_us := 0\nvar qa_width_slow: Array = []\n"
		changed = changed.replace("    if not widths.has(key): widths[key] = font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x","    if not widths.has(key):\n        var qa_font_start := Time.get_ticks_usec()\n        widths[key] = font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x\n        var qa_font_us := Time.get_ticks_usec()-qa_font_start\n        qa_width_misses += 1; qa_width_miss_us += qa_font_us\n        if qa_font_us>1000: qa_width_slow.append({\"text\":name,\"us\":qa_font_us})\n    else:\n        qa_width_hits += 1")
	if path.ends_with("water_layer.gd"):
		changed += "\nvar qa_water_hide_us := 0\n"
		changed = changed.replace("    for node in line_nodes.values():node.hide()","    var qa_water_start := Time.get_ticks_usec()\n    for node in line_nodes.values():node.hide()\n    qa_water_hide_us += Time.get_ticks_usec()-qa_water_start")
	var replacement := GDScript.new()
	replacement.source_code = changed.replace("\t","    ")
	if replacement.reload() != OK: printerr("FAIL: instrument reload ",path); return false
	var saved := {}
	for property in object.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: saved[property.name] = object.get(property.name)
	object.set_script(replacement)
	for key in saved: object.set(key,saved[key])
	scripts_kept.append(replacement)
	return true

func install_profiling() -> bool:
	var objects := [main,main.map_view,main.map_view.markers,main.shared_road_layer,main.hex_tile_layer,main.district_office_layer,main.district_layer,main.asset_stream,main.map_view.terrain_materials,main.map_view.terrain_chunks,main.developer_tools.road_layer,main.cpu_jobs]
	var plan := {
		"res://scripts/main/main_map.gd":{"_process":"delta","_refresh_visible_tiles":"","_pump_tiles":"","_plan_prefetch":"rect","_retire_tiles":"","_desired_tiles":"rect"},
		"res://scripts/map/map_view_3d.gd":{"advance":"delta","sync":"force,pose_only","_update_fine":""},
		"res://scripts/map/map_screen_markers.gd":{"_draw":"","_crest":"house,screen,size","text_width":"font,name,size"},
		"res://scripts/map/shared_road_layer.gd":{"_draw_content":""},
		"res://scripts/map/hex_tile_layer.gd":{"_draw_content":"","_draw_mesh_chunks":"alpha"},
		"res://scripts/map/district_office_layer.gd":{"_draw":""},
		"res://scripts/map/district_layer.gd":{"_draw":""},
		"res://scripts/map/map_asset_stream.gd":{"_advance_stream":""},
		"res://scripts/map/terrain_material_set.gd":{"update":"zoom,target_zoom"},
		"res://scripts/map/terrain_chunk_set.gd":{"update_near":"","update_visibility":"force"},
		"res://scripts/map/editable_road_layer.gd":{"_draw":""},
		"res://scripts/map/map_cpu_jobs.gd":{"drain":"key"}
	}
	var index := 0
	for path in plan:
		if not instrument_script(path,plan[path],objects[index]): return false
		index += 1
	if not main.has_method("_qa_original__process"): printerr("FAIL: profiler not attached"); return false
	if not instrument_other_map_nodes(root): return false
	return true

func instrument_other_map_nodes(node: Node) -> bool:
	var script: Script = node.get_script()
	if script != null:
		var path: String = script.resource_path
		if path.begins_with("res://scripts/map/") and not path.ends_with("map_diagnostics.gd"):
			var source: String = script.source_code
			if source.is_empty(): source = FileAccess.get_file_as_string(path)
			var methods := {}
			for line in source.split("\n"):
				if line.begins_with("func _draw()") and not node.has_method("_qa_original__draw"): methods["_draw"] = ""
				if line.begins_with("func _process(") and not node.has_method("_qa_original__process"):
					methods["_process"] = line.get_slice("(",1).get_slice(":",0).strip_edges()
			if not methods.is_empty():
				if not instrument_script(path,methods,node): return false
	for child in node.get_children():
		if not instrument_other_map_nodes(child): return false
	return true

func settle() -> bool:
	print("BENCH800_PHASE loading")
	var deadline := Time.get_ticks_msec()+60000
	var stable := 0
	while Time.get_ticks_msec()<deadline:
		await process_frame
		stable = stable+1 if main.initialized and not main.has_pending_map_work() else 0
		if stable>=30: return true
	printerr("FAIL: settle timeout"); return false

func shader_variant(kind: String) -> Shader:
	if shaders.has(kind): return shaders[kind]
	var source := FileAccess.get_file_as_string("res://scripts/map/map_surface_3d.gdshader")
	if kind=="simple_surface":
		source = source.substr(0,source.find("    float distance_to_focus"))+"    ALBEDO = colour;\n    ROUGHNESS = 1.0;\n}\n"
	if kind=="no_detail_normal":
		var begin := source.find("    vec3 normal_colour")
		var end := source.find("    float haze",begin)
		source = source.substr(0,begin)+source.substr(end)
	if kind=="no_detail_albedo":
		var begin := source.find("    vec3 grass =")
		var end := source.find("    vec3 normal_colour",begin)
		source = source.substr(0,begin)+source.substr(end)
	if kind=="constant_surface":
		source = source.substr(0,source.find("void fragment()"))+"void fragment() { vec2 world = map_position.xz + vec2(4096.0); if (fuji_active && !is_fuji && all(greaterThan(world,fuji_rect.xy)) && all(lessThan(world,fuji_rect.zw))) discard; if (fine_active && !is_fine && all(greaterThan(world,fine_rect.xy)) && all(lessThan(world,fine_rect.zw))) discard; ALBEDO = vec3(0.4,0.5,0.3); ROUGHNESS = 1.0; }\n"
	var shader := Shader.new(); shader.code = source; shaders[kind] = shader
	return shader

func set_variant(kind: String) -> void:
	var view: Node = main.map_view
	for key in ["probe_no_marker_text","probe_no_crests","probe_no_hex_lines","probe_no_hex","probe_no_occlusion","probe_freeze_near"]: view.set_meta(key,false)
	view.set_meta("probe_atlas_scale",1.0)
	main.shared_road_layer.set_meta("probe_no_roads",false)
	main.developer_tools.road_layer.show()
	main.river_layer.show(); main.lake_layer.show(); main.political_layer.show(); main.district_layer.show(); main.territory_borders.show(); main.district_office_layer.show()
	view.source_root.show(); view.markers.show(); view.surface.show()
	view.view_camera.cull_mask = 1048575
	view.sun.shadow_enabled = true
	view.source_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for material in [view.surface_material,view.fine_material,view.fuji_material]: material.shader = shader_variant("baseline")
	if kind in ["simple_surface","no_detail_normal","no_detail_albedo","constant_surface"]:
		for material in [view.surface_material,view.fine_material,view.fuji_material]: material.shader = shader_variant(kind)
	if kind=="no_markers": view.markers.hide()
	if kind=="no_crests": view.set_meta("probe_no_crests",true)
	if kind=="no_text": view.set_meta("probe_no_marker_text",true)
	if kind=="no_occlusion": view.set_meta("probe_no_occlusion",true)
	if kind=="no_hex_lines": view.set_meta("probe_no_hex_lines",true)
	if kind=="no_roads": main.shared_road_layer.set_meta("probe_no_roads",true)
	if kind=="no_actual_roads": main.developer_tools.road_layer.hide()
	if kind=="no_hydro": main.river_layer.hide(); main.lake_layer.hide()
	if kind=="no_borders": main.political_layer.hide(); main.district_layer.hide(); main.territory_borders.hide()
	if kind=="no_office_tiles": main.district_office_layer.hide()
	if kind=="no_shadows": view.sun.shadow_enabled = false
	if kind=="atlas_half": view.set_meta("probe_atlas_scale",0.5)
	if kind=="no_source_layers": view.source_root.hide()
	if kind=="freeze_atlas": view.source_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if kind=="freeze_near" or kind=="no_near": view.set_meta("probe_freeze_near",true)
	if kind=="no_near":
		view.fine_surface.hide(); view.fuji_surface.hide()
		for material in [view.surface_material,view.fine_material,view.fuji_material]:
			material.set_shader_parameter("fine_active",false); material.set_shader_parameter("fuji_active",false)
	if kind=="no_3d": view.view_camera.cull_mask = 0
	view.fine_shader_state = []; view.last_state = []
	view.sync(true)
	main.hex_tile_layer.queue_redraw(); main.shared_road_layer.queue_redraw(); view.markers.invalidate()

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"mean":0.0,"p95":0.0,"max":0.0}
	var total := 0.0
	for value in values: total += float(value)
	values.sort()
	return {"mean":total/values.size(),"p95":values[int(values.size()*0.95)],"max":values[-1]}

func measure(variant: String, mode: String) -> void:
	main.camera.position = center; main.map_view.yaw = 0.0
	if not await settle(): quit(1); return
	print("BENCH800_PHASE warmup")
	await create_timer(1.5,true).timeout
	collector.reset(); collector.enabled = instrument
	var font_before := {}
	var water_before := {}
	if instrument:
		font_before = {"hits":main.map_view.markers.qa_width_hits,"misses":main.map_view.markers.qa_width_misses,"us":main.map_view.markers.qa_width_miss_us,"slow":main.map_view.markers.qa_width_slow.size()}
		for water in [main.river_layer,main.lake_layer]:
			if water.get("qa_water_hide_us")!=null: water_before[water.kind] = water.qa_water_hide_us
	var begin := Time.get_ticks_usec()
	collector.window_begin = begin
	var previous := begin
	var counts := {"marker":main.map_view.markers.total_draw_us,"occlusion":main.map_view.marker_occlusion_us,"geometry":main.map_view.geometry_builds,"near_builds":main.map_view.terrain_chunks.near_builds,"far_loads":main.map_view.terrain_chunks.far_loads}
	var samples := {"frame":[],"main_update":[],"source_cpu":[],"source_gpu":[],"root_cpu":[],"root_gpu":[],"render_setup_cpu":[],"draw_calls":[],"primitives":[],"probe_sampling_wall":[]}
	var function_frames: Dictionary = {}
	print("BENCH800_PHASE ",variant," ",mode)
	while Time.get_ticks_usec()-begin < int(seconds*1000000.0):
		var t := float(Time.get_ticks_usec()-begin)/10000000.0*TAU
		if mode=="pan": main.camera.position = center+Vector2(cos(t),sin(t))*160.0
		if mode=="orbit": main.map_view.yaw = rad_to_deg(t)
		await process_frame
		var now := Time.get_ticks_usec()
		samples.frame.append(float(now-previous)/1000.0); previous = now
		var qa_sample_start := Time.get_ticks_usec()
		samples.main_update.append(float(main.main_update_us)/1000.0)
		samples.source_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(main.map_view.source_view.get_viewport_rid()))
		samples.source_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(main.map_view.source_view.get_viewport_rid()))
		samples.root_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		samples.root_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		samples.render_setup_cpu.append(RenderingServer.get_frame_setup_time_cpu())
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		for label in collector.frame:
			if not function_frames.has(label): function_frames[label] = []
			function_frames[label].append(float(collector.frame[label])/1000.0)
		collector.frame.clear()
		samples.probe_sampling_wall.append(float(Time.get_ticks_usec()-qa_sample_start)/1000.0)
	collector.enabled = false
	var duration := float(Time.get_ticks_usec()-begin)/1000000.0
	var frame_count: int = samples.frame.size()
	var row := {"variant":variant,"mode":mode,"seconds":duration,"begin_ticks_ms":begin/1000,"end_ticks_ms":Time.get_ticks_msec(),"frames":frame_count,"fps":frame_count/duration,"instrumented":instrument,"metrics":{},"functions":{},"marker_ms_per_frame":float(main.map_view.markers.total_draw_us-counts.marker)/1000.0/frame_count,"occlusion_ms_per_frame":float(main.map_view.marker_occlusion_us-counts.occlusion)/1000.0/frame_count,"geometry_builds":main.map_view.geometry_builds-counts.geometry,"near_builds":main.map_view.terrain_chunks.near_builds-counts.near_builds,"far_loads":main.map_view.terrain_chunks.far_loads-counts.far_loads,"atlas_size":[main.map_view.source_view.size.x,main.map_view.source_view.size.y],"source_enabled":variant!="freeze_atlas"}
	for key in samples: row.metrics[key] = stats(samples[key])
	row["worker_jobs"] = collector.worker_us.size()
	row["worker_job_wall_us"] = stats(collector.worker_us)
	var worker_sum := 0
	for us in collector.worker_us: worker_sum += int(us)
	row["worker_wall_ms_per_frame"] = float(worker_sum)/1000.0/frame_count
	row["road_cells"] = main.developer_tools.network.cells.size()
	if instrument:
		row["font_width_cache"] = {"hits":main.map_view.markers.qa_width_hits-font_before.hits,"misses":main.map_view.markers.qa_width_misses-font_before.misses,"miss_us":main.map_view.markers.qa_width_miss_us-font_before.us,"slow":main.map_view.markers.qa_width_slow.slice(font_before.slow)}
		row["water_layers"] = []
		for water in [main.river_layer,main.lake_layer]:
			if water_before.has(water.kind): row.water_layers.append({"kind":water.kind,"records":water.records.size(),"retained_line_nodes":water.line_nodes.size(),"visible_records_at_end":water.draw_count,"hide_cpu_ms_per_frame":float(water.qa_water_hide_us-water_before[water.kind])/1000.0/frame_count})
	for label in collector.totals:
		var data: Dictionary = collector.totals[label].duplicate()
		data["self_ms_per_frame"] = float(data.self_us)/1000.0/frame_count
		data["inclusive_ms_per_frame"] = float(data.inclusive_us)/1000.0/frame_count
		data["active_frame_self_ms"] = stats(function_frames.get(label,[]))
		row.functions[label] = data
	rows.append(row)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"pid":OS.get_process_id(),"fps_limit":fps_limit,"engine":Engine.get_version_info(),"instrumented":instrument},"  ")); file.close()
	print("PROCESSING_RESULT ",JSON.stringify(row))

func run() -> void:
	root.title = "800% processing investigation (QA)"
	collector = Collector.new(); collector.name = "ProcessingProfiler"; root.add_child(collector)
	Engine.max_fps = fps_limit
	root.size = Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.get_node("GameSession").new_game("oda_nobuhide")
	await process_frame; await process_frame
	main = current_scene
	while not main.initialized: await process_frame
	if instrument:
		if not await settle(): quit(1); return
		if not install_profiling(): quit(1); return
	main.game_clock.paused = true
	main.set_map_zoom(8.0); main.map_view.manual_angle = 15.0
	RenderingServer.viewport_set_measure_render_time(main.map_view.source_view.get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	if not await settle(): quit(1); return
	for variant in variants:
		set_variant(variant)
		await measure(variant,"pan")
		await measure(variant,"orbit")
	print("PROCESSING_COMPLETE")
	quit(0)
