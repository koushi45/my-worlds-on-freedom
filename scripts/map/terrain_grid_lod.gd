extends RefCounted
const VERSION := 1
## Merge pairs of grid cells while keeping dense borders and measured samples.
## The center fan avoids T-junctions between dense and reduced neighbors.

static func simplify(arrays: Array, columns: int, rows: int, step: float, tolerance: float, minimum_up: float, normal_error: float, protected: Rect2 = Rect2(), preserve_lines: bool = false) -> Dictionary:
    var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var blocks_x := (columns-1)/2
    var blocks_y := (rows-1)/2
    if (columns-1)%2!=0 or (rows-1)%2!=0:
        return {"arrays":arrays,"error":0.0,"merged":0}
    var reduced := PackedByteArray()
    var errors := PackedFloat32Array()
    reduced.resize(blocks_x*blocks_y)
    errors.resize(reduced.size())
    for by in blocks_y:
        for bx in blocks_x:
            var a := by*2*columns+bx*2
            var b := a+2
            var c := a+2*columns
            var d := c+2
            var world := Vector2(vertices[a].x,vertices[a].z)+Vector2(4096,4096)
            if protected.has_area() and protected.intersects(Rect2(world,Vector2.ONE*step*2.0)): continue
            var candidates := [a+1,b+columns,c+1,a+columns,a+columns+1]
            var pairs := [[a,b],[b,d],[c,d],[a,c],[b,c]]
            var error := 0.0
            var acceptable := true
            for i in candidates.size():
                var v: int=candidates[i]
                var ends: Array=pairs[i]
                error=maxf(error,absf(vertices[v].y-(vertices[ends[0]].y+vertices[ends[1]].y)*0.5))
                if normals[v].y<minimum_up or normals[v].distance_to((normals[ends[0]]+normals[ends[1]])*0.5)>normal_error:
                    acceptable=false
            for v in [a,b,c,d]:
                if normals[v].y<minimum_up: acceptable=false
            if acceptable and error<=tolerance:
                reduced[by*blocks_x+bx]=1
                # Both source and reduced triangles are within this envelope
                # of the two coarse corner planes, hence their difference <=2e.
                errors[by*blocks_x+bx]=error*2.0
    var indices := PackedInt32Array()
    var merged := 0
    var maximum_error := 0.0
    for by in blocks_y:
        for bx in blocks_x:
            var a := by*2*columns+bx*2
            var b := a+2
            var c := a+2*columns
            var d := c+2
            var use_reduced: bool=reduced[by*blocks_x+bx]!=0
            var ring: Array[int]=[a]
            if use_reduced:
                var world := Vector2(vertices[a].x,vertices[a].z)+Vector2(4096,4096)
                var keep_top: bool=by==0 or reduced[(by-1)*blocks_x+bx]==0 or preserve_lines and int(round(world.y))%128==0
                var keep_right: bool=bx==blocks_x-1 or reduced[by*blocks_x+bx+1]==0 or preserve_lines and int(round(world.x+step*2.0))%128==0
                var keep_bottom: bool=by==blocks_y-1 or reduced[(by+1)*blocks_x+bx]==0 or preserve_lines and int(round(world.y+step*2.0))%128==0
                var keep_left: bool=bx==0 or reduced[by*blocks_x+bx-1]==0 or preserve_lines and int(round(world.x))%128==0
                if keep_top: ring.append(a+1)
                ring.append(b)
                if keep_right: ring.append(b+columns)
                ring.append(d)
                if keep_bottom: ring.append(c+1)
                ring.append(c)
                if keep_left: ring.append(a+columns)
                use_reduced=ring.size()<8
            if use_reduced:
                var center := a+columns+1
                for i in ring.size():
                    indices.append(center)
                    indices.append(ring[i])
                    indices.append(ring[(i+1)%ring.size()])
                merged+=1
                maximum_error=maxf(maximum_error,errors[by*blocks_x+bx])
            else:
                for y in 2:
                    for x in 2:
                        var v := a+y*columns+x
                        indices.append_array(PackedInt32Array([v,v+1,v+columns,v+1,v+columns+1,v+columns]))
    var remap := PackedInt32Array()
    remap.resize(vertices.size())
    remap.fill(-1)
    var kept_vertices := PackedVector3Array()
    var kept_normals := PackedVector3Array()
    var kept_uv := PackedVector2Array()
    var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
    for i in indices.size():
        var old := indices[i]
        if remap[old]<0:
            remap[old]=kept_vertices.size()
            kept_vertices.append(vertices[old])
            kept_normals.append(normals[old])
            kept_uv.append(uv[old])
        indices[i]=remap[old]
    var result: Array=[]
    result.resize(Mesh.ARRAY_MAX)
    result[Mesh.ARRAY_VERTEX]=kept_vertices
    result[Mesh.ARRAY_NORMAL]=kept_normals
    result[Mesh.ARRAY_TEX_UV]=kept_uv
    result[Mesh.ARRAY_INDEX]=indices
    return {"arrays":result,"error":maximum_error,"merged":merged}
