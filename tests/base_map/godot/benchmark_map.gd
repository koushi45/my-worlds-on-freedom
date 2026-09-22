extends SceneTree
var frames_ms: Array = []
var stages: Array = []
var main: Node
var previous := 0
var output := "res://builds/performance/baseline.json"
var cycles := 3

func sample(label: String, action_ms: float) -> void:
	var values: Array = []
	var settled_frames:=0
	var sample_start:=Time.get_ticks_msec()
	while settled_frames<30 and Time.get_ticks_msec()-sample_start<20000:
		await process_frame
		if not main.has_method("has_pending_map_work") or not main.has_pending_map_work():settled_frames+=1
		var now := Time.get_ticks_usec()
		if previous>0:
			var elapsed := (now-previous)/1000.0
			values.append(elapsed)
			frames_ms.append(elapsed)
		previous=now
	stages.append({"stage":label,"action_ms":action_ms,"ready_ms":Time.get_ticks_msec()-sample_start,"frames_ms":values,
		"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"render_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects":Performance.get_monitor(Performance.OBJECT_COUNT),
		"tiles":main.loaded_tiles.size(),"district_parents":main.district_layer.loaded.size()})

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--cycles="): cycles=maxi(1,int(arg.trim_prefix("--cycles=")))
	Engine.max_fps=60
	var start := Time.get_ticks_usec()
	main=load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await sample("startup",(Time.get_ticks_usec()-start)/1000.0)
	var points := [Vector2(3460,5880),Vector2(4750,5350),Vector2(5500,4100),Vector2(1920,6750)]
	for cycle in range(cycles):
		for i in range(points.size()):
			start=Time.get_ticks_usec()
			main.set_oblique(cycle%2==1)
			main.set_map_zoom(4.0 if i%2==0 else 1.0)
			main.camera.position=main.elevation.project(points[i])
			main._refresh_visible_tiles()
			await sample("move_%d_%d" % [cycle,i],(Time.get_ticks_usec()-start)/1000.0)
		start=Time.get_ticks_usec()
		var key: String="izumi/candidate-district-candidate-g04003"
		main.district_panel.show_browser()
		main.district_panel.select_index(main.district_panel.matches.find(key))
		main.district_panel.focus_current()
		await sample("select_%d" % cycle,(Time.get_ticks_usec()-start)/1000.0)
	await sample("idle",0.0)
	var sorted:=frames_ms.duplicate()
	sorted.sort()
	var stalls:=0
	for ms in sorted:
		if ms>100.0: stalls+=1
	var result={"stages":stages,"p50_ms":sorted[int(sorted.size()*0.50)],"p95_ms":sorted[int(sorted.size()*0.95)],
		"p99_ms":sorted[int(sorted.size()*0.99)],"maximum_ms":sorted[-1],"frames_over_100ms":stalls,
		"frames":sorted.size(),"note":"30 settled frames per stage; frame times include synchronous actions; GPU desktop benchmark"}
	var f:=FileAccess.open(output,FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "))
	print("MAP BENCHMARK: ",output," p99=",result["p99_ms"]," max=",result["maximum_ms"])
	quit(0)
