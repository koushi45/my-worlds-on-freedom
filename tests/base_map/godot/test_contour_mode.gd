extends SceneTree
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	printerr("FAIL: " + message)

func check_shader() -> void:
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var field := Image.create(256,64,false,Image.FORMAT_RGB8)
	for y in 64:
		for x in 256:
			var height := x*2
			field.set_pixel(x,y,Color(float(height/256)/255.0,float(height%256)/255.0,1.0 if y<48 else 0.0))
	var texture := ImageTexture.create_from_image(field)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/map/contour_map.gdshader")
	material.set_shader_parameter("height_field",texture)
	sprite.material = material
	viewport.add_child(sprite)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	for x in [25,50,75,100,125,150,175,200,225]:
		check(result.get_pixel(x,20).r < result.get_pixel(x-10,20).r-0.15,"synthetic terrain contours at each 50m")
	check(result.get_pixel(125,20).r < result.get_pixel(25,20).r-0.1,"250m index contours are darker")
	check(result.get_pixel(25,55).is_equal_approx(result.get_pixel(15,55)),"sea has no elevation contours")
	viewport.queue_free()

func run() -> void:
	await check_shader()
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline and (current_scene==null or current_scene.game_menu==null): await process_frame
	if current_scene==null or current_scene.game_menu==null: printerr("Map ready timed out"); quit(1); return
	var main = current_scene
	var dev = main.developer_tools
	var previous_tilt: bool = main.elevation.enabled
	dev.set_contour_mode(true)
	check(not dev.contour_mode and dev.contour_layer==null,"contours unavailable outside developer mode")
	dev.open()
	dev.set_contour_mode(true)
	check(dev.contour_layer.visible and not main.tile_root.visible,"contours replace normal basemap")
	check(not main.elevation.enabled,"contour view is north-up")
	check(dev.contour_layer.material.get_shader_parameter("interval_m")==50.0,"50 meter contour interval")
	main.set_oblique(true)
	check(not main.elevation.enabled,"cannot tilt contour basemap out of alignment")
	dev.set_road_editing(true)
	var focus: Vector2 = main.district_office_layer.office_point("kai/unresolved-c074c2107bc1fabe")
	main.set_map_zoom(4.0)
	main.camera.position = focus
	main._refresh_visible_tiles()
	check(dev.road_layer.is_visible_in_tree(),"road editing works with contour map")
	var cell := preload("res://scripts/map/hex_grid.gd").cell_at(focus)
	var had: bool = dev.network.cells.has(cell)
	dev.click_world(main._screen_to_world(main.get_viewport_rect().size*.5))
	check(dev.network.cells.has(cell)!=had,"contour picking uses the same hex coordinates")
	dev.network.undo()
	for frame in 20: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/developer_contours.png")
	dev.set_contour_mode(false)
	check(main.tile_root.visible and main.elevation.enabled==previous_tilt,"normal display and tilt restored")
	dev.set_contour_mode(true)
	dev.close()
	check(not dev.contour_mode and not dev.contour_layer.visible and main.tile_root.visible,"exiting developer mode removes contours")
	print("Contour mode tests: %d failures" % failures)
	quit(1 if failures else 0)
