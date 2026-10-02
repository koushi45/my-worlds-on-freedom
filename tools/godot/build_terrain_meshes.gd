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
    for name in ["far","fuji"]:
        var chunk := Chunk.new()
        var region: Rect2 = Rect2(0,0,8192,8192) if name=="far" else view.fuji_rect
        var step: float = float(view.STEP) if name=="far" else view.fuji_step
        var arrays := view._geometry_arrays(region,step,name=="fuji")
        chunk.mesh = ArrayMesh.new()
        chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        var maximum := 0.0
        for vertex in arrays[Mesh.ARRAY_VERTEX]: maximum = maxf(maximum,vertex.y)
        chunk.data = {"version":1,"terrain_sha256":terrain_hash,"fuji_sha256":fuji_hash,
            "height_scale":view.height_scale,"fuji_step":view.fuji_step,"region":region,"step":step,"max_height":maximum}
        var path: String = "res://data/derived/elevation/terrain_"+name+".res"
        assert(ResourceSaver.save(chunk,path,ResourceSaver.FLAG_COMPRESS)==OK)
        print("BAKED TERRAIN ",name," vertices=",arrays[Mesh.ARRAY_VERTEX].size())
    view.free()
    quit(0)
