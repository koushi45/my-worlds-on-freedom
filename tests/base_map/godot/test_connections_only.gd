extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr(message)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _initialize() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var renderer = main.shared_road_layer
	check(not FileAccess.file_exists("res://data/derived/roads/roads_1582.json"),"retired road data absent")
	check(not main.has_node("HistoricalRoads1582"),"retired road layer absent")
	for node in main.find_children("*","Button",true,false):
		check(node.text not in ["1582年の道","全国の道","佐土原の道"],"retired road controls absent")
	for stroke in renderer.data["strokes"]:
		check(not stroke.has("historical_ids") and not stroke["connection_ids"].is_empty(),"only connection memberships remain")
	for oblique in [false,true]:
		main.set_oblique(oblique)
		main.focus_road_region("sites:tokai")
		main.camera.position = main.elevation.project(Vector2(4130,5560))
		main.camera.zoom = Vector2(1.25,1.25)
		await frame()
		check(renderer.drawn_strokes > 0,"connections visible")
		root.get_texture().get_image().save_png("res://builds/connections_only_%s.png" % ("oblique" if oblique else "flat"))
	main.focus_road_region("all")
	main.connection_layer.select_route(main.connection_layer.data["routes"][0]["id"])
	await frame()
	check(renderer.active_strokes > 0,"selected route highlights shared geometry")
	main.connection_layer.hide()
	await frame()
	check(renderer.drawn_strokes == 0,"connections toggle hides every road")
	check(main.settlement_layer.visible and main.river_layer.visible and main.lake_layer.visible,"other layers unaffected")
	main.connection_layer.show()
	await frame()
	check(renderer.active_strokes > 0,"selection restored on show")
	print("CONNECTIONS ONLY TEST: "+("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)
