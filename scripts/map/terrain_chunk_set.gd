extends RefCounted
## Exact terrain tiles. Visible geometry and offscreen shadow casters are retained.
const FAR_SIDE := 1024
const NEAR_SIDE := 128
const CACHE_LIMIT := 64
const JOB_BYTES := 768*1024
var view: Node3D
var manifest: Dictionary = {}
var far_nodes: Dictionary = {}
var near_nodes: Dictionary = {}
var near_cache: Dictionary = {}
var jobs: Dictionary = {}
var wanted: Dictionary = {}
var active_keys: Dictionary = {}
var serial := 0
var near_builds := 0
var near_reuses := 0
var far_loads := 0
var far_releases := 0
var far_lod_switches := 0
var last_visibility: Array = []
var wanted_region := Rect2()
var wanted_active := false

func load_manifest() -> bool:
    var path := "res://data/derived/elevation/terrain_chunks/manifest.json"
    var adaptive_path := "res://data/derived/elevation/terrain_adaptive_chunks/manifest.json"
    if view.adaptive_terrain and FileAccess.file_exists(adaptive_path): path=adaptive_path
    if not FileAccess.file_exists(path): return false
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary or data.get("version",0)!=1 or data.get("chunk_side",0)!=FAR_SIDE: return false
    if path==adaptive_path and data.get("adaptive_version",0)!=preload("res://scripts/map/terrain_grid_lod.gd").VERSION: return false
    if data.get("terrain_sha256","")!=view.terrain_hash or data.get("fuji_sha256","")!=view.fuji_hash or data.get("geometry_sha256","")!=view.geometry_hash: return false
    manifest=data
    return true

func _coarse_pixel_error(region: Rect2, error: float) -> float:
    if not view.oblique or error<=0.000001: return 0.0
    var inverse: Transform3D=view.view_camera.global_transform.affine_inverse()
    var height: float=maxf(view.max_height,float(manifest.get("culling_height",view.max_height)))
    var depth := INF
    var horizontal := 0.0
    var vertical := 0.0
    for x in [region.position.x,region.end.x]:
        for z in [region.position.y,region.end.y]:
            for y in [0.0,height]:
                var point: Vector3=inverse*Vector3(x-4096,y,z-4096)
                depth=minf(depth,-point.z)
                horizontal=maxf(horizontal,absf(point.x))
                vertical=maxf(vertical,absf(point.y))
    if depth<=view.view_camera.near+error: return INF
    var pixels: float=view.main.get_viewport().size.y/(2.0*tan(deg_to_rad(view.view_camera.fov*0.5)))
    var sun_ray: Vector3=-view.sun.global_transform.basis.z
    var directions := [Vector3.UP,Vector3(sun_ray.x/maxf(absf(sun_ray.y),0.001),0,sun_ray.z/maxf(absf(sun_ray.y),0.001))]
    var result := 0.0
    for direction in directions:
        var delta: Vector3=inverse.basis*direction
        var lower := depth-error*absf(delta.z)
        if lower<=view.view_camera.near: return INF
        var dx := pixels*error*(absf(delta.x)/lower+horizontal*absf(delta.z)/(lower*lower))
        var dy := pixels*error*(absf(delta.y)/lower+vertical*absf(delta.z)/(lower*lower))
        result=maxf(result,Vector2(dx,dy).length())
    return result

func _visible(region: Rect2, planes: Array[Plane]) -> bool:
    # Include any offscreen terrain able to cast a shadow onto visible ground.
    # Sun rays travel downwards, and measured terrain cannot go below y=0.
    var bound: float = maxf(view.max_height,float(manifest.get("culling_height",view.max_height)))
    var ray: Vector3 = -view.sun.global_transform.basis.z
    var reach := Vector2(absf(ray.x),absf(ray.z))*bound/maxf(absf(ray.y),0.001)+Vector2.ONE*2.0
    var low := region.position-reach-Vector2(4096,4096)
    var high := region.end+reach-Vector2(4096,4096)
    for plane in planes:
        var nearest := Vector3(low.x if plane.normal.x>=0.0 else high.x,0.0 if plane.normal.y>=0.0 else bound,low.y if plane.normal.z>=0.0 else high.y)
        if plane.distance_to(nearest)>0.01: return false
    return true

