extends SceneTree
var failures := 0
var main: Node
class OrbitProbe extends Node2D:
    var point := Vector2.ZERO
    func _draw() -> void: draw_circle(point,1.3,Color(1,0,1))

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        printerr("FAIL: ",message)

func drag(button: int, relative: Vector2) -> void:
    var press := InputEventMouseButton.new()
    press.button_index = button
    press.position = Vector2(650,400)
    press.pressed = true
    root.push_input(press,true)
    var motion := InputEventMouseMotion.new()
    motion.relative = relative
    motion.position = press.position+relative
    motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE if button == MOUSE_BUTTON_MIDDLE else MOUSE_BUTTON_MASK_LEFT
    root.push_input(motion,true)
    press.position = motion.position
    press.pressed = false
    root.push_input(press,true)

func settle() -> void:
    for i in 30: await process_frame

func run() -> void:
    var session := root.get_node("GameSession")
    check(session.new_game("oda_nobuhide") == OK,"new game")
    var deadline := Time.get_ticks_msec()+60000
    while Time.get_ticks_msec()<deadline and (current_scene == null or not current_scene.get("initialized")):
        await process_frame
    if current_scene == null or not current_scene.get("initialized"):
        printerr("Map startup timed out"); quit(1); return
    main = current_scene
    main.game_clock.set_process(false)
    main.camera.position = Vector2(4480,5504)
    main.set_map_zoom(2.0)
    await settle()
    var center: Vector2 = main.camera.position
    var atlas_size: Vector2i = main.map_view.source_view.size
    drag(MOUSE_BUTTON_MIDDLE,Vector2(160,-80))
    check(is_equal_approx(main.map_view.yaw,-40.0),"horizontal middle drag rotates")
    check(is_equal_approx(main.map_view.angle,40.0),"vertical middle drag tilts")
    check(main.camera.position == center,"orbit retains geographic center")
    check(not main.dragging,"release ends orbit")
    main.set_map_zoom(4.0)
    await settle()
    check(is_equal_approx(main.map_view.angle,40.0),"zoom retains manual angle")
    for heading in [-179.0,-90.0,0.0,90.0,179.0]:
        main.map_view.yaw = heading
        main.map_view.sync(true)
        for screen in [Vector2(640,400),Vector2(450,430),Vector2(820,480)]:
            var point: Vector2 = main._screen_to_world(screen)
            check(point.is_finite(),"rotated terrain pick")
            if point.is_finite(): check(main.world_to_screen(point).distance_to(screen)<0.7,"rotated pick reprojects")
        check(main.map_view.source_view.size == atlas_size,"orbit keeps atlas allocation")
        check(is_equal_approx(main.map_view.source_camera.rotation,-deg_to_rad(heading)),"atlas follows heading")
        if DisplayServer.get_name() != "headless":
            var probe := OrbitProbe.new()
            probe.point = main._screen_to_world(Vector2(780,440))
            probe.z_index = 100
            main.map_view.source_root.add_child(probe)
            for i in 4: await process_frame
            await RenderingServer.frame_post_draw
            var frame := root.get_texture().get_image()
            var pixel_scale: float = float(root.size.x)/main.get_viewport_rect().size.x
            var predicted: Vector2 = main.world_to_screen(probe.point)*pixel_scale
            var centroid := Vector2.ZERO
            var count := 0
            for y in range(int(predicted.y)-20,int(predicted.y)+21):
                for x in range(int(predicted.x)-20,int(predicted.x)+21):
                    var colour := frame.get_pixel(x,y)
                    if colour.r>0.30 and colour.b>0.30 and colour.g<0.12 and absf(colour.r-colour.b)<0.18:
                        centroid += Vector2(x+0.5,y+0.5); count += 1
            check(count>20,"rotated atlas probe visible")
            if count>0: check((centroid/float(count)).distance_to(predicted)<1.5,"rotated atlas aligns with terrain")
            probe.queue_free()
    main.map_view.yaw = -90.0
    var before: Vector2 = main.camera.position
    drag(MOUSE_BUTTON_LEFT,Vector2(70,0))
    check(main.camera.position.distance_to(before)>1.0,"left drag still pans after rotation")
    check(is_equal_approx(main.map_view.yaw,-90.0),"left drag retains heading")
    drag(MOUSE_BUTTON_MIDDLE,Vector2(0,-1000))
    check(main.map_view.angle == 15.0,"minimum pitch")
    drag(MOUSE_BUTTON_MIDDLE,Vector2(0,1000))
    check(main.map_view.angle == 90.0,"maximum pitch")
    drag(MOUSE_BUTTON_MIDDLE,Vector2(20,-120))
    var saved: Dictionary = session.capture(main)
    check(session.validate(saved),"current save with orbit validates")
    main.map_view.manual_angle = -1.0; main.map_view.yaw = 0.0
    session.pending = saved
    session.apply_to(main)
    await settle()
    check(main.map_view.manual_angle == saved.camera.manual_angle and main.map_view.yaw == saved.camera.yaw,"save restores orbit")
    main.developer_tools.open(); main.developer_tools.set_contour_mode(true)
    drag(MOUSE_BUTTON_MIDDLE,Vector2(120,-80))
    check(not main.is_oblique() and main.map_view.angle == 90.0,"contour stays top-down")
    main.developer_tools.close()
    check(main.is_oblique() and main.map_view.angle == saved.camera.manual_angle,"contour exit restores orbit")
    main.set_oblique(false)
    drag(MOUSE_BUTTON_MIDDLE,Vector2(20,-20))
    check(main.is_oblique(),"middle drag enables orbit from flat view")
    main._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    check(not main.dragging,"focus loss clears drag")
    print("MAP ORBIT QA: ","PASS" if failures == 0 else "FAIL", " (",failures," failures)")
    quit(0 if failures == 0 else 1)
