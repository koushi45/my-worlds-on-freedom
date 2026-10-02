extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    root.get_node("GameSession").new_game("uesugi_yamanouchi")
    while current_scene==null or current_scene.map_view==null: await process_frame
    var main: Node = current_scene
    main.game_clock.set_process(false)
    main.camera.position=Vector2(4480,5504)
    main.set_map_zoom(2.0)
    for i in 30: await process_frame
    var cursor := Vector2(900,530)
    var anchor: Vector2 = main.map_view.pick(cursor)
    main._zoom_at(8.0,cursor)
    for i in 80:
        await process_frame
        if i%5==0:
            print("ANCHOR ",i," err=",main.world_to_screen(anchor)-cursor," camera=",main.camera.position," requested=",main.map_view.anchor_world," fine=",main.map_view.fine_surface.visible)
    main.camera.position=Vector2(4740,5504)
    main.map_view.anchor_world=Vector2(INF,INF)
    main.set_map_zoom(8.0)
    while main.has_pending_map_work(): await process_frame
    for i in 10: await process_frame
    await RenderingServer.frame_post_draw
    var before := root.get_texture().get_image()
    before.save_png("res://builds/qa/map_view_angle/debug_light_before.png")
    print("LIGHT ",main.map_view.sun.global_transform," fine material ",main.map_view.fine_material.shader.code.substr(0,100))
    main.map_view.sun.light_energy=0.0
    for i in 10: await process_frame
    await RenderingServer.frame_post_draw
    var after := root.get_texture().get_image()
    after.save_png("res://builds/qa/map_view_angle/debug_light_off.png")
    var difference := 0.0
    for y in range(350,850,20):
        for x in range(450,1450,20):
            var a := before.get_pixel(x,y)
            var b := after.get_pixel(x,y)
            difference+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
    print("LIGHT CHANGE ",difference)
    for region in [Vector2(4480,5504),Vector2(4740,5504),Vector2(3460,5880)]:
        for zoom in [1.0,2.0,4.0,6.0,8.0]:
            main.camera.position=region
            main.set_map_zoom(zoom)
            for i in 40: await process_frame
            for offset in [Vector2.ZERO,Vector2(-250,100),Vector2(250,100),Vector2(0,300),Vector2(-400,-250),Vector2(400,-250)]:
                var screen: Vector2 = Vector2(640,360)+offset
                var hit:Vector2=main.map_view.pick(screen)
                if not hit.is_finite(): continue
                var error:float=main.world_to_screen(hit).distance_to(screen)*1.5
                if error>0.5: print("RAY ",region," zoom=",zoom," screen=",screen," hit=",hit," error=",error)
    quit()
