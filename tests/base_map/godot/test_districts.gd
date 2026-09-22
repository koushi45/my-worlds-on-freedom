extends SceneTree
const Wait=preload("res://tests/base_map/godot/wait_map.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: "+message)

func frames() -> void:
	await process_frame
	await process_frame
	if root.get_child_count()>0: await Wait.settled(root.get_child(root.get_child_count()-1))
	if "--capture" in OS.get_cmdline_user_args(): await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	if "--capture" in OS.get_cmdline_user_args(): root.get_texture().get_image().save_png("res://builds/qa/district_"+name+".png")

func _initialize() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await frames()
	var layer = main.district_layer
	var expected_count: int = root.get_node("GameSession").catalog.district_ids.size()
	check(layer.initialized and layer.records.size()==expected_count,"district metadata loaded")
	if "--district-unconfirmed" in OS.get_cmdline_user_args():
		check(layer.unconfirmed_mode and layer.review_mode, "explicit unconfirmed mode enabled")
		check(layer.parents.size()==66, "all 66 parents packaged")
		for record in layer.records.values():
			check(record["adoption_status"]=="held", "preview does not adopt a district")
			check(str(record["mesh_file"]).begins_with("res://data/derived/districts/unconfirmed/"), "preview uses packaged meshes")
	check(layer.loaded.is_empty(),"national view loads no district geometry")
	check(layer.draw_line_count==0 and layer.label_count==0,"national view suppresses district lines and labels")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa"))
	capture("national")
	var key := "izumi/candidate-district-candidate-g04003"
	check(layer.records.has(key),"Izumi Minami candidate exists")
	for k in layer.records:
		var r: Dictionary = layer.records[k]
		await Wait.parent(layer,r["parent"])
		check(layer.contains_point(k,Vector2(r["label"][0],r["label"][1])),"label lies inside its region: "+k)
	var checked_hole := false
	for pid in layer.loaded:
		for k in layer.loaded[pid]["polygons"]:
			for polygon in layer.loaded[pid]["polygons"][k]:
				if checked_hole or polygon.size()<2: continue
				var hole: PackedVector2Array = layer.points(polygon[1])
				if hole[0]==hole[-1]: hole.resize(hole.size()-1)
				var indices := Geometry2D.triangulate_polygon(hole)
				if indices.size()<3: continue
				var p := (hole[indices[0]]+hole[indices[1]]+hole[indices[2]])/3.0
				check(not layer.contains_point(k,p),"hole is excluded by runtime hit test")
				checked_hole = true
	# Current districts have no interior rings. The curated Murakami island group
	# is the only multi-polygon district, with one base-coastline exterior per island.
	main.district_panel.mode.select(1)
	main.district_panel.set_mode(1)
	check(main.district_selection_mode,"district selection mode")
	layer.select_key(key)
	for tilt in [false,true]:
		main.set_oblique(tilt)
		main.set_map_zoom(4.0)
		var p := Vector2(3460,5880)
		main.camera.position = main.elevation.project(p)-Vector2(45,0)
		main._refresh_visible_tiles()
		await frames()
		if layer.independent_geometry == null: await Wait.fill(layer)
		check(layer.loaded.size()<15,"local view evicts distant country geometry")
		check(layer.selected_key==key and (layer.independent_geometry != null or layer.fill_mesh()!=null),"terrain-aligned selected fill created")
		check(main.camera.zoom.x==4.0,"400 percent cap preserved")
		layer.load_parent("izumi")
		var raw_boundary = layer.loaded["izumi"]["polygons"][key][0][0][0]
		var boundary := Vector2(raw_boundary[0],raw_boundary[1])
		var display: Vector2 = main.elevation.project(boundary)
		var screen: Vector2 = (display-main.camera.position)*main.camera.zoom+main.get_viewport_rect().size/2.0
		var ground: Vector2 = main._screen_to_world(screen)
		check(ground.distance_to(boundary)<0.01,"existing inverse returns district boundary")
		var picks: Array = layer.pick(ground)
		check(picks.size()==1 and layer.records.has(picks[0]),"boundary click resolves to exactly one district")
		var offset_ground: Vector2 = main._screen_to_world(screen+Vector2(3,0))
		var near_picks: Array = layer.pick(offset_ground)
		check(near_picks.size()==1 and layer.records.has(near_picks[0]),"3px tolerance resolves to exactly one district")
		main.district_panel.show_candidates(picks)
		check(main.district_panel.current_key==picks[0],"single boundary candidate is auto-selected")
		main.district_panel.browser.hide()
		layer.select_key(key)
		await frames()
		capture("400_"+("oblique" if tilt else "flat"))
		layer.set_enabled(false)
		check(not layer.visible,"district visibility off")
		layer.set_enabled(true)
		await frames()
		check(layer.visible and not layer.active_keys.is_empty(),"visibility restores unchanged view")
	main.district_panel.show_browser()
	main.district_panel.search.text = "南郡"
	main.district_panel.refresh()
	check(key in main.district_panel.matches,"search finds hidden label")
	main.district_panel.select_index(main.district_panel.matches.find(key))
	check("所属拠点" in main.district_panel.details.text and "CC BY-NC" in main.district_panel.details.text,"detail includes sites and attribution")
	if layer.unconfirmed_mode:
		check("未確定版" in main.district_panel.details.text, "detail explicitly identifies unconfirmed edition")
	await frames()
	capture("details")
	main.district_panel.browser.hide()
	main.district_panel.set_mode(0)
	check(not main.district_selection_mode and layer.selected_key.is_empty(),"country mode clears district fill")
	if layer.unconfirmed_mode:
		for merged in layer.records.values():
			if not merged.has("merge_members") or merged["parent"]!="kawachi" or merged["name"]!="河内郡": continue
			main.district_panel.show_browser()
			main.district_panel.search.text = "大県郡"
			main.district_panel.refresh()
			check(merged["key"] in main.district_panel.matches,"former district name finds merged district")
			main.district_panel.select_index(main.district_panel.matches.find(merged["key"]))
			check("表示用合併" in main.district_panel.details.text,"merged detail preserves constituent names")
			for tilt in [false,true]:
				main.set_oblique(tilt)
				main.district_panel.focus_current()
				await frames()
				if layer.independent_geometry == null: await Wait.fill(layer)
				check(layer.selected_key==merged["key"] and (layer.independent_geometry != null or layer.fill_mesh()!=null),"merged terrain fill works in flat and oblique")
				capture("merged_"+("oblique" if tilt else "flat"))
			break
	if layer.unconfirmed_mode:
		for named in layer.records.values():
			if not named.has("provisional_name") or named["parent"]!="izumi": continue
			main.district_panel.show_browser()
			main.district_panel.search.text = named["name"]
			main.district_panel.refresh()
			check(named["key"] in main.district_panel.matches,"provisional name is searchable")
			main.district_panel.select_index(main.district_panel.matches.find(named["key"]))
			check("便宜的な仮称" in main.district_panel.details.text,"provisional name is not presented as historical membership")
			await frames()
			capture("named_details")
			main.set_oblique(false)
			main.district_panel.focus_current()
			await frames()
			capture("named_flat")
			break
	print("DISTRICT TEST: "+("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)
