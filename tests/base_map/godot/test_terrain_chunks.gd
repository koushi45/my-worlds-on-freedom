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
    var original_normals: PackedVector3Array = full[Mesh.ARRAY_NORMAL].duplicate()
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
            var point := Vector2(vertex.x,vertex.z)+Vector2(4096,4096)
            var edge := minf(minf(point.x-view.fine_rect.position.x,view.fine_rect.end.x-point.x),minf(point.y-view.fine_rect.position.y,view.fine_rect.end.y-point.y))
            var height := lerpf(actual[Mesh.ARRAY_TEX_UV2][i].x,vertex.y,smoothstep(0.0,32.0,edge))
            var expected: Vector3 = full[Mesh.ARRAY_VERTEX][index]
            check(absf(height-expected.y)<0.00001,"GPU boundary height matches geographic pick height")
            var neighbor_heights: Array[float] = []
            for n in 4:
                var offset: Vector2 = [Vector2(-2,0),Vector2(2,0),Vector2(0,-2),Vector2(0,2)][n]
                var p := point+offset
                var distance := minf(minf(p.x-view.fine_rect.position.x,view.fine_rect.end.x-p.x),minf(p.y-view.fine_rect.position.y,view.fine_rect.end.y-p.y))
                neighbor_heights.append(lerpf(actual[Mesh.ARRAY_CUSTOM1][i*4+n],actual[Mesh.ARRAY_CUSTOM0][i*4+n],smoothstep(0.0,32.0,distance)))
            var normal := Vector3(neighbor_heights[0]-neighbor_heights[1],4.0,neighbor_heights[2]-neighbor_heights[3]).normalized()
            check(normal.distance_to(original_normals[index])<0.00002,"GPU boundary normal matches original normal including halo")
            check(actual[Mesh.ARRAY_TEX_UV][i]==full[Mesh.ARRAY_TEX_UV][index],"unchanged UV")
            compared+=1
    var reused := 0
    var old_keys: Dictionary=chunks.active_keys.duplicate()
    var before_builds: int=chunks.near_builds
    main.camera.position.x+=128
    await settle()
    for key in chunks.active_keys:
        if old_keys.has(key): reused+=1
    check(reused==24,"neighbor movement reuses all 24 overlapping tiles")
    check(chunks.near_builds-before_builds==8,"only 8 exposed tiles generated")
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