func update_visibility(force: bool = false) -> void:
    var state := [view.view_camera.global_transform,view.view_camera.fov,view.view_camera.size,view.main.get_viewport_rect().size,view.oblique,view.fine_rect,view.fine_surface.visible,view.fuji_surface.visible]
    if not force and state==last_visibility: return
    last_visibility=state
    var planes: Array[Plane] = view.view_camera.get_frustum()
    var required := {}
    for entry in manifest.chunks:
        var region := Rect2(Vector2(entry.x,entry.y),Vector2.ONE*FAR_SIDE)
        if not _visible(region,planes): continue
        var key: String = entry.path
        required[key]=true
        var selected := key
        var coarse := false
        if entry.has("coarse_path"):
            var was_coarse: bool=far_nodes.has(key) and far_nodes[key].get_meta("coarse",false)
            if _coarse_pixel_error(region,float(entry.coarse_error))<=(0.5 if was_coarse else 0.35):
                selected=entry.coarse_path
                coarse=true
        if far_nodes.has(key) and far_nodes[key].get_meta("selected_path",key)==selected: continue
        # Small baked tiles load before the frame draws, avoiding missing ground
        # during fast turns. No nationwide mesh or cache is retained alongside.
        var resource: Resource = ResourceLoader.load(selected,"",ResourceLoader.CACHE_MODE_IGNORE)
        var mesh: ArrayMesh
        if resource!=null: mesh=resource.mesh
        if mesh==null:
            mesh=ArrayMesh.new()
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,view._geometry_arrays(region,view.STEP,false))
        var node: MeshInstance3D
        if far_nodes.has(key):
            node=far_nodes[key]
            far_lod_switches+=1
        else:
            node=MeshInstance3D.new()
            view.surface.add_child(node)
        node.mesh=mesh
        node.material_override=view.surface_material
        node.set_meta("selected_path",selected)
        node.set_meta("coarse",coarse)
        far_nodes[key]=node
        far_loads+=1
    for key in far_nodes.keys():
        if not required.has(key):
            far_nodes[key].free()
            far_nodes.erase(key)
            far_releases+=1
    for key in near_nodes:
        near_nodes[key].visible=_visible(active_keys[key],planes)

func _near_tiles(region: Rect2) -> Dictionary:
    var result := {}
    for y in range(int(region.position.y),int(region.end.y),NEAR_SIDE):
        for x in range(int(region.position.x),int(region.end.x),NEAR_SIDE):
            var tile := Rect2(x,y,minf(NEAR_SIDE,region.end.x-x),minf(NEAR_SIDE,region.end.y-y))
            # Normals use a 2-unit halo. Only tiles touching an outer morph band
            # vary with that edge; interior tile geometry is independent of it.
            var mask := 0
            if x-region.position.x<34.0: mask|=1
            if region.end.x-tile.end.x<34.0: mask|=2
            if y-region.position.y<34.0: mask|=4
            if region.end.y-tile.end.y<34.0: mask|=8
            var key := "%d:%d:%d:%d:%d" % [x,y,int(tile.size.x),int(tile.size.y),mask]
            result[key]=tile
    return result

func _trim_cache() -> void:
    for key in near_cache.keys():
        if near_cache.size()<=CACHE_LIMIT: break
        if not active_keys.has(key) and not wanted.has(key): near_cache.erase(key)

