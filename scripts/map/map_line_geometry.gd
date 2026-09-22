extends RefCounted
## Pure CPU geometry, usable by the build pipeline or an owning worker.
static func arrays_for(lines: Array) -> Array:
	var vertices := PackedVector2Array()
	var normals := PackedVector2Array()
	var distances := PackedColorArray()
	var indices := PackedInt32Array()
	for line in lines:
		var along := 0.0
		for i in range(line.size()-1):
			var a: Vector2 = line[i]
			var b: Vector2 = line[i+1]
			var length := a.distance_to(b)
			if length < 0.000001: continue
			var normal := (b-a).orthogonal().normalized()
			var n := vertices.size()
			vertices.append_array(PackedVector2Array([a,a,b,b]))
			normals.append_array(PackedVector2Array([-normal,normal,-normal,normal]))
			distances.append_array(PackedColorArray([distance_color(along),distance_color(along),distance_color(along+length),distance_color(along+length)]))
			indices.append_array(PackedInt32Array([n,n+1,n+2,n+1,n+3,n+2]))
			along += length
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = normals
	arrays[Mesh.ARRAY_COLOR] = distances
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

static func prepare_parent(data: Dictionary) -> Dictionary:
	if data.has("line_grid"): return data
	var result := data.duplicate()
	var polygons := {}
	var grid := {}
	var lines := []
	for region in data["regions"]: polygons[region["key"]] = region["polygons"]
	for raw in data["lines"]:
		var line: Dictionary = raw.duplicate()
		var b: Array = line["bounds"]
		var rect := Rect2(Vector2(b[0],b[1]),Vector2(b[2]-b[0],b[3]-b[1])).grow(0.001)
		line["rect"] = rect
		var points := PackedVector2Array()
		if line["points"] is PackedVector2Array: points = line["points"]
		else:
			for p in line["points"]: points.append(Vector2(p[0],p[1]))
		line["vector"] = points
		for y in range(int(floor(rect.position.y/128)),int(floor(rect.end.y/128))+1):
			for x in range(int(floor(rect.position.x/128)),int(floor(rect.end.x/128))+1):
				var cell := Vector2i(x,y)
				if not grid.has(cell): grid[cell] = []
				grid[cell].append(lines.size())
		lines.append(line)
	result["lines"] = lines
	result["polygons"] = polygons
	result["line_grid"] = grid
	return result

static func distance_color(distance: float) -> Color:
	# Canvas vertex colors are normalized bytes. Pack a 24-bit fixed-point
	# distance instead of putting an unclamped distance into the red channel.
	var value:=int(round(distance*64.0))
	return Color(float((value>>16)&255)/255.0,float((value>>8)&255)/255.0,float(value&255)/255.0,1.0)
