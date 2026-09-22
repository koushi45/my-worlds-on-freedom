extends SceneTree

func _initialize() -> void:
	var editor=load("res://scenes/main/region36_border_editor.tscn").instantiate()
	editor.autosave_path="user://region36_test_%s.json" % Time.get_ticks_usec()
	root.add_child(editor)
	await process_frame
	assert(editor.initialized)
	assert(editor.lines.is_empty())
	assert(editor.target_polygons.size()==1)
	var a:=Vector2(3482.7655,5796.481)
	var b:=a+Vector2(2,0)
	assert(editor.add_line(a,b))
	assert(not editor.add_line(a,Vector2(3300,5600)))
	assert(editor.save_edits(editor.autosave_path)==OK)
	var saved: Dictionary=editor.export_data()
	assert(saved.scope=="region36")
	editor.undo()
	assert(editor.lines.is_empty())
	editor.redo()
	assert(editor.lines.size()==1)
	assert(editor.load_edits(editor.autosave_path))
	assert(editor.export_data().boundaries==saved.boundaries)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-to="):
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(arg.trim_prefix("--capture-to="))==OK)
	DirAccess.remove_absolute(editor.autosave_path)
	print("PASS: region36 editor drawing, protected exterior, undo/redo, save/load")
	quit()
