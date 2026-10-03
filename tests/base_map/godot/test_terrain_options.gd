extends SceneTree
var failures := 0
var main: Node
var settings: Node
var records: Array = []

func check(value: bool, message: String) -> void:
    if not value: failures += 1; printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func settle() -> void:
    var deadline := Time.get_ticks_msec()+60000
    var stable := 0
    while stable<10:
        await process_frame
        var chunks: RefCounted = main.map_view.terrain_chunks
        var ready: bool = not main.has_pending_map_work() and main.map_view.fine_job<0 and chunks.far_requests.is_empty()
        stable = stable+1 if ready else 0
        if Time.get_ticks_msec()>deadline: check(false,"terrain options settle"); return

func run() -> void:
    settings = root.get_node("DisplaySettings")
    Engine.max_fps = 60
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var original_path: String = settings.settings_path
    var original_levels := [settings.terrain_cache_level,settings.terrain_parallel_level,settings.terrain_prefetch_level]
    settings.settings_path = "user://qa_terrain_options.cfg"
    settings.set_terrain_options(0,0,0,false)
    var options: Control = load("res://scripts/game/display_options.gd").new()
    root.add_child(options)
    check(options.terrain_selectors.size()==3,"three independent option controls")
    options.terrain_selectors[0].select(1)
    options.terrain_selectors[1].select(2)
    options.terrain_selectors[2].select(1)
    options._apply()
    var config := ConfigFile.new()
    check(config.load(settings.settings_path)==OK,"terrain settings saved")
    check(config.get_value("terrain","cache")==1 and config.get_value("terrain","parallel")==2 and config.get_value("terrain","prefetch")==1,"independent terrain settings persisted")
    var reloaded: Node = settings.get_script().new()
    reloaded.settings_path = settings.settings_path
    root.add_child(reloaded)
    check(reloaded.terrain_cache_level==1 and reloaded.terrain_parallel_level==2 and reloaded.terrain_prefetch_level==1,"terrain settings reload")
    reloaded.queue_free()
    options.queue_free()
    settings.set_terrain_options(0,0,0,false)
    root.get_node("GameSession").new_game("oda_nobuhide")
    while current_scene==null or not current_scene.get("initialized"): await process_frame
    main=current_scene
    main.game_clock.set_process(false)
    main.set_map_zoom(8.0)
    main.map_view.manual_angle=15.0
    main.camera.position=Vector2(4480,5504)
    await settle()
    for level in [0,1,2,0]:
        settings.set_terrain_options(level,level,level,false)
        await settle()
        var view: Node = main.map_view
        var chunks: RefCounted = view.terrain_chunks
        check(main.cpu_jobs.limit==[4,6,10][level],"global CPU job limit")
        check(main.asset_stream.limit==[2,4,6][level],"map loading concurrency")
        check(main.map_memory_budget_mib==[320,640,1024][level],"map cache budget")
        check(chunks.near_cache_limit==[64,128,256][level],"near mesh cache limit")
        check(chunks.near_cache.size()<=chunks.near_cache_limit,"near cache stays bounded")
        check(chunks.near_nodes.size()==[32,96,144][level],"active terrain retention range")
        check(not chunks.prefetch_wanted.is_empty() if level>0 else chunks.prefetch_wanted.is_empty(),"speculative terrain generation option")
        check(not chunks.far_cache.is_empty() if level>0 else chunks.far_cache.is_empty(),"far mesh cache option")
        var start := Time.get_ticks_usec()
        var before: int = chunks.near_builds
        main.camera.position.x+=128.0
        var target: Rect2 = view._desired_fine_rect()
        while view.fine_rect!=target: await process_frame
        var elapsed := (Time.get_ticks_usec()-start)/1000.0
        check(chunks.near_builds-before<=8 if level==0 else true,"low profile needs only exposed tiles")
        await settle()
        for heading in [90.0,180.0,270.0,0.0]:
            view.yaw=heading
            for i in 4: await process_frame
        await settle()
        for id in main.district_office_layer.records:
            var point: Vector2 = main.district_office_layer.office_point(id)
            if not view.fine_rect.grow(-40.0).has_point(point): continue
            var screen: Vector2 = view.project(point)
            if not main.get_viewport_rect().grow(-20).has_point(screen): continue
            if view.marker_visible(point,true):
                check(view.pick(screen).distance_to(point)<0.01,"pick follows boundary-deformed terrain")
        main.game_menu.toggle()
        main.game_menu.show_options()
        options=main.game_menu.options
        for i in 3: await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://builds/performance_800/terrain_options_ui_%d.png" % level)
        main.game_menu._close_all()
        records.append({"level":level,"active_tiles":chunks.near_nodes.size(),"cached_tiles":chunks.near_cache.size(),"move_ready_ms":elapsed,"far_cached":chunks.far_cache.size(),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)})
    settings.settings_path=original_path
    settings.set_terrain_options(original_levels[0],original_levels[1],original_levels[2],false)
    DirAccess.remove_absolute("user://qa_terrain_options.cfg")
    var file := FileAccess.open("res://builds/performance_800/terrain_options_results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"records":records},"  "))
    file.close()
    print("TERRAIN_OPTIONS ","PASS" if failures==0 else "FAIL"," ",JSON.stringify(records))
    quit(0 if failures==0 else 1)
