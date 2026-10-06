extends SceneTree
var main: Node
var failures := 0
var max_pick_pixels := 0.0
var max_anchor_pixels := 0.0
var output := "res://builds/qa/map_view_angle/"
var stage := "view"
var records: Array = []

func check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=").trim_suffix("/")+"/"
        if arg.begins_with("--stage="): stage=arg.trim_prefix("--stage=")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    call_deferred("run")

func settle() -> void:
    var deadline := Time.get_ticks_msec()+30000
    for i in 20: await process_frame
    while main.has_pending_map_work() and Time.get_ticks_msec()<deadline: await process_frame
    check(not main.has_pending_map_work(),"map streaming completes")
    for i in 8: await process_frame

func run() -> void:
    var session := root.get_node("GameSession")
    check(session.new_game("uesugi_yamanouchi")==OK,"new game")
    var deadline := Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and (current_scene==null or current_scene.map_view==null): await process_frame
    if current_scene==null or current_scene.map_view==null:
        printerr("FAIL: 3D view startup");quit(1);return
    main=current_scene
    main.game_clock.set_process(false)
    main.set_process_input(false);main.set_process_unhandled_input(false);root.gui_disable_input=true
    check(main.map_view.terrain_chunks.far_nodes.size()>0 if main.map_view.chunked_terrain else main.map_view.surface.mesh.get_surface_count()==1,"real 3D terrain")
    check(main.map_view.view_camera.current,"3D camera current")
    check(not main.camera.enabled,"control camera does not transform HUD")
    check(main.shared_road_layer.get_parent()==main.hex_tile_layer,"roads stay children of hex layer")
    check(main.tile_root.get_viewport()==main.map_view.source_view,"ground layers use source atlas")
    var allocations: Vector2i = main.map_view.source_view.size
    for region in [{"name":"mixed","point":Vector2(4480,5504)},{"name":"mountain","point":Vector2(4740,5504)},{"name":"coast","point":Vector2(3460,5880)}]:
        main.camera.position=region.point
        main.set_oblique(true)
        for zoom in [1.0,2.0,4.0,6.0,8.0]:
            main.set_map_zoom(zoom)
            await settle()
            var expected: float = {1.0:75.0,2.0:60.0,4.0:40.0,6.0:25.0,8.0:15.0}[zoom]
            check(absf(main.map_view.angle-expected)<0.001,"zoom angle "+str(zoom))
            var materials: RefCounted = main.map_view.terrain_materials
            check(materials.active==int(zoom*100),"native material for selected zoom")
            var native_size: int = {1.0:192,2.0:384,4.0:768,6.0:1024,8.0:1254}[zoom]
            check(materials.resident[materials.active].grass_albedo.get_width()==native_size,"native albedo dimensions")
            check(materials.resident[materials.active].grass_normal.get_width()==native_size,"native micro normal dimensions")
            check(main.map_view.source_view.size==allocations,"stable atlas allocation")
            var center: Vector2 = main.get_viewport_rect().size*0.5
            for offset in [Vector2.ZERO,Vector2(-250,100),Vector2(250,100),Vector2(0,300),Vector2(-400,-250),Vector2(400,-250)]:
                var screen: Vector2 = center+offset
                var source: Vector2 = main._screen_to_world(screen)
                if not source.is_finite():
                    check(main.map_view.view_camera.project_ray_normal(screen).y>=0,"sky returns no ground selection")
                    continue
                var error: float = main.world_to_screen(source).distance_to(screen)*float(root.size.x)/main.get_viewport_rect().size.x
                max_pick_pixels=maxf(max_pick_pixels,error)
                check(error<1.0,"ray hit reprojects to clicked pixel")
            if zoom==8.0:
                check(not main._screen_to_world(Vector2(640,0)).is_finite(),"800 percent exposes sky above the horizon")
                check(main.map_view.fine_surface.visible,"near measured geometry active")
                var near_vertices := 0
                if main.map_view.chunked_terrain:
                    for node in main.map_view.terrain_chunks.near_nodes.values(): near_vertices+=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
                else: near_vertices=main.map_view.fine_surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
                check(near_vertices>60000 if main.map_view.adaptive_terrain else near_vertices>130000,"near terrain retains dense detail and boundary samples")
            check(main.asset_stream.failed.is_empty(),"no failed assets")
            check(main.asset_stream.resident_bytes<=main.asset_stream.budget_bytes,"stream budget")
            var timings: Array = []
            var before := Time.get_ticks_usec()
            for i in 60:
                await process_frame
                var now := Time.get_ticks_usec()
                timings.append((now-before)/1000.0)
                before=now
            timings.sort()
            records.append({"region":region.name,"zoom":zoom,"angle":main.map_view.angle,"p95_ms":timings[56],"max_ms":timings[-1],"resident_bytes":main.asset_stream.resident_bytes,"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(output+"%s_%s_%d.png" % [stage,region.name,int(zoom*100)])
    main.camera.position=Vector2(4480,5504)
    main.set_map_zoom(2.0)
    await settle()
    var anchor_screen: Vector2 = main.get_viewport_rect().size*0.5+Vector2(260,170)
    var anchor: Vector2 = main._screen_to_world(anchor_screen)
    main._zoom_at(8.0,anchor_screen)
    var transition_times: Array = []
    var before := Time.get_ticks_usec()
    for i in 80:
        await process_frame
        var now := Time.get_ticks_usec()
        transition_times.append((now-before)/1000.0);before=now
        var error: float = main.world_to_screen(anchor).distance_to(anchor_screen)*float(root.size.x)/main.get_viewport_rect().size.x
        max_anchor_pixels=maxf(max_anchor_pixels,error)
        check(error<1.0,"cursor anchor through zoom and angle animation")
    check(is_equal_approx(main.camera.zoom.x,8.0),"zoom reaches latest requested target")
    if main.map_view.chunked_terrain:
        for node in main.map_view.terrain_chunks.far_nodes.values():
            check(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL].size()<=65*65,"lighting uses tiled geometry normals")
    else: check(main.map_view.surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL].size()==513*513,"lighting uses geometry normals")
    # Test the actual raster path as well as the camera/ray mathematics.
    var probe_screen := Vector2(780,440)
    var probe = preload("res://tests/base_map/godot/map_projection_probe.gd").new()
    probe.point=main._screen_to_world(probe_screen)
    probe.z_index=100
    main.map_view.source_root.add_child(probe)
    for i in 5: await process_frame
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
                centroid+=Vector2(x+0.5,y+0.5);count+=1
    check(count>20,"probe visible through 3D surface shader")
    var raster_error := INF if count==0 else (centroid/float(count)).distance_to(predicted)
    check(raster_error<1.0,"ground raster and screen marker align within one physical pixel")
    probe.queue_free()
    # Moving the real sun must change slope illumination without regenerating colour.
    main.camera.position=Vector2(4740,5504)
    main.set_map_zoom(8.0)
    await settle()
    await RenderingServer.frame_post_draw
    var lit_before := root.get_texture().get_image()
    var sun_rotation: Vector3 = main.map_view.sun.rotation
    main.map_view.sun.rotate_y(PI)
    for i in 5: await process_frame
    await RenderingServer.frame_post_draw
    var lit_after := root.get_texture().get_image()
    var lighting_change := 0.0
    for y in range(350,850,20):
        for x in range(450,1450,20):
            var a := lit_before.get_pixel(x,y)
            var b := lit_after.get_pixel(x,y)
            lighting_change += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
    check(lighting_change>10.0,"sun direction changes real slope lighting")
    main.map_view.sun.rotation=sun_rotation
    # Reference-like panorama: Fuji to the north, coast in the foreground.
    main.camera.position=Vector2(4785.24,5573.55)
    await settle()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+stage+"_fuji_800.png")
    var hud: Array = []
    for child in main.get_children():
        if child is CanvasLayer and child.visible:
            hud.append(child)
            child.hide()
    for i in 2: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+stage+"_fuji_map_only_800.png")
    var textured := root.get_texture().get_image()
    var surface_strength: float = main.map_view.surface_material.get_shader_parameter("material_strength")
    main.map_view.surface_material.set_shader_parameter("material_strength",0.0)
    main.map_view.fine_material.set_shader_parameter("material_strength",0.0)
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    var smooth := root.get_texture().get_image()
    smooth.save_png(output+stage+"_fuji_material_disabled.png")
    var material_difference := 0.0
    for y in range(350,850,10):
        for x in range(450,1450,10):
            var a := textured.get_pixel(x,y)
            var b := smooth.get_pixel(x,y)
            material_difference+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
    check(material_difference>30.0,"native materials visibly change the real rendered terrain")
    main.map_view.surface_material.set_shader_parameter("material_strength",surface_strength)
    main.map_view.fine_material.set_shader_parameter("material_strength",surface_strength)
    for child in hud: child.show()
    var offices: Node2D = main.district_office_layer
    var office_id: String = offices.records.keys()[0]
    var office_point: Vector2 = offices.office_point(office_id)
    main.camera.position=office_point
    main.map_view.sync(true)
    check(offices.pick(main._screen_to_world(main.world_to_screen(office_point)))==office_id,"office tile pick matches 3D anchor")
    main.army_campaign.units["view_probe"]={"house_id":session.player_house,"site_id":"district:"+office_id,"next_site":"","progress":0.0,"orders":[]}
    check(main.army_campaign.pick(main.world_to_screen(office_point))=="view_probe","army billboard pick follows 3D screen anchor")
    main.army_campaign.units.erase("view_probe")
    main.camera.position=Vector2(4480,5504)
    for percent in [600,800]:
        main._zoom_at(percent/100.0,main.get_viewport_rect().size*0.5)
        for i in 60: await process_frame
        check(is_equal_approx(main.camera.zoom.x,percent/100.0),"map zoom reaches requested percentage")
    var saved: Dictionary = session.capture(main)
    check(saved.camera.oblique,"save stores visible 3D mode")
    main.set_oblique(false);main.set_map_zoom(0.5)
    session.pending=saved
    session.apply_to(main)
    await settle()
    check(main.is_oblique() and is_equal_approx(main.camera.zoom.x,8.0),"current save restores mode and zoom")
    check(main.camera.position.distance_to(Vector2(saved.camera.x,saved.camera.y))<0.01,"save restores source center")
    main.developer_tools.open();main.developer_tools.set_contour_mode(true)
    for i in 3: await process_frame
    check(not main.is_oblique() and main.map_view.angle==90.0,"contour forces top-down view")
    check(main.developer_tools.contour_layer.get_viewport()==main.map_view.source_view,"contour uses geographic surface")
    main.developer_tools.close()
    await settle()
    check(main.is_oblique() and not main.developer_tools.contour_mode and main.tile_root.visible,"leaving developer mode restores map")
    main.set_oblique(false)
    check(main.map_view.angle==90.0,"flat toggle exact top-down")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+stage+"_flat_800.png")
    transition_times.sort()
    var settings := root.get_node("DisplaySettings")
    var original_resolution: int = settings.current_index
    for resolution in [0,1]:
        settings.apply_resolution(resolution,false)
        for i in 10: await process_frame
        var screen := Vector2(650,410)
        var point: Vector2 = main._screen_to_world(screen)
        var error: float = main.world_to_screen(point).distance_to(screen)*float(root.size.x)/main.get_viewport_rect().size.x
        check(error<1.0,"resize maintains physical pixel alignment")
    settings.apply_resolution(original_resolution,false)
    for i in 10: await process_frame
    var report := {"failures":failures,"max_pick_error_pixels":max_pick_pixels,"max_anchor_error_pixels":max_anchor_pixels,"raster_alignment_error_pixels":raster_error,"geometry_builds":main.map_view.geometry_builds,"atlas_size":[allocations.x,allocations.y],"transition_p95_ms":transition_times[75],"transition_max_ms":transition_times[-1],"states":records}
    var file := FileAccess.open(output+stage+"_results.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "));file.close()
    print("VIEW ANGLE QA: ","PASS" if failures==0 else "FAIL", "; ray error ",max_pick_pixels," pixels; anchor error ",max_anchor_pixels," pixels")
    quit(0 if failures==0 else 1)
