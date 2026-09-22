extends SceneTree
const Chunk = preload("res://scripts/map/map_render_chunk.gd")
const Geometry = preload("res://scripts/map/map_line_geometry.gd")
var output := "res://data/derived/map_runtime/"
var manifest: Dictionary
var surface = preload("res://scripts/map/elevation_surface.gd").new()

func footprint(resource: Resource, path: String) -> Dictionary:
	var components := {}
	if resource.mesh != null:
		var bytes := 0
		for i in range(resource.mesh.get_surface_count()):
			for array in resource.mesh.surface_get_arrays(i):
				if array != null: bytes += array.to_byte_array().size()
		components[path+":mesh"] = bytes
	for texture in resource.textures:
		var key: String = texture.resource_path
		if key.is_empty(): key = path+":texture"
		components[key] = texture.get_image().get_data_size()
	if not resource.data.is_empty(): components[path+":data"] = var_to_bytes(resource.data).size()
	var coasts := 0
	for line in resource.coasts: coasts += line.size()*8
	if coasts > 0: components[path+":coasts"] = coasts
	return components

func save(resource: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	assert(ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS)==OK)
	manifest["footprints"][path] = footprint(resource,path)
	manifest["file_bytes"][path] = FileAccess.get_file_as_bytes(path).size()

func overview(tilt: bool) -> void:
	surface.enabled = tilt
	var source: Resource = load(manifest.tiles["lod0-r00-c00"+("_tilt" if tilt else "_flat")])
	var chunk = Chunk.new()
	var image: Image = source.textures[0].get_image()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	# The source composite is a pale land mask; elevation and coastline are
	# separate textures. Bake all three into the permanent game backdrop.
	for index in [1,2]:
		var overlay: Image=source.textures[index].get_image()
		if overlay.is_compressed():overlay.decompress()
		overlay.convert(Image.FORMAT_RGBA8)
		image.blend_rect(overlay,Rect2i(Vector2i.ZERO,overlay.get_size()),Vector2i.ZERO)
	image.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	chunk.textures.append(ImageTexture.create_from_image(image))
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for y in range(129):
		for x in range(129):
			vertices.append(surface.project(Vector2(x,y)*64))
			uv.append(Vector2(x,y)/128.0)
	for y in range(128):
		for x in range(128):
			var n := y*129+x
			indices.append_array(PackedInt32Array([n,n+1,n+129,n+1,n+130,n+129]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	chunk.mesh=ArrayMesh.new()
	chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	var path := output+"overview_"+("tilt" if tilt else "flat")+".res"
	save(chunk,path)
	manifest.overviews["tilt" if tilt else "flat"] = path

func coarse_tiles() -> void:
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/map_images/map_images_manifest.json"))
	for tile in catalog.tiles:
		var b: Array=tile.global_viewport
		var step:=64 if int(tile.lod)<=1 else 32
		var columns:=int((float(b[2])-float(b[0]))/step)+1
		var rows:=int((float(b[3])-float(b[1]))/step)+1
		for tilt in [false,true]:
			surface.enabled=tilt
			var vertices:=PackedVector2Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
			for y in range(rows):
				for x in range(columns):
					vertices.append(surface.project(Vector2(b[0],b[1])+Vector2(x,y)*step))
					uv.append(Vector2(float(x)/(columns-1),float(y)/(rows-1)))
			for y in range(rows-1):
				for x in range(columns-1):
					var n:=y*columns+x
					indices.append_array(PackedInt32Array([n,n+1,n+columns,n+1,n+columns+1,n+columns]))
			var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
			var path: String=manifest.tiles[tile.tile_id+("_tilt" if tilt else "_flat")]
			var chunk: Resource=load(path)
			chunk.mesh=ArrayMesh.new();chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
			save(chunk,path)

func _initialize() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(output+"manifest.json"))
	if "--tiles-only" in OS.get_cmdline_user_args():
		coarse_tiles()
		FileAccess.open(output+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest))
		quit();return
	if "--overview-only" in OS.get_cmdline_user_args():
		overview(false);overview(true)
		FileAccess.open(output+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest))
		quit();return
	var boundaries_only := "--boundaries-only" in OS.get_cmdline_user_args()
	if not boundaries_only:
		manifest["footprints"] = {}
		manifest["file_bytes"] = {}
		manifest["overviews"] = {}
		manifest["boundary_batches"] = {}
		manifest["seamless_version"] = 1
		overview(false);overview(true)
		coarse_tiles()
	for category in (["parents"] if boundaries_only else ["tiles","districts","parents"]):
		for key in manifest[category]:
			var path: String = manifest[category][key]
			var resource: Resource = load(path)
			if category == "parents":
				resource.data = Geometry.prepare_parent(resource.data)
				save(resource,path)
				var batches := []
				# Spatial cells bound both upload size and visible geometry.
				for tilt in [false,true]:
					var cells := {}
					for line in resource.data.lines:
						var vector: PackedVector2Array = line["surface_tilt" if tilt else "surface_flat"]
						var along := 0.0
						for i in range(vector.size()-1):
							var a := vector[i];var b := vector[i+1]
							if a.distance_to(b) < 0.000001: continue
							var cell := Vector2i(((a+b)*0.5/256).floor())
							if not cells.has(cell): cells[cell]=[]
							cells[cell].append([a,b,along])
							along += a.distance_to(b)
					for cell in cells:
						var segments: Array = cells[cell]
						for start in range(0,segments.size(),1024):
							var lines := []
							var bounds := Rect2(segments[start][0],Vector2.ZERO)
							for i in range(start,mini(start+1024,segments.size())):
								lines.append(PackedVector2Array([segments[i][0],segments[i][1]]))
								bounds=bounds.expand(segments[i][0]).expand(segments[i][1])
							var arrays := Geometry.arrays_for(lines)
							var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
							for i in range(lines.size()):
								for v in range(4): colors[i*4+v]=Geometry.distance_color(float(segments[start+i][2])+(lines[i][0].distance_to(lines[i][1]) if v>=2 else 0.0))
							arrays[Mesh.ARRAY_COLOR]=colors
							var chunk=Chunk.new();chunk.mesh=ArrayMesh.new()
							chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
							var batch_path: String = output+"parents/"+key+"/batch_%d_%d_%d_%s.res" % [cell.x,cell.y,start,"tilt" if tilt else "flat"]
							save(chunk,batch_path)
							batches.append({"path":batch_path,"tilt":tilt,"bounds":[bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y]})
				manifest.boundary_batches[key]=batches
			else:
				manifest.footprints[path] = footprint(resource,path)
				manifest.file_bytes[path] = FileAccess.get_file_as_bytes(path).size()
		print("SEAMLESS BAKE: ",category)
	var f:=FileAccess.open(output+"manifest.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest))
	print("SEAMLESS BAKE: complete")
	quit()
