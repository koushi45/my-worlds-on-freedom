extends SceneTree
## External QA harness: does not change production scripts or user saves/settings.
var main: Node
var rows: Array = []
var events: Array = []
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func measure(label: String, mode: String = "idle") -> void:
	print("BENCH800_PHASE warmup")
	await create_timer(2.5, true).timeout
	print("BENCH800_PHASE ", label)
	var begin := Time.get_ticks_usec()
	var previous := begin
	var times: Array[float] = []
	var marker_us := 0
	var occlusion_us := 0
	if is_instance_valid(main):
		marker_us = main.map_view.markers.total_draw_us
		occlusion_us = main.map_view.marker_occlusion_us
	while Time.get_ticks_usec()-begin < 10000000:
		if mode == "pan":
			var t := float(Time.get_ticks_usec()-begin)/10000000.0*TAU
			main.camera.position = Vector2(4480,5504)+Vector2(cos(t),sin(t))*160.0
		if mode == "orbit": main.map_view.yaw = float(Time.get_ticks_usec()-begin)/10000000.0*360.0
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now-previous)/1000.0)
		previous = now
	var elapsed := float(Time.get_ticks_usec()-begin)/1000000.0
	times.sort()
	var row := {"phase":label,"seconds":elapsed,"frames":times.size(),"fps":times.size()/elapsed,"p95_ms":times[int(times.size()*0.95)],"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	if is_instance_valid(main):
		row["marker_cpu_ms_per_frame"] = float(main.map_view.markers.total_draw_us-marker_us)/1000.0/times.size()
		row["occlusion_cpu_ms_per_frame"] = float(main.map_view.marker_occlusion_us-occlusion_us)/1000.0/times.size()
		row["map_cache_bytes"] = main.asset_stream.resident_bytes
		row["elapsed_days"] = main.game_clock.elapsed_days
	rows.append(row)
	print("FEATURE_RESULT ",JSON.stringify(row))

func settle() -> bool:
	print("BENCH800_PHASE loading")
	var deadline := Time.get_ticks_msec()+60000
	var stable := 0
	while Time.get_ticks_msec()<deadline:
		await process_frame
		stable = stable+1 if not main.has_pending_map_work() and main.map_view.fine_job<0 and main.map_view.terrain_materials.waiting.is_empty() else 0
		if stable>=30: return true
	printerr("FAIL: settle timeout")
	quit(1)
	return false

func timed_day(callback: Callable, label: String, y: int, m: int, d: int) -> void:
	var begin := Time.get_ticks_usec()
	callback.call(y,m,d)
	daily_times[label].append(float(Time.get_ticks_usec()-begin)/1000.0)

var daily_times: Dictionary = {}

func run() -> void:
	root.title = "Resource investigation (QA)"
	Engine.max_fps = 60
	root.size = Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var session := root.get_node("GameSession")
	session.new_game("oda_nobuhide")
	await process_frame
	await process_frame
	main = current_scene
	while not main.initialized: await process_frame
	main.game_clock.paused = true
	main.camera.position = Vector2(4480,5504)
	main.set_map_zoom(8.0)
	main.map_view.manual_angle = 15.0
	if not await settle(): return
	await measure("baseline_pan","pan")
	main.map_view.markers.hide()
	await measure("no_markers_pan","pan")
	main.map_view.markers.show()
	main.hex_tile_layer.hide()
	await measure("no_hex_group_pan","pan")
	main.hex_tile_layer.show()
	main.shared_road_layer.set_meta("probe_no_roads",true)
	main.shared_road_layer.queue_redraw()
	await measure("no_roads_pan","pan")
	main.shared_road_layer.set_meta("probe_no_roads",false)
	main.shared_road_layer.queue_redraw()
	main.map_view.sun.shadow_enabled = false
	await measure("no_shadows_pan","pan")
	main.map_view.sun.shadow_enabled = true
	await measure("baseline_repeat_pan","pan")
	main.camera.position = Vector2(4480,5504)
	if not await settle(): return
	for id in main.governance_registry.districts:
		if main.governance_registry.districts[id].house_id==session.player_house:
			main.district_info.set_district(id)
			main.district_info.panel.show()
			break
	await measure("district_info")
	main.district_info.hide_info()
	main.developer_tools.open()
	main.developer_tools.set_contour_mode(true)
	if not await settle(): return
	await measure("contour_map")
	main.developer_tools.close()
	for id in main.governance_registry.districts:
		var district: Dictionary = main.governance_registry.districts[id]
		if district.house_id != session.player_house: continue
		var officers: Array = main.army_campaign.available_officers(id)
		if officers.is_empty() or main.district_actions.sortie_available(district)<400: continue
		main.camera.position = main.army_campaign.node_point("district:"+id)
		if not await settle(): return
		await measure("army_home_idle")
		var begin := Time.get_ticks_usec()
		var unit: String = main.army_campaign.dispatch(id,[officers[0]],25,false,false)
		events.append({"name":"dispatch_one_unit","cpu_call_ms":float(Time.get_ticks_usec()-begin)/1000.0,"unit":unit,"error":main.army_campaign.last_error})
		main.game_clock.set_speed(8)
		main.game_clock.paused = false
		await measure("army_one_time_x8")
		main.game_clock.paused = true
		break
	print("BENCH800_PHASE daily_cpu")
	for connection in main.game_clock.day_advanced.get_connections():
		var original: Callable = connection.callable
		var label := str(original.get_object().get_script().resource_path)
		daily_times[label] = []
		main.game_clock.day_advanced.disconnect(original)
		main.game_clock.day_advanced.connect(func(y,m,d): timed_day(original,label,y,m,d))
	main.game_clock.set_process(false)
	main.game_clock.paused = false
	main.game_clock.set_speed(1)
	for i in 365:
		main.game_clock.advance_real_seconds(1.0)
		await process_frame
	for label in daily_times:
		var values: Array = daily_times[label]
		values.sort()
		var total := 0.0
		for ms in values: total += ms
		events.append({"name":label,"days":values.size(),"mean_ms":total/values.size(),"p95_ms":values[int(values.size()*0.95)],"max_ms":values[-1]})
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"pid":OS.get_process_id(),"rows":rows,"events":events},"  "))
	file.close()
	print("FEATURE_PROBE_COMPLETE")
	quit(0)
