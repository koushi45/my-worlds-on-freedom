extends SceneTree
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message);printerr("FAIL: "+message)
func _initialize() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var layer = main.settlement_layer
	main.settlement_panel.refresh_list()
	check(main.settlement_panel.matches.size()==254,"254 independent adopted places loaded")
	check(not layer.eligible(layer.lookup["kagoshima_port"]),"merged port not duplicated")
	main.settlement_panel.search.text="kagoshima_port"
	main.settlement_panel.refresh_list()
	check(main.settlement_panel.matches==["uchi_castle"],"merged alias finds compound place")
	main.settlement_panel.search.text=""
	check(not layer.eligible(layer.lookup["takaoka_castle_late"]),"later castle excluded")
	check(not layer.eligible(layer.lookup["tonokori_castle"]),"unresolved site hidden by default")
	layer.show_deferred=true
	check(layer.eligible(layer.lookup["tonokori_castle"]),"deferred research overlay available")
	layer.show_deferred=false
	layer.set_role(false,"castle")
	check(not layer.eligible(layer.lookup["sadowara_castle"]),"castle filter")
	check(layer.eligible(layer.lookup["bonotsu_port"]),"ports remain after castle filter")
	layer.set_role(true,"castle")
	main.settlement_panel.search.text="sadowara"
	main.settlement_panel.refresh_list()
	check(main.settlement_panel.matches==["sadowara_castle"],"search by legacy id")
	for oblique in [false,true]:
		main.set_oblique(oblique)
		main.focus_road_region("sites:south_kyushu")
		await process_frame
		await process_frame
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			check(layer.drawn_ids.size()>8,"southern sites actually rendered")
			root.get_texture().get_image().save_png("res://builds/windows-latest/qa/settlements_south_%s.png" % ("oblique" if oblique else "flat"))
	main.settlement_panel.focus_site("uchi_castle")
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check("uchi_castle" in layer.labeled_ids,"selected site name remains readable")
		var screen: Vector2=layer.get_global_transform_with_canvas()*main.elevation.project(layer.point(layer.lookup["uchi_castle"]["point"]))
		check(layer.pick(screen)=="uchi_castle","screen hit test follows elevation")
		root.get_texture().get_image().save_png("res://builds/windows-latest/qa/settlements_kagoshima.png")
		main.settlement_panel.show_site("uchi_castle")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/windows-latest/qa/settlements_details.png")
		main.settlement_panel.browser.hide()
		for oblique in [false,true]:
			main.set_oblique(oblique)
			for region in ["kyushu","kinki","tohoku","hokkaido","kanto","koshin","hokuriku","tokai","chugoku","shikoku"]:
				main.focus_road_region("sites:"+region)
				await process_frame
				await RenderingServer.frame_post_draw
				check(layer.drawn_ids.size()>0,"regional sites rendered: "+region)
				root.get_texture().get_image().save_png("res://builds/windows-latest/qa/settlements_%s_%s.png" % [region,"oblique" if oblique else "flat"])
	layer.hide()
	check(main.river_layer.visible and main.lake_layer.visible,"independent layer visibility")
	check(layer.pick(Vector2(800,360)).is_empty(),"hidden layer has no hit targets")
	for level in range(5):
		main._set_lod(level,Vector2(800,360))
		await process_frame
		check(is_equal_approx(layer.view_zoom,main.camera.zoom.x),"LOD propagated")
	if failures.is_empty():print("PASS: settlement filters, research view, search, focus, picking, terrain projection and LOD")
	quit(0 if failures.is_empty() else 1)
