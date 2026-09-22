extends SceneTree

func _initialize() -> void:
	var packed := load("res://tools/review/kyushu_registration.tscn") as PackedScene
	assert(packed != null)
	var viewer = packed.instantiate()
	root.add_child(viewer)
	await process_frame
	await process_frame
	assert(viewer.initialized)
	assert(viewer.boundary_points.size() == 15)
	assert(viewer.coast_points.size() == 1)
	assert(viewer.click_polygons.size() == 9)
	for id in viewer.click_polygons:
		assert(viewer.selection_lines(id).size() >= 3)
	assert(viewer.hit_test(Vector2.ZERO) == "")
	# Bungo's main inland point is inside its labelled face.
	assert(viewer.hit_test(Vector2(1900, 6500)) == "bungo")
	viewer.selected_id = "bungo"
	viewer.update_label()
	viewer.queue_redraw()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		assert(picture.save_png("res://data/work/political/kyushu_registration/qa/07_godot_review.png") == OK)
	print("Kyushu review scene: loading, 9 click regions, shared selection geometry passed")
	quit(0)
