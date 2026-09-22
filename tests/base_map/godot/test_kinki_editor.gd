extends SceneTree
var failures: Array[String] = []
func check(value: bool,text: String) -> void:
	if not value: failures.append(text); printerr(text)
func _initialize() -> void:
	var scope := "honshu" if "--honshu" in OS.get_cmdline_user_args() else "chugoku" if "--chugoku" in OS.get_cmdline_user_args() else "kinki"
	var editor = load("res://scenes/main/%s_border_editor.tscn" % scope).instantiate()
	editor.autosave_path="user://kinki_editor_test_%s.json" % str(Time.get_ticks_usec())
	root.add_child(editor)
	await process_frame
	check(editor.initialized,"editor initialization")
	check(editor.region_scope==scope and editor.draft.status=="editor_draft_only","unconfirmed region editor")
	check(editor.export_data().scope==scope,"scope in export")
	check(editor.locked.regions.size()==24,"Kyushu Shikoku Chugoku locked")
	if scope=="chugoku":
		check(editor.allowed(Vector2(2870,5550),Vector2(2880,5550)),"Chugoku interior editable")
		if editor.draft.has("regions"):
			check(editor.select_preview(Vector2(2870,5550))=="mimasaka","aligned country frame selection")
	var fixed := JSON.stringify(editor.locked)
	var coast := JSON.stringify(editor.draft.coastlines)
	var seed_count: int = editor.lines.size()
	if scope=="kinki":
		check(editor.shared_lines.size()==3,"three approved shared boundary references")
		check(editor.export_data().shared_boundary_references.size()==3,"export retains immutable shared references")
		if not editor.draft.has("handdrawn_source"):
			var old_seed = JSON.parse_string(FileAccess.get_file_as_string("res://data/work/political/kinki_uploaded_crop/kinki/review_layer.json"))
			var legacy: Dictionary = editor.export_data()
			legacy.boundaries=old_seed.boundaries
			legacy.reference_hashes=editor.draft.legacy_reference_hashes[0]
			var legacy_path: String=editor.autosave_path+".legacy.json"
			var legacy_file := FileAccess.open(legacy_path,FileAccess.WRITE)
			legacy_file.store_string(JSON.stringify(legacy));legacy_file.close()
			check(editor.load_edits(legacy_path),"legacy JSON migration")
			check(editor.lines.size()==seed_count,"legacy duplicate shared lines removed")
			check(JSON.stringify(editor.lines)==JSON.stringify(editor.draft.boundaries),"legacy junction maps to approved seam")
			DirAccess.remove_absolute(legacy_path)
		var shared: PackedVector2Array=editor.shared_lines[1]
		check(not editor.allowed(shared[0],shared[1]),"shared border cannot be duplicated as editable line")
		var q: Vector2=(shared[0]+shared[1])*0.5
		check(editor.snap_point(q+Vector2(0.01,0.01)).distance_to(q)<0.03,"snap onto immutable shared boundary")
	editor.mode=1
	var a: Vector2 = editor.bounds.position + Vector2(100,100)
	var b := a+Vector2(100,0)
	editor.lines=[{"boundary_id":"test","points":[[a.x,a.y],[b.x,b.y]]}]
	var rect := Rect2(a+Vector2(30,-10),Vector2(40,20))
	check(editor.delete_rectangle(rect),"rectangle deletes intersecting portion")
	check(editor.lines.size()==2,"crossing line retains both outside pieces")
	var total := 0.0
	for line in editor.lines:
		var poly: PackedVector2Array=editor.points(line.points)
		for i in range(poly.size()-1): total+=poly[i].distance_to(poly[i+1])
	check(absf(total-60)<0.1,"inside length removed, outside preserved")
	editor.undo()
	check(editor.lines.size()==1,"undo deletion")
	editor.redo()
	check(editor.lines.size()==2,"redo deletion")
	check(not editor.delete_rectangle(Rect2(a+Vector2(200,0),Vector2(5,5))),"empty deletion no op")
	check(not editor.add_line(Vector2(1900,6500),Vector2(1910,6500)),"Kyushu locked")
	check(not editor.add_line(Vector2(2870,5550),Vector2(2880,5550)),"approved Chugoku locked")
	check(JSON.stringify(editor.locked)==fixed and JSON.stringify(editor.draft.coastlines)==coast,"immutable layers unchanged")
	editor.lines=editor.draft.boundaries.duplicate(true)
	var test_path: String = editor.autosave_path+".export.json"
	check(editor.save_edits(test_path)==OK,"JSON export")
	editor.lines=[]
	check(editor.load_edits(test_path),"JSON import matching metadata")
	check(editor.lines.size()==seed_count,"roundtrip seed lines")
	var seed: Dictionary=editor.lines[0]
	var seed_point := Vector2(seed.points[0][0],seed.points[0][1])
	editor.delete_rectangle(Rect2(seed_point-Vector2.ONE*2,Vector2.ONE*4))
	check(editor.save_edits(test_path)==OK and editor.load_edits(test_path),"clipped seed JSON roundtrip")
	# Add real user line in an editable part of the region.
	var added := false
	for i in range(100):
		var p: Vector2=editor.bounds.position+editor.bounds.size*Vector2((i%10+0.5)/10.0,(floori(i/10.0)+0.5)/10.0)
		if editor.add_line(p,p+Vector2(10,10)): added=true; break
	check(added,"two-point addition")
	if scope=="chugoku" and editor.draft.has("regions"):
		check(editor.select_preview(Vector2(2870,5550)).is_empty(),"modified lines must not show stale frames")
	check(editor.save_edits(test_path)==OK and editor.load_edits(test_path),"edited JSON roundtrip")
	# Real drag events remove interior, without changing the camera transform.
	editor.lines=[{"boundary_id":"test_drag","points":[[a.x,a.y],[b.x,b.y]]}]
	var old_offset: Vector2=editor.offset
	var press := InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	press.position=rect.position*editor.zoom_value+editor.offset
	editor._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position=rect.end*editor.zoom_value+editor.offset
	editor._unhandled_input(motion)
	press.position=motion.position;press.pressed=false
	editor._unhandled_input(press)
	check(editor.lines.size()==2 and editor.offset==old_offset,"drag rectangle does not pan")
	editor.lines=editor.draft.boundaries.duplicate(true)
	editor.pending=false
	editor.status("動作検証済み：範囲削除・追加・JSON入出力")
	if "--shared-seam" in OS.get_cmdline_user_args():
		editor.zoom_value=1.2
		editor.offset=Vector2(740,350)-Vector2(3070,5530)*editor.zoom_value
		editor.queue_redraw()
	if "--preview" in OS.get_cmdline_user_args():
		editor.mode=2
		editor.zoom_value=1.5
		editor.offset=Vector2(800,360)-Vector2(2860,5550)*editor.zoom_value
		check(editor.select_preview(Vector2(2870,5550))=="mimasaka","restored frame selection")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/%s_editor.png" % scope)
	DirAccess.remove_absolute(editor.autosave_path)
	DirAccess.remove_absolute(test_path)
	print("PASS: editor rectangle clipping, undo/redo, two-point add, JSON roundtrip, locked regions" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)
