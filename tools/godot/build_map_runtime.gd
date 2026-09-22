extends SceneTree
const Chunk = preload("res://scripts/map/map_render_chunk.gd")
const Surface = preload("res://scripts/map/elevation_surface.gd")
var output := "res://data/derived/map_runtime/"
var surface = Surface.new()
var manifest: Dictionary = {"tiles":{},"districts":{},"parents":{}}

func read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func save_chunk(chunk: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	assert(ResourceSaver.save(chunk,path,ResourceSaver.FLAG_COMPRESS)==OK)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var tiles: Array = read_json("res://data/derived/map_images/map_images_manifest.json")["tiles"]
	tiles.append_array(read_json("res://data/derived/detail_map/manifest.json")["tiles"])
	for tile in tiles:
		for tilt in [false,true]:
			surface.enabled=tilt
			var chunk=Chunk.new()
			if tile.has("density"):
				var raw: Dictionary=read_json("res://"+tile["files"]["geometry"])
				var vertices:=PackedVector2Array();var uv:=PackedVector2Array()
				vertices.resize(raw["vertices"].size());uv.resize(vertices.size())
				var b:Array=tile["global_viewport"];var origin:=Vector2(b[0],b[1])
				for i in range(vertices.size()):
					var p:=Vector2(raw["vertices"][i][0],raw["vertices"][i][1])
					vertices[i]=surface.project(p)
					uv[i]=((p-origin)*float(tile["density"])+Vector2.ONE*float(tile["gutter"]))/float(tile["output_size"][0])
				var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(raw["indices"])
				chunk.mesh=ArrayMesh.new();chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
				for ring in raw["coasts"]:
					var points:=PackedVector2Array()
					for p in ring:points.append(Vector2(p[0],p[1]))
					chunk.coasts.append(surface.project_line(points))
				chunk.textures.append(load("res://"+tile["files"]["relief"]))
				chunk.resident_bytes=vertices.size()*16+raw["indices"].size()*4+1032*1032*4
			else:
				chunk.mesh=surface.mesh_for(tile["global_viewport"])
				chunk.textures.append(load("res://"+tile["files"]["composite"]))
				chunk.textures.append(load("res://assets/map/elevation/"+tile["tile_id"]+".png"))
				chunk.textures.append(load("res://"+tile["files"]["coastline"]))
				chunk.resident_bytes=3*2048*2048*4+16*1024*1024
			var key:String=tile["tile_id"]+("_tilt" if tilt else "_flat")
			var path:=output+"tiles/"+key+".res"
			save_chunk(chunk,path);manifest["tiles"][key]=path
		surface.mesh_cache.clear()
		surface.cache_costs.clear();surface.cache_bytes=0
	print("Baked tiles: ",tiles.size())
	var index_path:="res://data/derived/districts/unconfirmed/index.json"
	var index:=read_json(index_path)
	manifest["source_index_sha256"]=FileAccess.get_sha256(index_path)
	manifest["elevation_sha256"]=FileAccess.get_sha256("res://assets/map/elevation/mesh_height.png")
	manifest["heightfield_sha256"]=surface.fingerprint()
	for r in index["regions"]:
		var f:=FileAccess.open(r["mesh_file"],FileAccess.READ)
		var raw:=f.get_buffer(f.get_length()).to_float32_array()
		for tilt in [false,true]:
			surface.enabled=tilt
			var vertices:=PackedVector2Array();vertices.resize(raw.size()/2)
			for i in range(vertices.size()): vertices[i]=surface.project(Vector2(raw[i*2],raw[i*2+1]))
			var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
			var chunk=Chunk.new();chunk.mesh=ArrayMesh.new()
			chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
			chunk.resident_bytes=vertices.size()*8
			var key:String=r["key"]+("_tilt" if tilt else "_flat")
			var path:=output+"districts/"+key+".res"
			save_chunk(chunk,path);manifest["districts"][key]=path
	for parent in index["parents"]:
		var d:=read_json(parent["file"])
		for r in d["regions"]:
			for polygon in r["polygons"]:
				for i in range(polygon.size()):
					var points:=PackedVector2Array()
					for p in polygon[i]:points.append(Vector2(p[0],p[1]))
					polygon[i]=points
		for line in d["lines"]:
			var points:=PackedVector2Array()
			for p in line["points"]:points.append(Vector2(p[0],p[1]))
			line["points"]=points
			surface.enabled=false;line["surface_flat"]=surface.project_line(points)
			surface.enabled=true;line["surface_tilt"]=surface.project_line(points)
		var chunk=Chunk.new();chunk.data=d
		chunk.resident_bytes=FileAccess.get_file_as_bytes(parent["file"]).size()*2
		var path:String=output+"parents/"+parent["id"]+".res"
		save_chunk(chunk,path);manifest["parents"][parent["id"]]=path
	var f:=FileAccess.open(output+"manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify(manifest))
	print("BAKED MAP: ",tiles.size()," tiles, ",index["regions"].size()," district fills, ",index["parents"].size()," packed parents")
	quit(0)
