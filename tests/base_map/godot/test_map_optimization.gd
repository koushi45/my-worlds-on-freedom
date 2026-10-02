extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
    if not value:
        failures+=1
        printerr("FAIL: ",message)
func run() -> void:
    root.get_node("GameSession").new_game("oda_nobuhide")
    var deadline := Time.get_ticks_msec()+60000
    while current_scene==null or not current_scene.get("initialized"):
        if Time.get_ticks_msec()>deadline: quit(1); return
        await process_frame
    var main: Node = current_scene
    var view: Node = main.map_view
    main.game_clock.set_process(false)
    main.set_process_input(false)
    main.set_process_unhandled_input(false)
    root.gui_disable_input=true
    check(not view.ray_bounds.is_empty(),"ray bounds loaded")
    main.set_map_zoom(8.0)
    var rays := 0
    var max_error := 0.0
    for center in [Vector2(4480,5504),view.fuji_rect.get_center()+Vector2(0,45),Vector2(5500,4100)]:
        main.camera.position=center
        view.manual_angle=15.0
        deadline=Time.get_ticks_msec()+60000
        for i in 30: await process_frame
        while main.has_pending_map_work() and Time.get_ticks_msec()<deadline: await process_frame
        check(not main.has_pending_map_work(),"assets settled")
        for heading in [0.0,75.0,180.0,270.0]:
            view.yaw=heading
            view.sync(true)
            for y in range(210,660,90):
                for x in range(220,1160,120):
                    var screen := Vector2(x,y)
                    view.ray_bounds_enabled=true
                    var fast: Vector2 = view.pick(screen)
                    view.ray_bounds_enabled=false
                    var exact: Vector2 = view.pick(screen)
                    check(fast.is_finite()==exact.is_finite(),"ray hit existence")
                    if fast.is_finite() and exact.is_finite():
                        var error := fast.distance_to(exact)
                        max_error=maxf(max_error,error)
                        check(error<0.02,"accelerated ray agrees with exact triangles")
                    rays+=1
            view.ray_bounds_enabled=true
        check(view.terrain_materials.stream.waiting.size()<=2,"bounded texture requests")
        check(view.terrain_materials.stream.resident_bytes+view.terrain_materials.stream.reserved_bytes<=view.terrain_materials.stream.budget_bytes,"bounded texture reservation")
        check(main.cpu_jobs.reserved_bytes<=main.cpu_jobs.budget_bytes,"bounded CPU jobs")
        check(view.terrain_chunks.near_cache.size()<=64 if view.chunked_terrain else view.fine_cache.size()<=2,"bounded near mesh cache")
    view.yaw=0
    for i in 30: await process_frame
    var draws: int = view.markers.draw_count
    var refreshes: int = main.house_status_hud.refresh_count
    for i in 60: await process_frame
    check(view.markers.draw_count==draws,"static markers are retained")
    check(main.house_status_hud.refresh_count==refreshes,"static HUD is retained")
    main.district_actions.changed.emit("probe")
    for i in 2: await process_frame
    check(main.house_status_hud.refresh_count>refreshes,"HUD reacts to gameplay event")
    main.settlement_layer.hide()
    for i in 2: await process_frame
    check(view.markers.draw_count>draws,"marker visibility change invalidates retained drawing")
    print("MAP_OPTIMIZATION ","PASS" if failures==0 else "FAIL"," rays=",rays," max_world_error=",max_error," skipped_blocks=",view.ray_blocks_skipped)
    quit(0 if failures==0 else 1)
