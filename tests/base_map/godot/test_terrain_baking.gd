extends SceneTree
const View = preload("res://scripts/map/map_view_3d.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
    if not value:
        failures+=1
        printerr("FAIL: ",message)
func run() -> void:
    var view := View.new()
    view.height_data=FileAccess.get_file_as_bytes("res://data/derived/elevation/terrain_vertices.bin")
    view.fuji_data=FileAccess.get_file_as_bytes("res://data/derived/elevation/fuji_vertices.bin")
    var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/elevation/terrain_geometry.json"))
    view.height_scale=meta.height_scale
    view.fuji_rect=Rect2(Vector2(meta.fuji_detail.origin[0],meta.fuji_detail.origin[1]),Vector2.ONE*float(meta.fuji_detail.span))
    view.fuji_step=meta.fuji_detail.step_world
    view.terrain_hash=view.bytes_sha256(view.height_data)
    view.fuji_hash=view.bytes_sha256(view.fuji_data)
    view.geometry_hash=view.bytes_sha256(FileAccess.get_file_as_bytes("res://data/derived/elevation/terrain_geometry.json"))
    var vertices_checked := 0
    for sample in [{"rect":Rect2(4480,5120,96,96),"step":16.0,"fine":false},{"rect":Rect2(4480,5120,64,64),"step":2.0,"fine":true},{"rect":view.fuji_rect,"step":view.fuji_step,"fine":true}]:
        var region: Rect2=sample.rect
        var step: float=sample.step
        var arrays: Array=view._geometry_arrays(region,step,sample.fine)
        var columns := int(region.size.x/step)+1
        var rows := int(region.size.y/step)+1
        var morph: Rect2=region if sample.fine else Rect2()
        for y in rows:
            for x in columns:
                var point := region.position+Vector2(x,y)*step
                # Reference calculation before memoizing vertex heights.
                var h: float=view._vertex_height(point,morph)
                var dx: float=view._vertex_height(point+Vector2(step,0),morph)-view._vertex_height(point-Vector2(step,0),morph)
                var dz: float=view._vertex_height(point+Vector2(0,step),morph)-view._vertex_height(point-Vector2(0,step),morph)
                check(arrays[Mesh.ARRAY_VERTEX][y*columns+x]==Vector3(point.x-4096,h,point.y-4096),"identical vertex")
                check(arrays[Mesh.ARRAY_NORMAL][y*columns+x]==Vector3(-dx,2*step,-dz).normalized(),"identical normal")
                vertices_checked+=1
        for y in rows-1:
            for x in columns-1:
                var a:=y*columns+x
                var i:=(y*(columns-1)+x)*6
                check(arrays[Mesh.ARRAY_INDEX].slice(i,i+6)==PackedInt32Array([a,a+1,a+columns,a+1,a+columns+1,a+columns]),"identical triangle indices")
    check(view._baked_terrain("far",Rect2(0,0,8192,8192),16)!=null,"far bake matches source")
    check(view._baked_terrain("fuji",view.fuji_rect,view.fuji_step)!=null,"Fuji bake matches source")
    view.geometry_hash="changed"
    check(view._baked_terrain("far",Rect2(0,0,8192,8192),16)==null,"stale bake rejected")
    view.free()
    print("TERRAIN_BAKING ","PASS" if failures==0 else "FAIL"," exact_vertices_and_normals=",vertices_checked)
    quit(0 if failures==0 else 1)
