extends SceneTree
var main: Node
var capture_dir := ""

func settled() -> bool:
	await process_frame
	var deadline:=Time.get_ticks_msec()+20000
	while main.has_pending_map_work():
		if Time.get_ticks_msec()>deadline:return false
		await process_frame
	await process_frame
	return true

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
	main=load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	if not await settled():quit(1);return
	if main.asset_stream.manifest.get("tiles",{}).size()!=504:
		printerr("FAIL: exported build disabled baked resources");quit(1);return
	if not main.district_layer.unconfirmed_mode or main.district_layer.records.size()!=709:
		printerr("FAIL: exported preview data");quit(1);return
	for tilt in [false,true]:
		main.set_oblique(tilt);main.set_map_zoom(4.0)
		main.camera.position=main.elevation.project(Vector2(3460,5880))
		if not await settled():quit(1);return
		main.district_layer.select_key("izumi/candidate-district-candidate-g04003")
		var deadline:=Time.get_ticks_msec()+20000
		while main.district_layer.fill_mesh()==null:
			if Time.get_ticks_msec()>deadline:printerr("FAIL: exported district fill");quit(1);return
			await process_frame
		if main.asset_stream.failed.size()>0 or main.asset_stream.resident_bytes>main.asset_stream.budget_bytes:
			printerr("FAIL: exported streaming");quit(1);return
		await process_frame
		await RenderingServer.frame_post_draw
		if not capture_dir.is_empty():
			root.get_texture().get_image().save_png(capture_dir+"/export_"+("tilt" if tilt else "flat")+".png")
	print("EXPORT PERFORMANCE QA: PASS; baked tiles, preview, 400%, both ground fills, cache budget")
	quit(0)
