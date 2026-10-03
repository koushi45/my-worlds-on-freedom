extends SceneTree
## Research-only changes to an isolated runtime script; game defaults stay intact.
var main: Node
var results: Array = []

func _initialize() -> void: call_deferred("run")

func settled() -> void:
    var deadline := Time.get_ticks_msec()+60000
    while main.has_pending_map_work() or main.map_view.fine_job>=0:
        if Time.get_ticks_msec()>deadline: printerr("FAIL: settle timeout"); quit(1); return
        await process_frame

func run() -> void:
    Engine.max_fps = 60
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    root.get_node("GameSession").new_game("oda_nobuhide")
    while current_scene==null or not current_scene.get("initialized"): await process_frame
    main = current_scene
    main.game_clock.set_process(false)
    main.set_map_zoom(8.0)
    main.map_view.manual_angle = 15.0
    main.camera.position = Vector2(4480,5504)
    for i in 30: await process_frame
    await settled()
    var source := FileAccess.get_file_as_string("res://scripts/map/terrain_chunk_set.gd")
    for concurrency in [2,4,8]:
        main.camera.position = Vector2(4480,5504)
        for i in 2: await process_frame
        await settled()
        var script := GDScript.new()
        script.source_code = source.replace("var parallel: int = [2,4,8][DisplaySettings.terrain_parallel_level]","var parallel: int = %d" % concurrency)
        if script.reload()!=OK: printerr("FAIL: research script compile"); quit(1); return
        var old: RefCounted = main.map_view.terrain_chunks
        var chunks: RefCounted = script.new()
        for key in ["view","manifest","far_nodes","near_nodes","near_cache","active_keys","wanted","wanted_region","wanted_active","last_visibility"]:
            chunks.set(key,old.get(key))
        main.map_view.terrain_chunks = chunks
        main.cpu_jobs.limit = maxi(4,concurrency)
        for step in 6:
            # Start with just the currently drawn region; each fresh step needs
            # the same boundary-dependent replacements regardless of cache history.
            chunks.near_cache.clear()
            for key in chunks.near_nodes: chunks.near_cache[key] = chunks.near_nodes[key].mesh
            var before: int = chunks.near_builds
            var start := Time.get_ticks_usec()
            main.camera.position.x += 128.0
            var target: Rect2 = main.map_view._desired_fine_rect()
            var frame_count := 0
            while main.map_view.fine_rect!=target or main.map_view.fine_job>=0:
                await process_frame
                frame_count += 1
                if Time.get_ticks_usec()-start>10000000: printerr("FAIL: update timeout"); quit(1); return
            results.append({"concurrency":concurrency,"step":step,"elapsed_ms":(Time.get_ticks_usec()-start)/1000.0,"frames":frame_count,"new_tiles":chunks.near_builds-before})
            await settled()
    var cached_bytes := 0
    for mesh in main.map_view.terrain_chunks.near_cache.values():
        var arrays: Array = mesh.surface_get_arrays(0)
        cached_bytes += arrays[Mesh.ARRAY_VERTEX].size()*12+arrays[Mesh.ARRAY_NORMAL].size()*12+arrays[Mesh.ARRAY_TEX_UV].size()*8+arrays[Mesh.ARRAY_INDEX].size()*4
    var report := {"results":results,"cache_tiles":main.map_view.terrain_chunks.near_cache.size(),"cache_array_bytes":cached_bytes,"worker_ids":main.cpu_jobs.threads.keys()}
    var output := FileAccess.open("res://builds/performance_800/terrain_latency_research.json",FileAccess.WRITE)
    output.store_string(JSON.stringify(report,"  "))
    output.close()
    print("TERRAIN_LATENCY_RESEARCH PASS ",JSON.stringify(report))
    quit(0)
