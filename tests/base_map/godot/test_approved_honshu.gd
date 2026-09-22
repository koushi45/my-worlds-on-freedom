extends SceneTree

func _initialize() -> void:
	var layer=load("res://scripts/map/political_boundary_layer.gd").new()
	root.add_child(layer)
	await process_frame
	assert(layer.click_polygons.size()==66)
	assert(layer.boundary_arcs.size()==4)
	assert(not layer.click_polygons.has("honshu-area-36"))
	assert(layer.select_at(Vector2(3423.9104,5726.9816))=="摂津国")
	assert(layer.select_at(Vector2(3453.2402,5895.0831))=="和泉国")
	assert(not layer.click_polygons.has("honshu-area-02"))
	assert(layer.unresolved_region_ids.is_empty())
	for point in [Vector2(5513.5302,3072.806),Vector2(5494.951,2815.705)]:
		assert(layer.select_at(point)=="陸奥国")
		assert(layer.selected_id=="honshu-area-01")
	assert(not layer.boundary_points.has("honshu:honshu-area-01:honshu-area-02:0"))
	assert(layer.select_at(Vector2(4845.876,4882.906))=="上野国")
	assert(layer.select_at(Vector2(5304.561,5164.807))=="下総国")
	assert(not layer.click_polygons.has("honshu-area-15"))
	assert(not "kozuke" in layer.unresolved_region_ids and not "shimosa" in layer.unresolved_region_ids)
	for id in layer.click_polygons:
		var lines: Array=layer.selection_lines(id)
		assert(not lines.is_empty(),id)
		for ring in layer.click_polygons[id]:
			for point in ring:
				var distance := INF
				for line in lines:
					for i in range(line.size()-1):
						distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,line[i],line[i+1])))
				assert(distance<0.003,"Missing selected frame: %s, %f" % [id,distance])
	print("PASS: all 66 selection frames covered, including four shared Chugoku intervals")
	quit()
