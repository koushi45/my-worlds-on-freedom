extends SceneTree
const Wait=preload("res://tests/base_map/godot/wait_map.gd")
var main: Node
var samples: Array = []
var frames_ms: Array = []
var errors: Array = []
func check(ok: bool, message: String) -> void:
	if not ok:errors.append(message);printerr(message)
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	var start:=Time.get_ticks_usec()
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	frames_ms.append((Time.get_ticks_usec()-start)/1000.0)
	check(main.overview!=null and main.overview.is_visible_in_tree(),"resident ground coverage")
	check(main.overview.mesh!=null and main.overview.texture!=null,"resident ground drawable")
	check(main.overviews["tilt"].visible==main.elevation.enabled,"matching projection")
	samples.append(main.main_update_us/1000.0)
func run() -> void:
	Engine.max_fps=60
	main=load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.map_memory_budget_mib=128
	await Wait.settled(main)
	check(main.overviews.size()==2,"both backdrops resident")
	check(not main.has_node("Interface"),"map-only UI retained")
	check(main.cpu_jobs.completed>=6,"projection work executed in pool")
	check(main.cpu_jobs.threads.size()>=2,"multiple CPU workers used")
	check(main.cpu_jobs.peak_running>=2,"overlapping CPU jobs")
	var baseline_ids := [main.overviews.flat.get_instance_id(),main.overviews.tilt.get_instance_id()]
	for tilt in [false,true]:
		main.set_oblique(tilt)
		main.asset_stream.injected_delay_ms=500
		for location in [Vector2(3460,5880),Vector2(4750,5350),Vector2(1920,6750)]:
			main.camera.position=main.elevation.project(location)
			for zoom_value in [0.5,1.3,2.197,4.0,0.96,1.02,0.5]:
				main.set_map_zoom(zoom_value)
				for i in range(4):await frame()
		main.asset_stream.injected_delay_ms=0
		await Wait.settled(main)
	check(baseline_ids==[main.overviews.flat.get_instance_id(),main.overviews.tilt.get_instance_id()],"backdrops never replaced")
	check(main.coverage_missing_frames==0,"zero coverage gaps")
	check(main.asset_stream.resident_bytes+main.asset_stream.reserved_bytes<=main.asset_stream.budget_bytes,"stream reservation budget")
	check(main.cpu_jobs.reserved_bytes==0,"workers release reservations")
	# Hysteresis around detail threshold.
	main.set_map_zoom(0.8)
	for i in range(10):main.set_map_zoom(1.02);main.set_map_zoom(0.99)
	check(not main.detail_active,"no repeated detail transition")
	main.set_map_zoom(4.0)
	main.camera.position=main.elevation.project(Vector2(5500,4100))
	var target: Array=main.catalog.get_detail_tiles(main.get_visible_world_rect())
	var failed_path: String=main._tile_path(target[0])
	main.asset_stream.injected_fail[failed_path]=true
	if main.asset_stream.cache.has(failed_path):main.asset_stream.release(failed_path)
	for i in range(60):await frame()
	check(main.asset_stream.failed.has(failed_path),"load failure injected")
	check(main.overview.visible,"backdrop survives failure")
	await Wait.settled(main)
	if DisplayServer.get_name()!="headless":
		root.get_texture().get_image().save_png("res://builds/seamless/failure_coverage.png")
		for node in main.loaded_tiles.values():node.hide()
		await frame()
		var backdrop: Image=root.get_texture().get_image()
		backdrop.save_png("res://builds/seamless/backdrop_coverage.png")
		var land:=backdrop.get_pixel(200,200)
		check(land.g-land.b>0.04,"known inland sample has terrain color, not pale placeholder")
		for node in main.loaded_tiles.values():node.show()
	main.asset_stream.injected_fail.clear()
	# Stale CPU completion cannot attach a parent after it is no longer requested.
	main.cpu_jobs.delay_ms=100
	var id := "izumi"
	await Wait.parent(main.district_layer,id)
	var parent_path: String=main.district_layer.compiled_parents[id]
	var resource: Resource=main.asset_stream.cache[parent_path]
	var original: Dictionary=resource.data
	var unindexed: Dictionary=original.duplicate()
	unindexed.erase("line_grid")
	resource.data=unindexed # Test-only missing derived index; source records unchanged.
	main.district_layer.loaded.erase(id)
	main.district_layer.load_parent(id)
	check(main.cpu_jobs.jobs.has("parent:"+id),"stale-result test actually dispatched")
	main.district_layer.waiting_parents.erase(id)
	while main.cpu_jobs.jobs.has("parent:"+id):await frame()
	check(not main.district_layer.loaded.has(id),"stale parent result rejected")
	resource.data=original
	main.cpu_jobs.delay_ms=0
	samples.sort();frames_ms.sort()
	var result={"passed":errors.is_empty(),"errors":errors,"frames":frames_ms.size(),"frame_max_ms":frames_ms[-1],"frames_over_100ms":frames_ms.filter(func(ms):return ms>100.0).size(),"frame_p95_ms":frames_ms[int(frames_ms.size()*.95)],"frame_p99_ms":frames_ms[int(frames_ms.size()*.99)],"main_update_p95_ms":samples[int(samples.size()*.95)],"coverage_missing_frames":main.coverage_missing_frames,"worker_threads":main.cpu_jobs.threads.keys(),"peak_workers":main.cpu_jobs.peak_running,"resident_bytes":main.asset_stream.resident_bytes,"budget_bytes":main.asset_stream.budget_bytes}
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(root.get_node("MapDiagnostics").suspended,"background state recorded")
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not root.get_node("MapDiagnostics").suspended,"resume restores heartbeat")
	main.notification(Node.NOTIFICATION_OS_MEMORY_WARNING)
	await process_frame
	check(main.low_memory_mode and main.prefetch_limit==4,"memory pressure reduces detail and prefetch")
	check(main.overview.visible,"memory pressure preserves backdrop")
	result["passed"]=errors.is_empty()
	FileAccess.open("res://builds/seamless/qa_headless.json" if DisplayServer.get_name()=="headless" else "res://builds/seamless/qa.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("SEAMLESS QA: ",JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
