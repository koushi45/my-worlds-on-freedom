extends SceneTree
const Adaptive=preload("res://scripts/map/terrain_grid_lod.gd")
var failures := 0
func check(value: bool, message: String) -> void:
    if not value:
        failures+=1
        printerr("FAIL: ",message)
func grid(rough: bool=false, steep: bool=false) -> Array:
    var result: Array=[]
    result.resize(Mesh.ARRAY_MAX)
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var indices := PackedInt32Array()
    for y in 17:
        for x in 17:
            var h := float(x)*0.01+float(y)*0.02
            if rough: h+=sin(float(x)*0.71)*cos(float(y)*0.53)*0.1
            vertices.append(Vector3(x*2-4096,h,y*2-4096))
            normals.append(Vector3(0.9,0.3,0).normalized() if steep else Vector3.UP)
            uv.append(Vector2(x*2,y*2)/8192.0)
    for y in 16:
        for x in 16:
            var a := y*17+x
            indices.append_array(PackedInt32Array([a,a+1,a+17,a+1,a+18,a+17]))
    result[Mesh.ARRAY_VERTEX]=vertices
    result[Mesh.ARRAY_NORMAL]=normals
    result[Mesh.ARRAY_TEX_UV]=uv
    result[Mesh.ARRAY_INDEX]=indices
    return result
func topology(arrays: Array) -> void:
    var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    var edges := {}
    var area := 0.0
    var border := {}
    for vertex in vertices:
        var point := Vector2(vertex.x,vertex.z)+Vector2(4096,4096)
        if point.x==0 or point.y==0 or point.x==32 or point.y==32: border[point]=true
    for i in range(0,indices.size(),3):
        var a := Vector2(vertices[indices[i]].x,vertices[indices[i]].z)
        var b := Vector2(vertices[indices[i+1]].x,vertices[indices[i+1]].z)
        var c := Vector2(vertices[indices[i+2]].x,vertices[indices[i+2]].z)
        var signed := (b-a).cross(c-a)
        check(signed>0,"consistent triangle orientation, no zero-area faces")
        area+=signed*0.5
        for pair in [[indices[i],indices[i+1]],[indices[i+1],indices[i+2]],[indices[i+2],indices[i]]]:
            var key := Vector2i(mini(pair[0],pair[1]),maxi(pair[0],pair[1]))
            edges[key]=edges.get(key,0)+1
    check(absf(area-1024)<0.001,"triangles cover the complete tile exactly")
    check(border.size()==64,"all dense border vertices retained")
    for key in edges:
        if edges[key]==1:
            var a: Vector3=vertices[key.x]+Vector3(4096,0,4096)
            var b: Vector3=vertices[key.y]+Vector3(4096,0,4096)
            check(a.x==b.x and (a.x==0 or a.x==32) or a.z==b.z and (a.z==0 or a.z==32),"no interior open edges or T-junctions")
        else: check(edges[key]==2,"manifold interior")
func _initialize() -> void:
    var flat: Array=grid()
    var reduced: Dictionary=Adaptive.simplify(flat,17,17,2.0,0.00001,0.97,0.01)
    check(reduced.arrays[Mesh.ARRAY_VERTEX].size()<flat[Mesh.ARRAY_VERTEX].size()*0.75,"flat terrain vertices reduced")
    check(reduced.arrays[Mesh.ARRAY_INDEX].size()<flat[Mesh.ARRAY_INDEX].size()*0.8,"flat terrain triangles reduced")
    topology(reduced.arrays)
    var steep: Array=grid(false,true)
    check(Adaptive.simplify(steep,17,17,2.0,0.00001,0.97,0.01).arrays[Mesh.ARRAY_VERTEX].size()==steep[Mesh.ARRAY_VERTEX].size(),"steep slopes keep dense grid")
    var rough: Array=grid(true)
    var mixed: Dictionary=Adaptive.simplify(rough,17,17,2.0,0.005,0.97,0.01)
    topology(mixed.arrays)
    check(mixed.error<=0.010001,"bounded coarse plane deviation")
    var protected: Dictionary=Adaptive.simplify(flat,17,17,2.0,0.00001,0.97,0.01,Rect2(0,0,32,32))
    check(protected.arrays[Mesh.ARRAY_VERTEX].size()==flat[Mesh.ARRAY_VERTEX].size(),"protected detail retains all samples")
    var lines: Array=grid()
    var scaled: PackedVector3Array=lines[Mesh.ARRAY_VERTEX]
    for i in scaled.size():
        scaled[i]=Vector3((scaled[i].x+4096)*8-4096,scaled[i].y,(scaled[i].z+4096)*8-4096)
    lines[Mesh.ARRAY_VERTEX]=scaled
    var corridors: Dictionary=Adaptive.simplify(lines,17,17,16.0,0.00001,0.97,0.01,Rect2(),true)
    var retained := {}
    for vertex in corridors.arrays[Mesh.ARRAY_VERTEX]: retained[Vector2(vertex.x,vertex.z)+Vector2(4096,4096)]=true
    for i in 17:
        check(retained.has(Vector2(128,i*16)) and retained.has(Vector2(i*16,128)),"potential near-domain seams retain dense far vertices")
    print("TERRAIN_ADAPTIVE ","PASS" if failures==0 else "FAIL"," flat_vertices=",reduced.arrays[Mesh.ARRAY_VERTEX].size()," original=",flat[Mesh.ARRAY_VERTEX].size()," merged=",reduced.merged)
    quit(0 if failures==0 else 1)