func update_near() -> void:
    var active: bool = view.oblique and view.main.camera.zoom.x>=4.0
    var desired: Rect2 = view._desired_fine_rect()
    if active!=wanted_active or active and desired!=wanted_region:
        wanted=_near_tiles(desired) if active else {}
        wanted_region=desired
        wanted_active=active
    var complete := true
    for key in jobs.keys():
        var job: Dictionary = jobs[key]
        if not view.main.cpu_jobs.is_complete(job.id): continue
        var arrays: Array = view.main.cpu_jobs.take(job.id)
        job.worker.free()
        jobs.erase(key)
        if not wanted.has(key):
            view.obsolete_fine_jobs+=1
            continue
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        near_cache[key]=mesh
        near_builds+=1
        view.geometry_builds+=1
    for key in wanted:
        if near_cache.has(key): continue
        complete=false
        if jobs.has(key): continue
        if jobs.size()>=mini(2,view.main.cpu_jobs.limit) or view.main.cpu_jobs.jobs.size()>=view.main.cpu_jobs.limit: continue
        var worker: Node3D = view.get_script().new()
        worker.height_data=view.height_data
        worker.height_scale=view.height_scale
        worker.adaptive_terrain=view.adaptive_terrain
        worker.fuji_data=view.fuji_data
        worker.fuji_rect=view.fuji_rect
        worker.fuji_step=view.fuji_step
        var id := "near-tile:%d:%d" % [view.get_instance_id(),serial]
        serial+=1
        if not view.main.cpu_jobs.submit(id,worker._geometry_arrays.bind(wanted[key],2.0,true,desired),JOB_BYTES,serial):
            worker.free()
            continue
        jobs[key]={"id":id,"worker":worker}
    if active and complete and (desired!=view.fine_rect or near_nodes.is_empty()):
        # Switch the domain atomically: the previous complete region stays
        # displayed until every replacement tile (including seams) is ready.
        for key in near_nodes.keys():
            if not wanted.has(key):
                near_nodes[key].free()
                near_nodes.erase(key)
        for key in wanted:
            if near_nodes.has(key):
                near_reuses+=1
                continue
            var node := MeshInstance3D.new()
            node.mesh=near_cache[key]
            node.material_override=view.fine_material
            view.fine_surface.add_child(node)
            near_nodes[key]=node
        active_keys=wanted.duplicate()
        view.fine_rect=desired
        view.marker_visibility.clear()
        view.last_state=[]
    view.fine_job=0 if active and not complete or not jobs.is_empty() else -1
    view.fine_surface.visible=active and view.fine_rect.has_area()
    view.fuji_surface.visible=view.fine_surface.visible and view.fine_rect.encloses(view.fuji_rect.grow(32.0))
    var shader_state := [view.fine_surface.visible,view.fuji_surface.visible,view.fine_rect]
    if shader_state!=view.fine_shader_state:
        view.fine_shader_state=shader_state
        for material in [view.surface_material,view.fine_material,view.fuji_material]:
            material.set_shader_parameter("fuji_active",view.fuji_surface.visible)
            material.set_shader_parameter("fuji_rect",Vector4(view.fuji_rect.position.x,view.fuji_rect.position.y,view.fuji_rect.end.x,view.fuji_rect.end.y))
        view.surface_material.set_shader_parameter("fine_active",view.fine_surface.visible)
        view.surface_material.set_shader_parameter("fine_rect",Vector4(view.fine_rect.position.x,view.fine_rect.position.y,view.fine_rect.end.x,view.fine_rect.end.y))
        view.last_state=[]
        view.marker_visibility.clear()
    _trim_cache()
    if not active:
        for node in near_nodes.values(): node.free()
        near_nodes.clear()
        active_keys.clear()
        near_cache.clear()
        view.fine_rect=Rect2()

func shutdown() -> void:
    if is_instance_valid(view.main) and is_instance_valid(view.main.cpu_jobs):
        for job in jobs.values():
            view.main.cpu_jobs.drain(job.id)
            job.worker.free()
    jobs.clear()
    near_cache.clear()
