extends SceneTree
const Wait=preload("res://tests/base_map/godot/wait_map.gd")

func check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: "+message)
		quit(1)
		assert(condition,message)

func _initialize() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await Wait.settled(main)
	var surface: RefCounted = main.elevation
	var max_error := 0.0
	for y in range(0,8193,43):
		for x in range(0,8193,59):
			var point := Vector2(x,y)
			max_error = maxf(max_error,point.distance_to(surface.unproject(surface.project(point))))
	check(max_error<0.01,"display/picking inverse accuracy")
	var changed := false
	for region in main.political_layer.data["regions"]:
		for polygon in region["polygons"]:
			var line: PackedVector2Array = main.political_layer.to_points(polygon)
			var display: PackedVector2Array = surface.project_line(line)
			for i in range(display.size()-1):
				var mid := (display[i]+display[i+1])*0.5
				var a: Vector2 = surface.unproject(display[i])
				var b: Vector2 = surface.unproject(display[i+1])
				check(mid.distance_to(surface.project((a+b)*0.5))<0.02,"border follows mesh triangle")
				if surface.elevation_at(a)>300: changed = true
	check(changed,"actual mountainous vertices present")
	for level in range(5):
		main._set_lod(level,Vector2(640,360))
		await process_frame
		await Wait.settled(main)
		check(not main.loaded_tiles.is_empty(),"LOD tiles finished loading")
		for tile in main.loaded_tiles.values():
			if tile.has_method("set_view_zoom"):
				check(tile.mesh != null and tile.relief != null,"detail land and relief share clipped terrain mesh")
			else:
				check(tile.mesh == tile.get_node("Elevation").mesh,"relief shares displaced base mesh")
				check(tile.get_node("Elevation").texture != null,"all LOD relief resources loaded")
	main.set_relief_visible(false)
	for tile in main.loaded_tiles.values():
		if tile.has_method("set_view_zoom"): check(not tile.elevation.relief_visible,"independent detail relief toggle")
		else: check(not tile.get_node("Elevation").visible,"independent relief toggle")
	main.set_oblique(false)
	check(surface.project(Vector2(3500,5000))==Vector2(3500,5000),"flat toggle restores original coordinates")
	main.set_relief_visible(true)
	main.set_oblique(true)
	main.focus_kyushu()
	await process_frame
	await process_frame
	await Wait.settled(main)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/elevation_kyushu.png")
		main.focus_region("honshu")
		main._set_lod(3,Vector2(640,360))
		main.camera.position = surface.project(Vector2(4070,4850))
		main._refresh_visible_tiles()
		await process_frame
		await Wait.settled(main)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/elevation_mountains.png")
		main.set_oblique(false)
		await process_frame
		await Wait.settled(main)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/elevation_flat.png")
	print("PASS: elevation mesh, 5 LODs, layer toggles, border adherence, inverse picking; max error ",max_error)
	quit(0)
