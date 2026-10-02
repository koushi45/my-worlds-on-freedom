extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
    root.get_node("GameSession").new_game("uesugi_yamanouchi")
    var deadline := Time.get_ticks_msec()+60000
    while current_scene == null or current_scene.map_view == null:
        if Time.get_ticks_msec()>deadline:
            printerr("FAIL: startup timed out"); quit(1); return
        await process_frame
    var main = current_scene
    main.game_clock.set_process(false)
    main.set_process_input(false)
    main.set_process_unhandled_input(false)
    root.gui_disable_input = true
    var view = main.map_view
    check(is_equal_approx(view.height_scale,0.00882632187962517),"2x vertical exaggeration")
    check(view.fuji_data.size()==513*513*2,"regional DEM loads")
    check(view.fuji_surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==513*513,"57m summit mesh")
    main.camera.position = view.fuji_rect.get_center()+Vector2(0,45)
    main.set_oblique(true)
    for zoom in [4.0,8.0]:
        main.set_map_zoom(zoom)
        deadline = Time.get_ticks_msec()+60000
        for frame in 30: await process_frame
        while main.has_pending_map_work() and Time.get_ticks_msec()<deadline: await process_frame
        for frame in 20: await process_frame
        check(view.fuji_surface.visible,"detailed summit active at zoom "+str(zoom))
        # The detailed patch must meet its parent mesh without a vertical crack.
        for axis in range(0,129,2):
            for point in [view.fuji_rect.position+Vector2(axis,0),view.fuji_rect.position+Vector2(0,axis),view.fuji_rect.end-Vector2(axis,0),view.fuji_rect.end-Vector2(0,axis)]:
                check(absf(view._vertex_height(point,view.fuji_rect)-view._triangle_height(point,2))<0.0001,"patch seam")
        for y in range(260,620,60):
            for x in range(420,900,60):
                var screen := Vector2(x,y)
                var point: Vector2 = view.pick(screen)
                if point.is_finite(): check(view.project(point).distance_to(screen)<0.5,"ray and rendering agree")
        if "--capture" in OS.get_cmdline_user_args():
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://builds/qa/fuji_%d.png" % int(zoom*100))
    main.set_oblique(false)
    for frame in 30: await process_frame
    check(not view.fuji_surface.visible,"flat mode disables summit mesh")
    print("Fuji terrain scale, detailed mesh, seams and picking: ","PASS" if failures==0 else "FAIL")
    quit(0 if failures==0 else 1)
