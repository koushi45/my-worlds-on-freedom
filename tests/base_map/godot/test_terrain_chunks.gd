extends SceneTree
var failures := 0
var main: Node
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
    if not value:
        failures+=1
        printerr("FAIL: ",message)
func settle() -> void:
    var deadline := Time.get_ticks_msec()+60000
    for i in 30: await process_frame
    while main.has_pending_map_work() and Time.get_ticks_msec()<deadline: await process_frame
    check(not main.has_pending_map_work(),"terrain jobs settle")
func run() -> void:
    Engine.max_fps=60
    root.get_node("GameSession").new_game("oda_nobuhide")
    var deadline := Time.get_ticks_msec()+60000
    while current_scene==null or not current_scene.get("initialized"):
        if Time.get_ticks_msec()>deadline: quit(1); return
        await process_frame
    main=current_scene
    main.game_clock.set_process(false)
    var view: Node=main.map_view
    var chunks: RefCounted=view.terrain_chunks
    check(view.chunked_terrain,"chunk manifest accepted")
    main.camera.position=Vector2(4480,5504)
    main.set_map_zoom(8.0)
    await settle()
    if view.adaptive_terrain:
        var pose: Transform3D=view.view_camera.global_transform
        view.view_camera.position=Vector3(0,10000,10000)
        view.view_camera.look_at(Vector3.ZERO,Vector3.UP)
        var distant: float=chunks._coarse_pixel_error(Rect2(4096,4096,1024,1024),0.25)
        view.view_camera.position=Vector3(0,100,100)
        view.view_camera.look_at(Vector3.ZERO,Vector3.UP)
        var close: float=chunks._coarse_pixel_error(Rect2(4096,4096,1024,1024),0.25)
        view.view_camera.global_transform=pose
        check(distant<0.35 and close>distant,"distance-dependent projected error selects coarser distant terrain")
    var adaptive: bool=view.adaptive_terrain
    view.adaptive_terrain=false
    var full: Array=view._geometry_arrays(view.fine_rect,2.0,true)
    view.adaptive_terrain=adaptive
    var reference := ArrayMesh.new()
    reference.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,full)
    full=reference.surface_get_arrays(0)
    var columns := int(view.fine_rect.size.x/2)+1
    var compared := 0
    for key in chunks.near_nodes:
        var region: Rect2=chunks.active_keys[key]
        var actual: Array=chunks.near_nodes[key].mesh.surface_get_arrays(0)
        for i in actual[Mesh.ARRAY_VERTEX].size():
            var vertex: Vector3=actual[Mesh.ARRAY_VERTEX][i]
            var grid := Vector2i((Vector2(vertex.x,vertex.z)+Vector2(4096,4096)-view.fine_rect.position)/2)
            var index := grid.y*columns+grid.x
            check(vertex==full[Mesh.ARRAY_VERTEX][index],"unchanged near vertex including seam")
            check(actual[Mesh.ARRAY_NORMAL][i].distance_to(full[Mesh.ARRAY_NORMAL][index])<0.000001,"unchanged near normal including halo")
            check(actual[Mesh.ARRAY_TEX_UV][i]==full[Mesh.ARRAY_TEX_UV][index],"unchanged UV")
            compared+=1
    var reused := 0
    var old_keys: Dictionary=chunks.active_keys.duplicate()
    var before_builds: int=chunks.near_builds
    main.camera.position.x+=128
    await settle()
    for key in chunks.active_keys:
        if old_keys.has(key): reused+=1
    check(reused>=8,"neighbor movement reuses unchanged tiles")
    check(chunks.near_builds-before_builds<=24,"only exposed/morphed tiles generated")
    check(chunks.near_cache.size()<=64,"bounded mesh cache")
    var before_orbit: int=chunks.near_builds
    for heading in [90.0,180.0,270.0,0.0]:
        view.yaw=heading
        await settle()
    check(chunks.near_builds==before_orbit,"orbit never regenerates same near terrain")
    check(chunks.far_nodes.size()<64,"offscreen far mesh data not retained at 800 percent")
    check(chunks.far_releases>0,"far data released after leaving view")
    main.set_map_zoom(1.0)
    await settle()
    check(chunks.near_cache.is_empty() and chunks.near_nodes.is_empty(),"near meshes released when disabled")
    print("TERRAIN_CHUNKS ","PASS" if failures==0 else "FAIL"," exact_vertices=",compared," reused_tiles=",reused," far_loads=",chunks.far_loads," far_releases=",chunks.far_releases)
    quit(0 if failures==0 else 1)
