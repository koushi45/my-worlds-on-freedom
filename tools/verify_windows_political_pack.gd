extends SceneTree
## Run this external script against the exported PCK, from builds/windows.
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ",message)

func _initialize() -> void:
	check(not FileAccess.file_exists("res://data/work/political/kyushu_registration/review_layer.json"),"work data leaked into export")
	check(not ResourceLoader.exists("res://tools/review/kyushu_registration.tscn"),"review scene leaked into export")
	check(not ResourceLoader.exists("res://data/derived/political/qa/p4/kyushu/01_source_trace_overlay.png"),"unapproved QA image leaked into export")
	check(FileAccess.file_exists("res://data/derived/political/approved_kyushu/ATTRIBUTION.md"),"attribution missing")
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	if packed==null:
		printerr("FAIL: exported main scene missing")
		quit(1)
		return
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	check(main.initialized,"map did not initialize")
	check(main.political_layer.initialized,"political layer did not initialize")
	check(main.political_layer.click_polygons.size()==66,"wrong province count")
	check(main.political_layer.unresolved_region_ids.size()==0,"wrong unresolved fill count")
	check(not main.political_layer.click_polygons.has("honshu-area-36"),"region36 not split")
	check(main.political_layer.select_at(Vector2(3423.9104,5726.9816))=="摂津国","Settsu selection")
	check(main.political_layer.select_at(Vector2(3453.2402,5895.0831))=="和泉国","Izumi selection")
	check(not ResourceLoader.exists("res://scenes/main/region36_border_editor.tscn"),"retired region36 editor exported")
	check(not main.political_layer.click_polygons.has("honshu-area-02"),"merged region 02 still present")
	for point in [Vector2(5513.5302,3072.806),Vector2(5494.951,2815.705)]:
		check(main.political_layer.select_at(point)=="陸奥国","merged Mutsu selection failed")
	check(not main.political_layer.boundary_points.has("honshu:honshu-area-01:honshu-area-02:0"),"internal Mutsu border remains")
	check(not main.political_layer.click_polygons.has("honshu-area-15"),"merged region still present")
	check(main.political_layer.select_at(Vector2(4845.876,4882.906))=="上野国","left half must select Kozuke")
	check(main.political_layer.select_at(Vector2(5304.561,5164.807))=="下総国","right half must select Shimosa")
	var names := {"honshu-area-01":"陸奥国", "honshu-area-03":"羽後国", "honshu-area-04":"陸中国", "honshu-area-05":"陸前国", "honshu-area-06":"羽前国", "honshu-area-08":"磐城国", "honshu-area-09":"岩代国", "honshu-area-30":"安房国"}
	for id in names:
		check(main.political_layer.region_names[id]==names[id],"wrong resolved name: " + id)
	check(main.political_layer.data.regional_bounds.has("chugoku"),"Chugoku must be approved")
	check(not FileAccess.file_exists("res://data/derived/editor/chugoku/editor_draft.json"),"retired Chugoku editor draft leaked into export")
	check(main.political_layer.hit_test(Vector2(2870,5550))=="mimasaka","Chugoku click selection")
	check(not FileAccess.file_exists("res://data/derived/editor/honshu/editor_draft.json"),"retired Honshu draft leaked into export")
	check(main.political_layer.boundary_arcs.size()==4,"shared Chugoku intervals missing")
	for tile in main.catalog.tiles:
		check(ResourceLoader.exists("res://"+str(tile["files"]["composite"])),"exported tile missing: "+str(tile["tile_id"]))
	main.focus_kyushu()
	main.select_country(Vector2(1900,6500))
	check(main.political_layer.selected_id=="bungo","exported Bungo selection failed")
	check(main.get_loaded_tile_count()>0,"Kyushu tiles not loaded")
	main.focus_region("chugoku")
	main.select_country(Vector2(2870,5550))
	check(main.political_layer.selected_id=="mimasaka","approved Chugoku selection")
	main.focus_region("honshu")
	main.select_country(Vector2(4521,5089))
	check(main.political_layer.selected_id=="shinano","Honshu production selection")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-to="):
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture-to="))==OK,"capture failed")
	if failures.is_empty():print("PASS: exported Windows pack, approved politics, map tiles, selection, no review assets")
	quit(0 if failures.is_empty() else 1)
