extends SceneTree
const View = preload("res://scripts/map/map_view_3d.gd")
const Chunk = preload("res://scripts/map/map_render_chunk.gd")
const Adaptive = preload("res://scripts/map/terrain_grid_lod.gd")
func _initialize() -> void:
    var view := View.new()
    view.adaptive_terrain=false
    view.height_data=FileAccess.get_file_as_bytes("res://data/derived/elevation/terrain_vertices.bin")
    view.fuji_data=FileAccess.get_file_as_bytes("res://data/derived/elevation/fuji_vertices.bin")
    var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/elevation/terrain_geometry.json"))
    view.height_scale=meta.height_scale
    view.fuji_rect=Rect2(Vector2(meta.fuji_detail.origin[0],meta.fuji_detail.origin[1]),Vector2.ONE*float(meta.fuji_detail.span))
    view.fuji_step=meta.fuji_detail.step_world
    var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/elevation/terrain_chunks/manifest.json"))
    if old.terrain_sha256!=view.bytes_sha256(view.height_data) or old.fuji_sha256!=view.bytes_sha256(view.fuji_data) or old.geometry_sha256!=view.bytes_sha256(FileAccess.get_file_as_bytes("res://data/derived/elevation/terrain_geometry.json")):
        printerr("ERROR: Uniform terrain bake is stale; run tools/godot/build_terrain_meshes.gd first")
        view.free();quit(1);return
    var directory := "res://data/derived/elevation/terrain_adaptive_chunks"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    var entries: Array=[]
    var total_base := 0
    var total_coarse := 0
    for y in range(0,8192,1024):
        for x in range(0,8192,1024):
            var region := Rect2(x,y,1024,1024)
            var source: Array=view._geometry_arrays(region,16,false)
            var base: Dictionary=Adaptive.simplify(source,65,65,16.0,view.height_scale*3.0,0.97,0.01,view.fuji_rect.grow(32),true)
            var coarse: Dictionary=Adaptive.simplify(source,65,65,16.0,view.height_scale*64.0,0.0,0.04,view.fuji_rect.grow(32),true)
            var paths: Array[String]=[]
            for level in 2:
                var result: Dictionary=base if level==0 else coarse
                var resource := Chunk.new()
                resource.mesh=ArrayMesh.new()
                resource.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result.arrays)
                resource.data={"region":region,"step":16,"error":result.error,"vertices":result.arrays[Mesh.ARRAY_VERTEX].size(),"indices":result.arrays[Mesh.ARRAY_INDEX].size()}
                var path := directory+"/%d_%d_%d.res" % [x/1024,y/1024,level]
                if ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS)!=OK:
                    view.free();quit(1);return
                paths.append(path)
            total_base+=base.arrays[Mesh.ARRAY_VERTEX].size()
            total_coarse+=coarse.arrays[Mesh.ARRAY_VERTEX].size()
            entries.append({"x":x,"y":y,"path":paths[0],"coarse_path":paths[1],"coarse_error":coarse.error})
    old.chunks=entries
    old["adaptive_version"]=Adaptive.VERSION
    old["uniform_vertices"]=64*65*65
    old["base_vertices"]=total_base
    old["coarse_vertices"]=total_coarse
    var file := FileAccess.open(directory+"/manifest.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(old,"  "))
    file.close()
    print("ADAPTIVE_BAKE base=",total_base," coarse=",total_coarse," original=",64*65*65)
    view.free()
    quit(0)
