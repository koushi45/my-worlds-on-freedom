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
	var partial := FileAccess.open(output,FileAccess.WRITE)
	partial.store_string(JSON.stringify({"engine":Engine.get_version_info(),"pid":OS.get_process_id(),"rows":rows,"events":events,"complete":false},"  "))
	partial.close()
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

func run() -> void:
	root.title = "Resource investigation (QA)"
	Engine.max_fps = 60
	root.size = Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	change_scene_to_file("res://scenes/start/start.tscn")
	await process_frame
	await process_frame
	await measure("title")
	current_scene.show_houses()
	await measure("house_selection")
	var session := root.get_node("GameSession")
	print("BENCH800_PHASE loading")
	var begin := Time.get_ticks_usec()
	session.new_game("oda_nobuhide")
	await process_frame
	await process_frame
	main = current_scene
	while not main.initialized: await process_frame
	main.game_clock.paused = true
	if not await settle(): return
	events.append({"name":"new_game_load","wall_ms":float(Time.get_ticks_usec()-begin)/1000.0})
	main.camera.position = Vector2(4480,5504)
	main.set_map_zoom(1.0)
	if not await settle(): return
	await measure("map_100_idle")
	main.set_map_zoom(8.0)
	main.map_view.manual_angle = 15.0
	if not await settle(): return
	await measure("map_800_idle")
	await measure("map_800_pan","pan")
	main.camera.position = Vector2(4480,5504)
	if not await settle(): return
	await measure("map_800_orbit","orbit")
	main.map_view.yaw = 0.0
	if not await settle(): return
	main.bgm_player.stop()
	await measure("map_800_no_bgm")
	main.bgm_player.play()
	main.game_clock.set_speed(8)
	main.game_clock.paused = false
	await measure("map_800_time_x8")
	main.game_clock.paused = true
	for entry in [["menu", "toggle"],["dictionary","show_dictionary"],["retainers","show_retainers"],["technology","show_technology"],["diplomacy","show_diplomacy"],["options","show_options"]]:
		main.game_menu._close_all()
		main.game_menu._open_menu(false)
		begin = Time.get_ticks_usec()
		if entry[1] != "toggle": main.game_menu.call(entry[1])
		events.append({"name":entry[0]+"_open","cpu_call_ms":float(Time.get_ticks_usec()-begin)/1000.0})
		await measure(entry[0])
	main.game_menu._close_all()
	await measure("map_after_panels")
	begin = Time.get_ticks_usec()
	var saved: Dictionary = session.capture(main)
	var captured := Time.get_ticks_usec()
	var encoded := JSON.stringify(saved)
	var serialized := Time.get_ticks_usec()
	var decoded: Variant = JSON.parse_string(encoded)
	var parsed := Time.get_ticks_usec()
	var valid: bool = session.validate(decoded)
	events.append({"name":"save_in_memory","capture_ms":float(captured-begin)/1000.0,"serialize_ms":float(serialized-captured)/1000.0,"parse_ms":float(parsed-serialized)/1000.0,"validate_ms":float(Time.get_ticks_usec()-parsed)/1000.0,"json_bytes":encoded.to_utf8_buffer().size(),"valid":valid})
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"pid":OS.get_process_id(),"fps_limit":60,"viewport":[1920,1080],"rows":rows,"events":events,"complete":true},"  "))
	file.close()
	print("FEATURE_PROBE_COMPLETE")
	quit(0)
