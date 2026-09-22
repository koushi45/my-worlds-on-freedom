extends SceneTree
const Wait=preload("res://tests/base_map/godot/wait_map.gd")

func _initialize() -> void:
	var main=load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await Wait.settled(main)
	assert(main.asset_stream.manifest.get("tiles",{}).size()==504,"baked terrain is enabled")
	assert(main.asset_stream.misses>0,"background resources were actually streamed")
	var refreshes:int=main.visible_refresh_count
	for i in range(20):await process_frame
	assert(main.visible_refresh_count==refreshes,"static map does not scan tiles every frame")
	for tilt in [false,true]:
		main.set_oblique(tilt)
		main.set_map_zoom(4.0)
		main.camera.position=main.elevation.project(Vector2(3460,5880))
		await Wait.settled(main)
		assert(main.overview!=null and main.overview.visible,"national backdrop remains resident behind detail")
		assert(main.pending_tiles.is_empty())
		assert(main.asset_stream.resident_bytes<=main.asset_stream.budget_bytes)
		assert(main.shared_road_layer.cache_bytes<=8*1024*1024)
		for key in ["izumi/candidate-district-candidate-g04003"]:
			assert(main.district_layer.records.has(key))
			await Wait.parent(main.district_layer,"izumi")
			main.district_layer.select_key(key)
			await Wait.fill(main.district_layer)
			var vertices:PackedVector2Array=main.district_layer.fill_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var f:=FileAccess.open(main.district_layer.records[key]["mesh_file"],FileAccess.READ)
			var raw:=f.get_buffer(f.get_length()).to_float32_array()
			assert(vertices.size()*2==raw.size())
			for i in range(0,vertices.size(),maxi(1,vertices.size()/100)):
				assert(vertices[i].distance_to(main.elevation.project(Vector2(raw[i*2],raw[i*2+1])))<.001,"baked ground fill matches original projection")
	# Fast camera changes leave only the latest requests and no stale attachments.
	for i in range(20):
		main.camera.position=Vector2(2000+i*100,6000)
		main._refresh_visible_tiles()
	await Wait.settled(main)
	for id in main.loaded_tiles:
		assert(id in main.catalog.get_detail_tiles(main.get_visible_world_rect().grow(2)).map(func(t):return t["tile_id"]))
	assert(main.asset_stream.failed.is_empty())
	assert(main.asset_stream.resident_bytes<=main.asset_stream.budget_bytes)
	print("MAP STREAMING QA: PASS; idle, budgets, baked projection, stale requests, fallback visibility")
	quit(0)
