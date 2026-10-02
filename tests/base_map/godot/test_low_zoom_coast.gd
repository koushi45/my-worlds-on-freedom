extends SceneTree

var main: Node
var failures := 0
var output := "res://builds/qa/low_zoom_coast/"

func check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=").trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    call_deferred("run")

func settle() -> void:
    for i in 20: await process_frame
    var deadline := Time.get_ticks_msec()+30000
    while main.has_pending_map_work() and Time.get_ticks_msec()<deadline: await process_frame
    check(not main.has_pending_map_work(),"streaming completes")
    for i in 8: await process_frame

func run() -> void:
    check(root.get_node("GameSession").new_game("uesugi_yamanouchi")==OK,"new game")
    var deadline := Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and (current_scene==null or not current_scene.initialized): await process_frame
    if current_scene==null or not current_scene.initialized: quit(1);return
    main = current_scene
    main.game_clock.set_process(false)
    main.set_process_input(false)
    main.set_process_unhandled_input(false)
    root.gui_disable_input = true
    var sea: MeshInstance3D = main.map_view.get_node("OuterSea")
    # Optional negative control recreates the original overlapping sea plane.
    if "--legacy-sea" in OS.get_cmdline_user_args():
        var plane := PlaneMesh.new()
        plane.size = Vector2(65536,65536)
        sea.mesh = plane
        sea.position.y = -0.1
    var records: Array = []
    for tilt in [false,true]:
        main.set_oblique(tilt)
        for zoom in [0.5,0.75,1.0]:
            main.set_map_zoom(zoom)
            for pan in 3:
                main.camera.position = Vector2(4850,5580)+Vector2(pan*127.25,pan*43.5)
                await settle()
                await RenderingServer.frame_post_draw
                var visible := root.get_texture().get_image()
                sea.hide()
                for i in 2: await process_frame
                await RenderingServer.frame_post_draw
                var hidden := root.get_texture().get_image()
                sea.show()
                var changed := 0
                var samples := 0
                var screen_scale: Vector2 = Vector2(root.size)/main.get_viewport_rect().size
                for y in range(120,visible.get_height()-120,4):
                    for x in range(120,visible.get_width()-120,4):
                        var screen: Vector2 = Vector2(x,y)/screen_scale
                        var camera: Camera3D = main.map_view.view_camera
                        var point: Vector2 = main.map_view.plane_intersection(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
                        if not Rect2(32,32,8128,8128).has_point(point): continue
                        samples += 1
                        var a := visible.get_pixel(x,y)
                        var b := hidden.get_pixel(x,y)
                        if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>0.03: changed += 1
                check(samples>1000,"geographic surface sampled")
                check(changed==0,"outer sea cannot cover geographic pixels: %s/%s/%s (%d changed)" % [tilt,zoom,pan,changed])
                check(main.asset_stream.failed.is_empty(),"no failed map assets")
                records.append({"tilt":tilt,"zoom":zoom,"pan":pan,"samples":samples,"changed":changed})
                if zoom==0.5: visible.save_png(output+"coast_%s_%d.png" % [tilt,pan])
    # Outside the map the surrounding sea must still cover the background.
    main.set_oblique(false)
    main.set_map_zoom(0.5)
    main.camera.position = Vector2(300,300)
    await settle()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"map_edge.png")
    var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"failures":failures,"records":records},"  "))
    print("LOW ZOOM COAST QA: ","PASS" if failures==0 else "FAIL")
    quit(0 if failures==0 else 1)
