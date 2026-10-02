extends SceneTree
var main: Node
var stage := "A"
var failures := 0
var stats: Array = []
var output := ""
var source_root := ""
func check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        printerr("FAIL: ",message)
func settled() -> void:
    await process_frame
    var deadline := Time.get_ticks_msec()+30000
    while main.has_pending_map_work() and Time.get_ticks_msec()<deadline: await process_frame
    check(not main.has_pending_map_work(), "streaming settled")
    for frame in 8: await process_frame
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--stage="): stage=arg.trim_prefix("--stage=")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=").trim_suffix("/")+"/"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--source-root="): source_root=arg.trim_prefix("--source-root=")
    if source_root.is_empty(): source_root=ProjectSettings.globalize_path("res://")
    if output.is_empty(): output=ProjectSettings.globalize_path("res://builds/qa/map_appearance/")
    DirAccess.make_dir_recursive_absolute(output)
    call_deferred("run")
func run() -> void:
    var session = root.get_node("GameSession")
    check(session.new_game("uesugi_yamanouchi")==OK,"new game")
    var deadline:=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and (current_scene==null or not current_scene.initialized):await process_frame
    if current_scene==null or not current_scene.initialized: quit(1);return
    main=current_scene
    main.set_process_input(false);main.set_process_unhandled_input(false);root.gui_disable_input=true
    main.game_clock.set_process(false)
    for region in [{"id":"mixed","point":Vector2(4480,5504)},{"id":"forest","point":Vector2(4740,5504)},{"id":"coast","point":Vector2(3460,5880)}]:
        for tilt in [false,true]:
            main.set_oblique(tilt)
            for zoom in ([2.0,4.0,6.0,8.0] if region.id=="mixed" else [4.0]):
                main.camera.position=main.elevation.project(region.point)
                main.set_map_zoom(zoom);main.camera.force_update_scroll()
                await settled()
                check(main.asset_stream.failed.is_empty(),"no failed assets")
                check(main.asset_stream.resident_bytes<=main.asset_stream.budget_bytes,"stream memory budget")
                if region.id=="mixed":
                    var center_tile=main.loaded_tiles.get("detail-r21-c17")
                    check(center_tile!=null and center_tile.relief.get_width()==(2064 if zoom>=4 else 1032),"native central texture size")
                var frames: Array = []
                for frame in 60:
                    var start:=Time.get_ticks_usec()
                    await process_frame
                    frames.append((Time.get_ticks_usec()-start)/1000.0)
                frames.sort()
                stats.append({"region":region.id,"tilt":tilt,"zoom":zoom,"samples":frames.size(),"frame_p95_ms":frames[56],"frame_max_ms":frames[-1],"stream_bytes":main.asset_stream.resident_bytes,"budget_bytes":main.asset_stream.budget_bytes,"renderer_video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)})
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png(output+"%s_%s_%d_%s.png" % [stage,region.id,int(zoom*100),"tilt" if tilt else "flat"])
    # Probe both exact texture thresholds and revisit already displayed regions.
    main.set_oblique(false);main.camera.position=Vector2(4480,5504)
    for zoom in [2.49,2.5,3.99,4.0,8.0,3.99,2.49]:
        main.set_map_zoom(zoom);await settled()
        var tile=main.loaded_tiles.get("detail-r21-c17")
        check(tile!=null,"threshold tile loaded")
        if tile!=null:check(tile.relief.get_width()==(2064 if zoom>=4 else 1548 if zoom>=2.5 else 1032),"threshold texture size")
    # Compare the texture actually displayed by the game with the source PNG.
    # Do this after timing, without retaining an extra baked chunk during traversal.
    main.set_map_zoom(8.0)
    await settled()
    var displayed=main.loaded_tiles.get("detail-r21-c17")
    var raw=Image.load_from_file(source_root.path_join("assets/map/detail/detail-r21-c17-high.png"))
    var imported: Image=displayed.relief.get_image()
    raw.convert(Image.FORMAT_RGB8);imported.convert(Image.FORMAT_RGB8)
    check(raw.get_data()==imported.get_data(),"runtime displays the current source pixels")
    var report={"stage":stage,"pid":OS.get_process_id(),"failures":failures,"stats":stats,"gpu_memory_note":"Godot renderer allocation monitor, not total device VRAM; zero means unavailable"}
    var file:=FileAccess.open(output+stage+"_runtime.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "))
    print("APPEARANCE QA ",stage,": ","PASS" if failures==0 else "FAIL")
    quit(0 if failures==0 else 1)
