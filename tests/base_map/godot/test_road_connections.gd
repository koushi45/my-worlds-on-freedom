extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message);printerr("FAIL: "+message)
func _initialize() -> void:
	var main=load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var layer=main.connection_layer
	check(not FileAccess.file_exists("res://data/derived/roads/roads_1582.json"),"retired roads absent from runtime package")
	check(not main.has_node("HistoricalRoads1582"),"retired road layer absent")
	check(layer.site_connections.size()==254,"all 254 statuses loaded")
	check(layer.data["routes"].size()>200,"regional connections loaded")
	main.connection_panel.search.text="佐土原"
	main.connection_panel.refresh()
	check(main.connection_panel.matches.size()>0,"route search")
	main.connection_panel.select_index(0)
	main.connection_panel.focus_current()
	check(not layer.selected_id.is_empty(),"route selected")
	check(not main.connection_panel.browser.visible,"route focus dismisses dialog")
	for oblique in [false,true]:
		main.set_oblique(oblique)
		for region in ["south_kyushu","kyushu","chugoku","shikoku","kinki","tokai","koshin","kanto","hokuriku","tohoku","hokkaido"]:
			main.focus_road_region("sites:"+region)
			await process_frame
			await process_frame
			if "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				if region!="hokkaido": check(layer.drawn_segments>0,"roads rendered "+region)
				root.get_texture().get_image().save_png("res://builds/windows-latest/qa/connections_%s_%s.png" % [region,"oblique" if oblique else "flat"])
	main.connection_panel.focus_current()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(layer.selected_waypoint_count>0,"visible numbered waypoints")
		root.get_texture().get_image().save_png("res://builds/windows-latest/qa/connections_selected.png")
	main.settlement_panel.show_site("sadowara_castle")
	check("道路接続" in main.settlement_panel.details.text,"site connection status in details")
	main.settlement_panel.browser.hide()
	for level in range(5):
		main._set_lod(level,Vector2(800,360))
		await process_frame
		check(is_equal_approx(layer.view_zoom,main.camera.zoom.x),"five LOD propagated")
	layer.hide()
	check(main.river_layer.visible and main.lake_layer.visible and main.settlement_layer.visible,"independent overlay visibility")
	layer.show()
	check(layer.visible,"old corridors independent")
	print("ROAD CONNECTION TEST: "+("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)
