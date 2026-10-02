extends SceneTree
var main: Node
var failures := 0
func _initialize() -> void: call_deferred("run")
func settle() -> void:
    var deadline := Time.get_ticks_msec()+60000
    for i in 30: await process_frame
    while main.has_pending_map_work() and Time.get_ticks_msec()<deadline: await process_frame
func run() -> void:
    Engine.max_fps=60
    root.size=Vector2i(1920,1080)
    root.get_node("GameSession").new_game("oda_nobuhide")
    var deadline := Time.get_ticks_msec()+60000
    while current_scene==null or not current_scene.get("initialized"):
        if Time.get_ticks_msec()>deadline: quit(1); return
        await process_frame
    main=current_scene
    main.game_clock.set_process(false)
    main.set_process_input(false)
    main.set_process_unhandled_input(false)
    root.gui_disable_input=true
    var view: Node=main.map_view
    var far := MeshInstance3D.new()
    far.mesh=view._baked_terrain("far",Rect2(0,0,8192,8192),16).mesh
    far.material_override=view.surface_material
    far.visible=false
    view.add_child(far)
    var near := MeshInstance3D.new()
    near.material_override=view.fine_material
    near.visible=false
    view.add_child(near)
    var cases: Array=[]
    for center in [Vector2(4480,5504),Vector2(4768,5440),Vector2(5500,4100)]:
        for heading in [0.0,90.0,180.0,270.0]: cases.append({"center":center,"heading":heading,"zoom":8.0,"angle":15.0})
    cases.append({"center":Vector2(4096,4096),"heading":0.0,"zoom":0.5,"angle":90.0})
    var reports: Array=[]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/performance_800/chunk_culling"))
    for i in cases.size():
        main.set_process(true)
        var entry: Dictionary=cases[i]
        main.camera.position=entry.center
        main.set_map_zoom(entry.zoom)
        view.manual_angle=entry.angle
        view.yaw=entry.heading
        await settle()
        main.set_process(false)
        view.source_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
        if view.fine_surface.visible:
            near.mesh=ArrayMesh.new()
            near.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,view._geometry_arrays(view.fine_rect,2.0,true))
        for j in 2: await RenderingServer.frame_post_draw
        var tiled: Image=root.get_texture().get_image()
        var fine_active: bool=view.fine_surface.visible
        view.surface.hide()
        view.fine_surface.hide()
        far.show()
        near.visible=fine_active
        for j in 2: await RenderingServer.frame_post_draw
        var original: Image=root.get_texture().get_image()
        var identical := tiled.get_data()==original.get_data()
        reports.append({"index":i,"yaw":entry.heading,"zoom":entry.zoom,"identical":identical,"far_tiles":view.terrain_chunks.far_nodes.size()})
        if not identical:
            tiled.save_png("res://builds/performance_800/chunk_culling/%d_tiled.png" % i)
            original.save_png("res://builds/performance_800/chunk_culling/%d_original.png" % i)
            failures+=1
            printerr("FAIL: terrain frustum/shadow raster differs at pose ",i)
        far.hide()
        near.hide()
        view.surface.show()
        view.fine_surface.visible=fine_active
        view.source_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    var report := FileAccess.open("res://builds/performance_800/chunk_culling/report.json",FileAccess.WRITE)
    report.store_string(JSON.stringify(reports,"  "))
    print("TERRAIN_CULLING ","PASS" if failures==0 else "FAIL"," full_frame_comparisons=",cases.size())
    quit(0 if failures==0 else 1)
