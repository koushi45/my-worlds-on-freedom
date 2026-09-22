extends RefCounted
## Pure CPU projection. Inputs are immutable, each result belongs to one task.
static func project_lines(lines: Dictionary, surface: RefCounted) -> Dictionary:
	var result := {}
	for key in lines: result[key] = surface.project_line(lines[key])
	return result

static func project_water(records: Array, surface: RefCounted) -> Dictionary:
	var result := {}
	for record in records:
		if not record.get("visible_by_default",true):continue
		var item := {}
		if record.has("points"):
			var points := PackedVector2Array()
			for p in record.points:points.append(Vector2(p[0],p[1]))
			item["line"]=surface.project_line(points)
			item["line_arrays"]=preload("res://scripts/map/map_line_geometry.gd").arrays_for([item.line])
		else:
			var vertices := PackedVector2Array()
			for p in record.triangles:vertices.append(surface.project(Vector2(p[0],p[1])))
			item["vertices"]=vertices
			item["rings"]=[]
			for raw in record.rings:
				var points := PackedVector2Array()
				for p in raw:points.append(Vector2(p[0],p[1]))
				item.rings.append(surface.project_line(points))
			item["line_arrays"]=preload("res://scripts/map/map_line_geometry.gd").arrays_for(item.rings)
		result[record.id]=item
	return result
