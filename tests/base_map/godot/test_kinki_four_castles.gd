extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr(message)

func _initialize() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ids := ["kishiwada_castle","ishiyama_honganji","takaya_castle","tsutsui_castle"]
	for id in ids:
		var site: Dictionary = main.settlement_layer.lookup[id]
		check(site["roles"] == ["castle"],"castle icon classification "+id)
		check(main.connection_layer.site_connections[id]["status"] == "connected","connected "+id)
		main.settlement_panel.search.text = site["display_name"]
		main.settlement_panel.refresh_list()
		check(id in main.settlement_panel.matches,"searchable "+id)
		main.settlement_panel.show_site(id)
		check(site["temporal_note"] in main.settlement_panel.details.text,"history note visible "+id)
	main.settlement_panel.browser.hide()
	main.settlement_layer.selected_id = ""
	for oblique in [false,true]:
		main.set_oblique(oblique)
		main.road_focus_active = false
		main.lod_level = 4
		main._apply_lod(true)
		var first := true
		var bounds := Rect2()
		for id in ids:
			var p: Vector2 = main.elevation.project(main.settlement_layer.point(main.settlement_layer.lookup[id]["point"]))
			if first: bounds = Rect2(p,Vector2.ZERO); first = false
			else: bounds = bounds.expand(p)
		bounds = bounds.grow(30)
		var available := Vector2(740,480)
		var zoom_value := minf(available.x/bounds.size.x,available.y/bounds.size.y)
		main.camera.zoom = Vector2.ONE*zoom_value
		main.camera.position = bounds.get_center()-Vector2(185/zoom_value,0)
		await process_frame
		await process_frame
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			for id in ids: check(id in main.settlement_layer.labeled_ids,"visible label "+id)
			root.get_texture().get_image().save_png("res://builds/kinki_four_%s.png" % ("oblique" if oblique else "flat"))
	print("KINKI FOUR CASTLES: "+("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)
