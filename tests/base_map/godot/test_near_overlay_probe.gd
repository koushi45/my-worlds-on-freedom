extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        printerr("FAIL: ",message)

func segment_key(a: Vector2, b: Vector2) -> String:
    var first := str(a)
    var second := str(b)
    return first+":"+second if first<second else second+":"+first

func _initialize() -> void: call_deferred("run")

func run() -> void:
    root.get_node("GameSession").new_game("oda_nobuhide")
    var deadline := Time.get_ticks_msec()+60000
    while current_scene==null or not current_scene.get("initialized"):
        if Time.get_ticks_msec()>deadline: quit(1); return
        await process_frame
    var main: Node = current_scene
    var view: Node = main.map_view
    main.game_clock.set_process(false)
    main.set_map_zoom(8.0)
    main.camera.position = Vector2(4480,5504)
    view.manual_angle = 15.0
    for i in 30: await process_frame
    deadline = Time.get_ticks_msec()+60000
    while main.has_pending_map_work() and Time.get_ticks_msec()<deadline: await process_frame
    check(not main.has_pending_map_work(),"assets settled")
    var tested_markers := 0
    var sample := Vector2(INF,INF)
    for id in main.district_office_layer.records:
        var point: Vector2 = main.district_office_layer.office_point(id)
        if point.distance_to(main.camera.position)>320.0: continue
        view.set_meta("probe_marker_radius",0.0)
        view.marker_visibility.clear()
        var original: bool = view.marker_visible(point)
        view.set_meta("probe_marker_radius",320.0)
        view.marker_visibility.clear()
        check(view.marker_visible(point)==original,"near marker retains exact visibility")
        tested_markers += 1
        if main.get_viewport_rect().grow(-4).has_point(view.project(point)): sample = point
    check(tested_markers>0,"near markers tested")
    var office_id: String = main.district_office_layer.records.keys()[0]
    main.show_district_info(office_id)
    check(view.markers.office_selected(office_id),"office panel selection is a distance exception")
    main.district_info.hide_info()
    check(not view.markers.office_selected(office_id),"closing office panel removes exception")
    check(sample.is_finite(),"onscreen near marker available")
    if sample.is_finite():
        view.set_meta("probe_marker_radius",1.0)
        check(not view.marker_visible(sample),"far unselected marker is limited")
        var selected_visible: bool = view.marker_visible(sample,true)
        view.set_meta("probe_marker_radius",0.0)
        check(selected_visible==view.marker_visible(sample,true),"selected marker bypasses radius")
        view.set_meta("probe_occlusion_interval",100)
        view.marker_visibility.clear()
        var original: bool = view.marker_visible(sample)
        var calls: int = view.marker_occlusion_calls
        view.marker_visibility.clear()
        check(view.marker_visible(sample)==original,"cached visibility retained")
        check(view.marker_occlusion_calls==calls,"temporal cache skips repeated ray")
        view.marker_visible(sample,true)
        check(view.marker_occlusion_calls==calls+1,"selected marker bypasses approximate visibility")
        calls = view.marker_occlusion_calls
        view.marker_visible(sample,false,"",true)
        check(view.marker_occlusion_calls==calls+1,"click visibility bypasses approximate visibility")
        calls = view.marker_occlusion_calls
        view.temporal_visibility[sample].time -= 101
        view.marker_visibility.clear()
        view.marker_visible(sample)
        check(view.marker_occlusion_calls==calls+1,"expired visibility rechecks ray")
        view.marker_visibility.clear()
        view.marker_visible(sample)
        check(view.marker_refresh_at>0,"cached visibility schedules final refresh")
        view.marker_refresh_at = Time.get_ticks_msec()-1
        view.advance(0.0)
        check(view.marker_refresh_at==0,"idle camera consumes refresh deadline")
    var hex: Node = main.hex_tile_layer
    hex._draw_mesh_chunks(0.3)
    var chunk_key: Vector2i = hex.mesh_chunks.keys()[0]
    var retained: Node = hex.mesh_chunks[chunk_key]
    var retained_mesh: Mesh = retained.mesh
    hex._draw_mesh_chunks(0.3)
    check(hex.mesh_chunks[chunk_key]==retained and retained.mesh==retained_mesh,"stationary hex geometry reused")
    var segments := {}
    for node in hex.mesh_chunks.values():
        var points: PackedVector2Array = node.last_segments
        for i in range(0,points.size(),2): segments[segment_key(points[i],points[i+1])] = true
    var edges := 0
    for cell in hex.visible_cells:
        var center: Vector2 = hex.Grid.center(cell)
        if center.distance_to(main.camera.position)>160.0 or not hex.bounds.grow(-12.0).has_point(center): continue
        var polygon: PackedVector2Array = hex.Grid.polygon(cell)
        for edge in 6:
            if edge>=3 and hex.visible_cells.has(cell+hex.EDGE_NEIGHBORS[edge]): continue
            var a: Vector2 = main.elevation.project(polygon[edge])
            var b: Vector2 = main.elevation.project(polygon[(edge+1)%6])
            check(segments.has(segment_key(a,b)),"near hex edge retains original endpoints")
            edges += 1
    check(edges>0,"near hex edges tested")
    for i in 80:
        hex.bounds = Rect2(Vector2((i%10)*256,(i/10)*256),Vector2.ONE*128.0)
        hex._draw_mesh_chunks(0.3)
    check(hex.mesh_chunks.size()<=64,"hex mesh cache bounded")
    hex.bounds = Rect2(Vector2(4096,4096),Vector2(2048,1024))
    hex._draw_mesh_chunks(0.3)
    check(hex.mesh_chunks.size()<=64,"zoomed out mesh cache bounded")
    check(hex.mesh_chunk_side>128.0,"zoomed out mesh adapts chunk size")
    main.set_process(false)
    for i in 2: await process_frame
    print("NEAR_OVERLAY_PROBE ","PASS" if failures==0 else "FAIL"," near_markers=",tested_markers," near_edges=",edges," chunks=",hex.mesh_chunks.size())
    quit(0 if failures==0 else 1)
