extends RefCounted
var regions: Dictionary
var extra_districts: Dictionary = {}

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/scenarios/independent_districts_1546.json"))
	regions = data.regions
	extra_districts = data.get("connectivity",{}).get("extra_districts",{})
	for r in regions.values():
		var map_area := 0.0
		for polygon in r.polygons:
			for i in range(polygon.size()):
				var points := PackedVector2Array()
				for p in polygon[i]: points.append(Vector2(p[0],p[1]))
				polygon[i] = points
				var signed_area := 0.0
				for j in range(points.size()-1): signed_area += points[j].cross(points[j+1])
				map_area += absf(signed_area)*0.5 if i == 0 else -absf(signed_area)*0.5
		r.map_area = maxf(map_area,0.001)

func parent_data(id: String) -> Dictionary:
	var polygons := {}
	for key in regions:
		if regions[key].parent == id: polygons[key] = regions[key].polygons
	return {"polygons":polygons,"lines":[],"line_grid":{}}
