extends SceneTree
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: "+message)

func _initialize() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
	check(main.river_layer.initialized and main.lake_layer.initialized,"water layers initialized")
	check(main.river_layer.records.size()>4000 and main.lake_layer.records.size()>600,"national coverage retained")
	var shown := 0
	var hidden := 0
	for record in main.river_layer.records:
		if record.get("visible_by_default",false): shown += 1
		else: hidden += 1
	check(shown>100 and hidden>3000,"only major main stems enabled")
	for record in main.lake_layer.records:
		check(int(record["source_type"])!=1,"river areas excluded from lake toggle")
	check(main.river_layer.z_index<main.political_layer.z_index,"political borders readable above water")
	main.focus_biwa()
	await process_frame
	var lake: Dictionary
	for record in main.lake_layer.records:
		if record["name"]=="BIWA KO": lake=record
	check(not lake.is_empty(),"Biwa polygon present")
	var source := Vector2(float(lake["label_point"][0]),float(lake["label_point"][1]))
	check(main.get_visible_world_rect().has_point(source),"Biwa focus")
	var mesh: ArrayMesh = main.lake_layer.surface_for(lake)["mesh"]
	var vertices: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,vertices.size(),3):
		var mid := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
		var ground: Vector2 = (main.elevation.unproject(vertices[i])+main.elevation.unproject(vertices[i+1])+main.elevation.unproject(vertices[i+2]))/3.0
		check(mid.distance_to(main.elevation.project(ground))<0.02,"lake triangle conforms to terrain")
	for level in range(5):
		main._set_lod(level,Vector2(640,360))
		await process_frame
		check(is_equal_approx(main.river_layer.view_zoom,main.camera.zoom.x),"river zoom follows camera")
	main.river_layer.hide()
	check(main.lake_layer.visible,"river toggle independent of lakes")
	main.lake_layer.hide()
	check(main.elevation.relief_visible,"water toggle independent of elevation")
	main.river_layer.show()
	main.lake_layer.show()
	main.set_oblique(false)
	check(main.lake_layer.surface_cache.is_empty(),"flat view invalidates water projection cache")
	main.set_oblique(true)
	main.focus_biwa()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa"))
		await RenderingServer.frame_post_draw
		check(main.lake_layer.draw_count>0 and main.river_layer.draw_count>0,"visible water drawn")
		root.get_texture().get_image().save_png("res://builds/qa/water_biwa.png")
		main.focus_kyushu()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/water_kyushu.png")
		main.set_oblique(false)
		main.focus_biwa()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/water_biwa_flat.png")
	if failures.is_empty(): print("PASS: rivers, lakes, Biwa focus, independent toggles, terrain conformity, 5 LODs")
	quit(0 if failures.is_empty() else 1)
