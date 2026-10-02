extends Node
## Real GPU benchmark: fixed poses and trajectories, full 800% assets.
var main: Node
var stage := "baseline"
var output := "res://builds/performance_800"
var frames := 120
var results: Array = []
var fps_limit := 60
var material_tier := 800
var atlas_scale := 1.0
var options: PackedStringArray

func _ready() -> void:
    options = OS.get_cmdline_user_args()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
        if arg.begins_with("--frames="): frames = int(arg.trim_prefix("--frames="))
        if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--fps-limit="): fps_limit = maxi(0,int(arg.trim_prefix("--fps-limit=")))
        if arg.begins_with("--material-tier="): material_tier = int(arg.trim_prefix("--material-tier="))
        if arg.begins_with("--atlas-scale="): atlas_scale = clampf(float(arg.trim_prefix("--atlas-scale=")),0.125,1.0)
    frames=maxi(10,frames)
    call_deferred("run")

func settle() -> bool:
    var deadline := Time.get_ticks_msec()+60000
    var stable := 0
    while Time.get_ticks_msec()<deadline:
        await get_tree().process_frame
        var view: Node = main.map_view
        var ready: bool = not main.has_pending_map_work() and view.fine_job<0 and view.terrain_materials.waiting.is_empty() and view.terrain_materials.active==800
        stable = stable+1 if ready else 0
        if stable>=30: return true
    return false

func measure(label: String, center: Vector2, mode: String) -> void:
    print("BENCH800_PHASE ",label," ",mode)
    var samples: Array[float] = []
    var updates: Array[float] = []
    var marker_times: Array[float] = []
    var process_times: Array[float] = []
    var source_cpu: Array[float] = []
    var source_gpu: Array[float] = []
    var root_cpu: Array[float] = []
    var root_gpu: Array[float] = []
    await get_tree().process_frame
    var previous := Time.get_ticks_usec()
    for i in frames+2:
        var t := clampf(float(i-2)/float(frames-1),0.0,1.0)*TAU
        if mode=="pan": main.camera.position = center+Vector2(cos(t),sin(t))*160.0
        if mode=="orbit": main.map_view.yaw = rad_to_deg(t)
        await get_tree().process_frame
        var now := Time.get_ticks_usec()
        if i<2:
            previous=now
            continue
        samples.append(float(now-previous)/1000.0)
        updates.append(float(main.main_update_us)/1000.0)
        if "last_draw_us" in main.map_view.markers: marker_times.append(float(main.map_view.markers.last_draw_us)/1000.0)
        process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
        source_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(main.map_view.source_view.get_viewport_rid()))
        source_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(main.map_view.source_view.get_viewport_rid()))
        root_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(get_tree().root.get_viewport_rid()))
        root_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_tree().root.get_viewport_rid()))
        previous = now
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
    if main.map_view.chunked_terrain:
        var chunks: RefCounted = main.map_view.terrain_chunks
        entry["far_tiles"] = chunks.far_nodes.size()
        entry["near_tiles"] = chunks.near_nodes.size()
        entry["near_cached_tiles"] = chunks.near_cache.size()
        entry["near_builds"] = chunks.near_builds
        entry["near_reuses"] = chunks.near_reuses
        entry["far_loads"] = chunks.far_loads
        entry["far_releases"] = chunks.far_releases
        entry["far_lod_switches"] = chunks.far_lod_switches
        var far_vertices := 0
        var near_vertices := 0
        var coarse_tiles := 0
        for node in chunks.far_nodes.values():
            far_vertices+=node.mesh.surface_get_array_len(0)
            if node.get_meta("coarse",false): coarse_tiles+=1
        for node in chunks.near_nodes.values(): near_vertices+=node.mesh.surface_get_array_len(0)
        entry["far_vertices"]=far_vertices
        entry["near_vertices"]=near_vertices
        entry["far_coarse_tiles"]=coarse_tiles
    if not marker_times.is_empty(): entry["markers_p95_ms"] = marker_times[int(frames*0.95)]
    results.append(entry)
    print("BENCH800 ",JSON.stringify(entry))
    print("BENCH800_PHASE loading")

func run() -> void:
    Engine.max_fps = fps_limit
    get_tree().root.size = Vector2i(1920,1080)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    var session := get_tree().root.get_node("GameSession")
    if session.new_game("oda_nobuhide")!=OK: get_tree().quit(1); return
    var deadline := Time.get_ticks_msec()+60000
    while (get_tree().current_scene==null or not get_tree().current_scene.get("initialized")) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
    if get_tree().current_scene==null or not get_tree().current_scene.get("initialized"): get_tree().quit(1); return
    main = get_tree().current_scene
    main.map_view.set_meta("probe_atlas_scale",atlas_scale)
    main.map_view.set_meta("probe_no_occlusion","--no-occlusion" in options)
    if material_tier != 800:
        if not main.map_view.terrain_materials.manifest.tiers.has(str(material_tier)):
            printerr("Invalid material tier"); get_tree().quit(1); return
        var tier: Dictionary = main.map_view.terrain_materials.manifest.tiers[str(material_tier)].duplicate(true)
        for key in main.map_view.terrain_materials.manifest.tiers:
            main.map_view.terrain_materials.manifest.tiers[key] = tier
    if "--no-shadows" in options: main.map_view.sun.shadow_enabled = false
    if "--no-hex" in options: main.hex_tile_layer.hide()
    if "--no-borders" in options:
        main.district_layer.hide()
        main.territory_borders.hide()
        main.political_layer.hide()
    if "--no-source" in options: main.map_view.source_root.hide()
    RenderingServer.viewport_set_measure_render_time(main.map_view.source_view.get_viewport_rid(),true)
    RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(),true)
    if "--no-markers" in OS.get_cmdline_user_args(): main.map_view.markers.hide()
    main.game_clock.set_process(false)
    main.set_map_zoom(8.0)
    main.map_view.manual_angle = 15.0
    var places := {"kinki":Vector2(4480,5504),"fuji":Vector2(4768,5440),"kanto":Vector2(5500,4100)}
    for label in places:
        if "--kinki-only" in OS.get_cmdline_user_args() and label!="kinki": continue
        var center: Vector2 = places[label]
        main.camera.position = center
        main.map_view.yaw = 0.0
        main.map_view.set_meta("probe_freeze_near",false)
        if not await settle(): printerr("BENCH800 settle timeout: ",label); get_tree().quit(1); return
        if "--freeze-near" in options or "--no-near" in options:
            main.map_view.set_meta("probe_freeze_near",true)
        if "--no-near" in options:
            main.map_view.fine_surface.hide()
            main.map_view.fuji_surface.hide()
            for material in [main.map_view.surface_material,main.map_view.fine_material,main.map_view.fuji_material]:
                material.set_shader_parameter("fine_active",false)
                material.set_shader_parameter("fuji_active",false)
        await RenderingServer.frame_post_draw
        get_tree().root.get_texture().get_image().save_png(output+"/"+stage+"_"+label+".png")
        await measure(label,center,"idle")
        await measure(label,center,"pan")
        main.camera.position = center
        if not await settle(): get_tree().quit(1); return
        await measure(label,center,"orbit")
    var file := FileAccess.open(output+"/"+stage+".json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"stage":stage,"engine":Engine.get_version_info(),"viewport":[1920,1080],"max_fps":fps_limit,"vsync":false,"options":options,"material_tier":material_tier,"atlas_scale":atlas_scale,"results":results},"  "))
    get_tree().quit(0)
