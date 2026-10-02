extends SceneTree
## Real GPU benchmark: fixed poses and trajectories, full 800% assets.
var main: Node
var stage := "baseline"
var output := "res://builds/performance_800"
var frames := 120
var results: Array = []

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
        if arg.begins_with("--frames="): frames = int(arg.trim_prefix("--frames="))
    call_deferred("run")

func settle() -> bool:
    var deadline := Time.get_ticks_msec()+60000
    var stable := 0
    while Time.get_ticks_msec()<deadline:
        await process_frame
        var view: Node = main.map_view
        var ready: bool = not main.has_pending_map_work() and view.fine_job<0 and view.terrain_materials.waiting.is_empty() and view.terrain_materials.active==800
        stable = stable+1 if ready else 0
        if stable>=30: return true
    return false

func measure(label: String, center: Vector2, mode: String) -> void:
    var samples: Array[float] = []
    var updates: Array[float] = []
    var marker_times: Array[float] = []
    var process_times: Array[float] = []
    var source_cpu: Array[float] = []
    var source_gpu: Array[float] = []
    var root_cpu: Array[float] = []
    var root_gpu: Array[float] = []
    var profiles := {}
    var nodes := [main,main.map_view,main.hex_tile_layer,main.district_office_layer,main.shared_road_layer,main.district_layer,main.territory_borders,main.army_campaign,main.political_layer,main.river_layer,main.lake_layer]
    await process_frame
    var previous := Time.get_ticks_usec()
    for i in frames:
        var t := float(i)/float(frames-1)*TAU
        if mode=="pan": main.camera.position = center+Vector2(cos(t),sin(t))*160.0
        if mode=="orbit": main.map_view.yaw = rad_to_deg(t)
        await process_frame
        var now := Time.get_ticks_usec()
        samples.append(float(now-previous)/1000.0)
        updates.append(float(main.main_update_us)/1000.0)
        if "last_draw_us" in main.map_view.markers: marker_times.append(float(main.map_view.markers.last_draw_us)/1000.0)
        process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
        source_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(main.map_view.source_view.get_viewport_rid()))
        source_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(main.map_view.source_view.get_viewport_rid()))
        root_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
        root_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
        for node in nodes:
            for prop in ["profile_process_us","profile_draw_us","profile_advance_us"]:
                if prop in node:
                    var key: String = node.get_script().resource_path+":"+prop
                    if not profiles.has(key): profiles[key] = []
                    profiles[key].append(float(node.get(prop))/1000.0)
        previous = now
    var elapsed := float(Time.get_ticks_usec()-previous)
    samples.sort()
    updates.sort()
    marker_times.sort()
    process_times.sort()
    source_cpu.sort(); source_gpu.sort(); root_cpu.sort(); root_gpu.sort()
    var sum := 0.0
    var over := 0
    for ms in samples:
        sum += ms
        if ms>20.0: over+=1
    var entry := {"label":label,"mode":mode,"frames":frames,"fps":frames*1000.0/sum,
        "p50_ms":samples[int(frames*0.5)],"p95_ms":samples[int(frames*0.95)],"p99_ms":samples[int(frames*0.99)],"max_ms":samples[-1],"over_20ms":over,
        "main_p95_ms":updates[int(frames*0.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
        "atlas_size":[main.map_view.source_view.size.x,main.map_view.source_view.size.y],"geometry_builds":main.map_view.geometry_builds,
        "tiles":main.loaded_tiles.size(),"materials":main.map_view.terrain_materials.active}
    entry["source_cpu_p95_ms"] = source_cpu[int(frames*0.95)]
    entry["source_gpu_p95_ms"] = source_gpu[int(frames*0.95)]
    entry["root_cpu_p95_ms"] = root_cpu[int(frames*0.95)]
    entry["root_gpu_p95_ms"] = root_gpu[int(frames*0.95)]
    entry["process_p95_ms"] = process_times[int(frames*0.95)]
    if not marker_times.is_empty(): entry["markers_p95_ms"] = marker_times[int(frames*0.95)]
    entry["cpu_functions_p95_ms"] = {}
    for key in profiles:
        profiles[key].sort()
        entry.cpu_functions_p95_ms[key] = profiles[key][int(frames*0.95)]
    results.append(entry)
    print("BENCH800 ",JSON.stringify(entry))

func run() -> void:
    Engine.max_fps = 60
    root.size = Vector2i(1920,1080)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    var session := root.get_node("GameSession")
    if session.new_game("oda_nobuhide")!=OK: quit(1); return
    var deadline := Time.get_ticks_msec()+60000
    while (current_scene==null or not current_scene.get("initialized")) and Time.get_ticks_msec()<deadline: await process_frame
    if current_scene==null or not current_scene.get("initialized"): quit(1); return
    main = current_scene
    RenderingServer.viewport_set_measure_render_time(main.map_view.source_view.get_viewport_rid(),true)
    RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
    if "--no-markers" in OS.get_cmdline_user_args(): main.map_view.markers.hide()
    if "--no-occlusion" in OS.get_cmdline_user_args(): main.map_view.skip_marker_occlusion = true
    main.game_clock.set_process(false)
    main.set_map_zoom(8.0)
    main.map_view.manual_angle = 15.0
    var places := {"kinki":Vector2(4480,5504),"fuji":Vector2(4768,5440),"kanto":Vector2(5500,4100)}
    for label in places:
        if "--kinki-only" in OS.get_cmdline_user_args() and label!="kinki": continue
        var center: Vector2 = places[label]
        main.camera.position = center
        main.map_view.yaw = 0.0
        if not await settle(): printerr("BENCH800 settle timeout: ",label); quit(1); return
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/"+stage+"_"+label+".png")
        await measure(label,center,"idle")
        await measure(label,center,"pan")
        main.camera.position = center
        if not await settle(): quit(1); return
        await measure(label,center,"orbit")
    var file := FileAccess.open(output+"/"+stage+".json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"stage":stage,"engine":Engine.get_version_info(),"viewport":[1920,1080],"max_fps":60,"vsync":false,"results":results},"  "))
    quit(0)
