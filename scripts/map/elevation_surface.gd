extends RefCounted
## A shared triangulated height field for rendering, borders and inverse picking.
const STEP := 16.0
const SIDE := 513
const CENTER := Vector2(4096, 4096)
const TILT := 0.72
const SHEAR := 0.18
var enabled := true
var relief_visible := true
var height_scale := 0.0
var heights := PackedFloat32Array()
var mesh_cache: Dictionary = {}
var cache_costs: Dictionary = {}
var cache_bytes := 0
var manifest: Dictionary

func _init(skip_load: bool = false) -> void:
	if skip_load: return
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/elevation/elevation_manifest.json"))
	height_scale = float(manifest["display_height_scale"])
	var texture := load("res://assets/map/elevation/mesh_height.png") as Texture2D
	var image := texture.get_image()
	heights.resize(SIDE * SIDE)
	for y in range(SIDE):
		for x in range(SIDE):
			var pixel := image.get_pixel(x,y)
			heights[y*SIDE+x] = roundf(pixel.r*255.0)*256.0+roundf(pixel.g*255.0)

func fingerprint() -> String:
	var digest:=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(heights.to_byte_array())
	digest.update(var_to_bytes([STEP,SIDE,TILT,SHEAR,height_scale]))
	return digest.finish().hex_encode()

func elevation_at(point: Vector2) -> float:
	if point.x < 0 or point.y < 0 or point.x > 8192 or point.y > 8192: return 0.0
	var grid := point / STEP
	var x := mini(int(grid.x),SIDE-2)
	var y := mini(int(grid.y),SIDE-2)
	var f := grid-Vector2(x,y)
	var a := heights[y*SIDE+x]
	var b := heights[y*SIDE+x+1]
	var c := heights[(y+1)*SIDE+x]
	var d := heights[(y+1)*SIDE+x+1]
	if f.x+f.y <= 1.0: return a+(b-a)*f.x+(c-a)*f.y
	return d+(c-d)*(1.0-f.x)+(b-d)*(1.0-f.y)

func project(point: Vector2) -> Vector2:
	if not enabled: return point
	var p := point-CENTER-Vector2(0,elevation_at(point)*height_scale)
	return CENTER+Vector2(p.x+SHEAR*p.y,p.y*TILT)

func unproject(point: Vector2) -> Vector2:
	if not enabled: return point
	var p := point-CENTER
	var source_y := p.y/TILT+CENTER.y
	var source_x := p.x-SHEAR*p.y/TILT+CENTER.x
	# Generator limits the height derivative to <1, so the inverse is unique.
	var lo := source_y
	var hi := source_y+4000.0*height_scale+1.0
	for iteration in range(22):
		var mid := (lo+hi)*0.5
		if mid-elevation_at(Vector2(source_x,mid))*height_scale < source_y: lo = mid
		else: hi = mid
	return Vector2(source_x,(lo+hi)*0.5)

func project_line(points: PackedVector2Array) -> PackedVector2Array:
	if not enabled: return points
	var output := PackedVector2Array()
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var cuts: Array[float] = [0.0]
		# Split at each shared mesh edge, including triangle diagonals.
		for pair in [Vector2(a.x,b.x),Vector2(a.y,b.y),Vector2(a.x+a.y,b.x+b.y)]:
			if absf(pair.y-pair.x)<0.0001: continue
			for k in range(int(floor(minf(pair.x,pair.y)/STEP))+1,int(ceil(maxf(pair.x,pair.y)/STEP))):
				var t: float = (k*STEP-pair.x)/(pair.y-pair.x)
				if t>0.00001 and t<0.99999: cuts.append(t)
		cuts.sort()
		for t in cuts:
			var p := project(a.lerp(b,t))
			if output.is_empty() or output[-1].distance_squared_to(p)>0.000001: output.append(p)
	if not points.is_empty(): output.append(project(points[-1]))
	return output

func mesh_for(bounds: Array) -> ArrayMesh:
	var key := str(bounds)+str(enabled)
	if mesh_cache.has(key): return mesh_cache[key]
	var origin := Vector2(float(bounds[0]),float(bounds[1]))
	var span := Vector2(float(bounds[2]),float(bounds[3]))-origin
	var columns := int(span.x/STEP)+1
	var rows := int(span.y/STEP)+1
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(columns*rows)
	uv.resize(columns*rows)
	for y in range(rows):
		for x in range(columns):
			var offset := Vector2(x,y)*STEP
			vertices[y*columns+x] = project(origin+offset)
			uv[y*columns+x] = offset/span
	for y in range(rows-1):
		for x in range(columns-1):
			var a := y*columns+x
			indices.append_array(PackedInt32Array([a,a+1,a+columns,a+1,a+columns+1,a+columns]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	mesh_cache[key] = mesh
	cache_costs[key]=vertices.size()*16+indices.size()*4
	cache_bytes=preload("res://scripts/map/map_cache.gd").trim(mesh_cache,cache_costs,32*1024*1024)
	return mesh

func snapshot() -> RefCounted:
	var copy = get_script().new(true)
	copy.enabled=enabled;copy.relief_visible=relief_visible
	copy.height_scale=height_scale;copy.heights=heights
	copy.manifest=manifest
	return copy
