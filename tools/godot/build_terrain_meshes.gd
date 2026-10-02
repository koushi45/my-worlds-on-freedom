extends SceneTree
## Bake identical far/Fuji meshes; no simplification or change in vertex normals.
const View = preload("res://scripts/map/map_view_3d.gd")
const Chunk = preload("res://scripts/map/map_render_chunk.gd")

func _initialize() -> void:
    var view := View.new()
    view.height_data = FileAccess.get_file_as_bytes("res://data/derived/elevation/terrain_vertices.bin")
    view.fuji_data = FileAccess.get_file_as_bytes("res://data/derived/elevation/fuji_vertices.bin")
    var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/elevation/terrain_geometry.json"))
    view.height_scale = meta.height_scale
    view.fuji_rect = Rect2(Vector2(meta.fuji_detail.origin[0],meta.fuji_detail.origin[1]),Vector2.ONE*float(meta.fuji_detail.span))
    view.fuji_step = meta.fuji_detail.step_world
    var terrain_hash := view.bytes_sha256(view.height_data)
    var fuji_hash := view.bytes_sha256(view.fuji_data)
    var geometry_hash := view.bytes_sha256(FileAccess.get_file_as_bytes("res://data/derived/elevation/terrain_geometry.json"))
    var directory := "res://data/derived/elevation/terrain_chunks"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    var entries: Array = []
    var far_maximum := 0.0
    for y in range(0,8192,1024):
        for x in range(0,8192,1024):
            var region := Rect2(x,y,1024,1024)
            var arrays := view._geometry_arrays(region,view.STEP,false)
            var chunk := Chunk.new()
            chunk.mesh=ArrayMesh.new()
            chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
            var maximum := 0.0
            for vertex in arrays[Mesh.ARRAY_VERTEX]: maximum=maxf(maximum,vertex.y)
            far_maximum=maxf(far_maximum,maximum)
            chunk.data={"region":region,"step":view.STEP,"max_height":maximum}
            var path := directory+"/%d_%d.res" % [x/1024,y/1024]
            if ResourceSaver.save(chunk,path,ResourceSaver.FLAG_COMPRESS)!=OK:
                view.free()
                quit(1)
                return
            entries.append({"x":x,"y":y,"path":path})
    var measured_maximum := 0
    for bytes in [view.height_data,view.fuji_data]:
        for i in range(0,bytes.size(),2): measured_maximum=maxi(measured_maximum,bytes.decode_u16(i))
    var manifest := FileAccess.open(directory+"/manifest.json",FileAccess.WRITE)
    manifest.store_string(JSON.stringify({"version":1,"chunk_side":1024,"terrain_sha256":terrain_hash,"fuji_sha256":fuji_hash,"geometry_sha256":geometry_hash,"max_height":far_maximum,"culling_height":measured_maximum*view.height_scale,"chunks":entries},"  "))
    manifest.close()
    print("BAKED FAR TILES ",entries.size())
    for name in ["far","fuji"]:
        var path: String = "res://data/derived/elevation/terrain_"+name+".res"
        if ResourceLoader.exists(path):
            var existing: Resource = load(path)
            if existing.data.get("terrain_sha256","")==terrain_hash and existing.data.get("fuji_sha256","")==fuji_hash and existing.data.get("geometry_sha256","")==geometry_hash:
                print("UNCHANGED TERRAIN ",name)
                continue
        var chunk := Chunk.new()
        var region: Rect2 = Rect2(0,0,8192,8192) if name=="far" else view.fuji_rect
        var step: float = float(view.STEP) if name=="far" else view.fuji_step
        var arrays := view._geometry_arrays(region,step,name=="fuji")
        chunk.mesh = ArrayMesh.new()
        chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        var maximum := 0.0
        for vertex in arrays[Mesh.ARRAY_VERTEX]: maximum = maxf(maximum,vertex.y)
        chunk.data = {"version":1,"terrain_sha256":terrain_hash,"fuji_sha256":fuji_hash,"geometry_sha256":geometry_hash,
            "height_scale":view.height_scale,"fuji_step":view.fuji_step,"region":region,"step":step,"max_height":maximum}
        if ResourceSaver.save(chunk,path,ResourceSaver.FLAG_COMPRESS)!=OK:
            quit(1)
            return
        print("BAKED TERRAIN ",name," vertices=",arrays[Mesh.ARRAY_VERTEX].size())
    view.free()
    quit(0)
