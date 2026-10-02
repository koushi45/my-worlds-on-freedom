extends Node3D
## Measured terrain, streamed fine geometry, and a south-facing perspective camera.
## Existing geographic layers render into the atlas; UI never enters that viewport.
const SurfaceShader = preload("res://scripts/map/map_surface_3d.gdshader")
const CENTER := Vector2(4096,4096)
const STEP := 16
const SIDE := 513
const CAMERA_DISTANCE := 20000.0
const ANGLES := [75.0,60.0,40.0,25.0,15.0]
const ZOOMS := [1.0,2.0,4.0,6.0,8.0]
var main: Node2D
var source_view: SubViewport
var source_root: Node2D
var source_camera: Camera2D
var view_camera: Camera3D
var surface: MeshInstance3D
var surface_material: ShaderMaterial
var markers: Node2D
var oblique := true
var angle := 75.0
var manual_angle := -1.0
var yaw := 0.0
const ORBIT_SENSITIVITY := 0.25

func target_angle() -> float:
    return (manual_angle if manual_angle >= 0.0 else angle_for_zoom(main.camera.zoom.x)) if oblique else 90.0

func orbit(relative: Vector2) -> void:
    if not oblique: main.set_oblique(true)
    manual_angle = clampf(angle + relative.y * ORBIT_SENSITIVITY,15.0,90.0)
    angle = manual_angle
    yaw = wrapf(yaw-relative.x*ORBIT_SENSITIVITY,-180.0,180.0)
    anchor_world = Vector2(INF,INF)
    sync(true)
var max_height := 0.0
var visible_rect := Rect2()
var geometry_builds := 0
var terrain_vertices := PackedVector3Array()
var last_state: Array = []
var anchor_world := Vector2(INF,INF)
var anchor_screen := Vector2.ZERO
var requested_zoom := 0.5
var updating_zoom := false
var marker_visibility: Dictionary = {}
var height_data := PackedByteArray()
var height_scale := 0.00882632187962517
var fuji_data := PackedByteArray()
var fuji_rect := Rect2()
var fuji_step := 0.25
var fuji_surface: MeshInstance3D
var fuji_material: ShaderMaterial
var fine_surface: MeshInstance3D
var fine_material: ShaderMaterial
var fine_rect := Rect2()
var fine_job_rect := Rect2()
var fine_job := -1
var fine_arrays: Array = []
var fine_worker: Node3D
var fine_key := ""
var fine_serial := 0
var fine_cache: Dictionary = {}
var terrain_chunks: RefCounted
var chunked_terrain := true
var adaptive_terrain := true
var fine_shader_state: Array = []
var obsolete_fine_jobs := 0
var sun: DirectionalLight3D
var environment_resource: Environment
var terrain_materials: RefCounted
var ray_bounds := PackedByteArray()
var ray_tiers: Array = []
var ray_bounds_enabled := true
var ray_cells_tested := 0
var ray_blocks_skipped := 0
var terrain_hash := ""
var fuji_hash := ""
var geometry_hash := ""

func _exit_tree() -> void:
    if terrain_chunks!=null: terrain_chunks.shutdown()
    if fine_job >= 0 and not chunked_terrain and is_instance_valid(main.cpu_jobs): main.cpu_jobs.drain(fine_key)
    if is_instance_valid(fine_worker): fine_worker.free()
    if terrain_materials!=null: terrain_materials.shutdown()

static func angle_for_zoom(zoom: float) -> float:
    if zoom <= 1.0: return ANGLES[0]
    for i in range(1,ZOOMS.size()):
        if zoom <= ZOOMS[i]:
            var t := log(zoom/ZOOMS[i-1])/log(ZOOMS[i]/ZOOMS[i-1])
            return lerpf(ANGLES[i-1],ANGLES[i],t)
    return ANGLES[-1]

func _ready() -> void:
    adaptive_terrain="--uniform-terrain" not in OS.get_cmdline_user_args() and "--legacy-terrain" not in OS.get_cmdline_user_args()
    source_view = SubViewport.new()
    source_view.name = "GeographicSurface"
    source_view.world_2d = World2D.new()
    source_view.disable_3d = true
    source_view.gui_disable_input = true
    source_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    source_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
    add_child(source_view)
    source_root = Node2D.new()
    source_view.add_child(source_root)
    source_camera = Camera2D.new()
    source_camera.ignore_rotation = false
    source_root.add_child(source_camera)
    view_camera = Camera3D.new()
    view_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    view_camera.keep_aspect = Camera3D.KEEP_HEIGHT
    view_camera.near = 1.0
    view_camera.far = 50000.0
    add_child(view_camera)
    view_camera.make_current()
    surface_material = ShaderMaterial.new()
    surface_material.shader = SurfaceShader
    surface_material.set_shader_parameter("surface_map",source_view.get_texture())
    surface_material.set_shader_parameter("far_albedo",load("res://assets/map/elevation/terrain_albedo.png"))
    height_data = FileAccess.get_file_as_bytes("res://data/derived/elevation/terrain_vertices.bin")
    var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/elevation/terrain_geometry.json"))
    height_scale = float(metadata.height_scale)
    var detail: Dictionary = metadata.fuji_detail
    fuji_data = FileAccess.get_file_as_bytes("res://"+str(detail.file))
    fuji_rect = Rect2(Vector2(detail.origin[0],detail.origin[1]),Vector2.ONE*float(detail.span))
    fuji_step = float(detail.step_world)
    terrain_hash = bytes_sha256(height_data)
    fuji_hash = bytes_sha256(fuji_data)
    geometry_hash = bytes_sha256(FileAccess.get_file_as_bytes("res://data/derived/elevation/terrain_geometry.json"))
    _load_ray_bounds()
    surface = MeshInstance3D.new()
    terrain_chunks = preload("res://scripts/map/terrain_chunk_set.gd").new()
    terrain_chunks.view = self
    chunked_terrain = "--legacy-terrain" not in OS.get_cmdline_user_args() and terrain_chunks.load_manifest()
    if chunked_terrain:
        max_height = maxf(float(terrain_chunks.manifest.max_height),4000.0*height_scale)
    else:
        var far_chunk := _baked_terrain("far",Rect2(0,0,8192,8192),STEP)
        if far_chunk!=null:
            surface.mesh = far_chunk.mesh
            max_height = maxf(float(far_chunk.data.max_height),4000.0*height_scale)
        else: surface.mesh = _build_mesh()
    surface.material_override = surface_material
    add_child(surface)
    fine_material = surface_material.duplicate() as ShaderMaterial
    fine_material.set_shader_parameter("is_fine",true)
    fine_surface = MeshInstance3D.new()
    fine_surface.material_override = fine_material
    fine_surface.visible = false
    add_child(fine_surface)
    fuji_material = surface_material.duplicate() as ShaderMaterial
    fuji_material.set_shader_parameter("is_fine",true)
    fuji_material.set_shader_parameter("is_fuji",true)
    fuji_surface = MeshInstance3D.new()
    var fuji_chunk := _baked_terrain("fuji",fuji_rect,fuji_step)
    var fuji_mesh: ArrayMesh
    if fuji_chunk!=null: fuji_mesh = fuji_chunk.mesh
    else:
        fuji_mesh = ArrayMesh.new()
        fuji_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_geometry_arrays(fuji_rect,fuji_step,true))
    fuji_surface.mesh = fuji_mesh
    fuji_surface.material_override = fuji_material
    fuji_surface.visible = false
    add_child(fuji_surface)
    terrain_materials = preload("res://scripts/map/terrain_material_set.gd").new()
    terrain_materials.apply(surface_material)
    terrain_materials.apply(fine_material)
    terrain_materials.apply(fuji_material)
    _setup_lighting()
    # A solid sea beyond the finite geographic canvas prevents blank edges.
    var sea := MeshInstance3D.new()
    sea.name = "OuterSea"
    sea.mesh = _build_outer_sea_mesh()
    var sea_style := StandardMaterial3D.new()
    sea_style.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sea_style.albedo_color = Color("#1d3948")
    sea.material_override = sea_style
    add_child(sea)
    var screen_layer := CanvasLayer.new()
    screen_layer.name = "GeographicMarkers"
    screen_layer.layer = 1
    main.add_child(screen_layer)
    markers = preload("res://scripts/map/map_screen_markers.gd").new()
    markers.main = main
    screen_layer.add_child(markers)
    main.camera.enabled = false
    requested_zoom = main.camera.zoom.x
    # Move only world drawings. Nested legends remain attached to the main viewport.
    for child in main.get_children():
        if child is Node2D and child != main.camera: adopt_layer(child)
    main.child_entered_tree.connect(_on_main_child)
    sync(true)

static func _build_outer_sea_mesh() -> ArrayMesh:
    # Leave the entire geographic surface uncovered. A full plane just 0.1
    # below it loses depth precision at low zoom and cuts stripes into coasts.
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    for bounds in [
        Rect2(-32768,-32768,65536,28672),
        Rect2(-32768,4096,65536,28672),
        Rect2(-32768,-4096,28672,8192),
        Rect2(4096,-4096,28672,8192),
    ]:
        var start := vertices.size()
        for point in [bounds.position,Vector2(bounds.end.x,bounds.position.y),Vector2(bounds.position.x,bounds.end.y),bounds.end]:
            vertices.append(Vector3(point.x,0.0,point.y))
            normals.append(Vector3.UP)
        indices.append_array(PackedInt32Array([start,start+1,start+2,start+1,start+3,start+2]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    return mesh

func _setup_lighting() -> void:
    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment_resource = environment
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("#70adc7")
    sky_material.sky_horizon_color = Color("#c6dee2")
    sky_material.ground_horizon_color = Color("#c6dee2")
    sky_material.ground_bottom_color = Color("#c6dee2")
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#d6e1e5")
    environment.ambient_light_energy = 0.40
    environment.fog_mode = Environment.FOG_MODE_DEPTH
    environment.fog_light_color = Color("#c6dee2")
    environment.fog_density = 0.98
    environment.fog_sky_affect = 0.0
    environment_node.environment = environment
    add_child(environment_node)
    sun = DirectionalLight3D.new()
    sun.light_color = Color("#fff3dc")
    sun.light_energy = 0.45
    sun.shadow_enabled = true
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    sun.directional_shadow_max_distance = 900.0
    sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
    add_child(sun)
    sun.look_at(-Vector3(-0.55,0.78,-0.65),Vector3.UP)

func _on_main_child(child: Node) -> void:
    if child is Node2D and child != main.camera: adopt_layer.call_deferred(child)

func adopt_layer(layer: Node2D) -> void:
    if not is_instance_valid(layer) or layer.get_parent() == source_root: return
    _retain_ui(layer)
    layer.reparent(source_root,false)

func _retain_ui(node: Node) -> void:
    for child in node.get_children():
        if child is CanvasLayer: child.reparent(main,false)
        else: _retain_ui(child)

func _build_mesh() -> ArrayMesh:
    var arrays := _geometry_arrays(Rect2(Vector2.ZERO,Vector2(8192,8192)),STEP,false)
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    for vertex in arrays[Mesh.ARRAY_VERTEX]: max_height = maxf(max_height,vertex.y)
    max_height = maxf(max_height,4000.0*height_scale)
    geometry_builds += 1
    return mesh

func _node_height(point: Vector2) -> float:
    var x := clampi(roundi(point.x/2.0),0,4096)
    var y := clampi(roundi(point.y/2.0),0,4096)
    var base: float = height_data.decode_u16((y*4097+x)*2)*height_scale
    if not fuji_rect.has_point(point): return base
    var grid := (point-fuji_rect.position)/fuji_step
    var cell := Vector2i(grid.floor()).min(Vector2i(511,511))
    var f := grid-Vector2(cell)
    var index := cell.y*513+cell.x
    var a: float = fuji_data.decode_u16(index*2)
    var b: float = fuji_data.decode_u16((index+1)*2)
    var c: float = fuji_data.decode_u16((index+513)*2)
    var d: float = fuji_data.decode_u16((index+514)*2)
    var measured := lerpf(lerpf(a,b,f.x),lerpf(c,d,f.x),f.y)*height_scale
    var edge := minf(minf(point.x-fuji_rect.position.x,fuji_rect.end.x-point.x),minf(point.y-fuji_rect.position.y,fuji_rect.end.y-point.y))
    return lerpf(base,measured,smoothstep(0.0,16.0,edge))

func _triangle_height(point: Vector2, step: float, region: Rect2 = Rect2()) -> float:
    if point.x<0 or point.y<0 or point.x>8192 or point.y>8192: return 0.0
    var cell := (point/step).floor()*step
    cell = cell.min(Vector2(8192-step,8192-step))
    var f := (point-cell)/step
    var a := _vertex_height(cell,region)
    var b := _vertex_height(cell+Vector2(step,0),region)
    var c := _vertex_height(cell+Vector2(0,step),region)
    var d := _vertex_height(cell+Vector2(step,step),region)
    if f.x+f.y<=1: return a+(b-a)*f.x+(c-a)*f.y
    return d+(c-d)*(1-f.x)+(b-d)*(1-f.y)

func _vertex_height(point: Vector2, region: Rect2) -> float:
    var height := _node_height(point)
    if region.has_area():
        var edge := minf(minf(point.x-region.position.x,region.end.x-point.x),minf(point.y-region.position.y,region.end.y-point.y))
        # Exact coarse triangle heights on the edge prevent cracks at a LOD seam.
        var parent_step: float = 2.0 if region == fuji_rect else float(STEP)
        var band: float = 4.0 if region == fuji_rect else 32.0
        if edge<band: height = lerpf(_triangle_height(point,parent_step),height,smoothstep(0.0,band,edge))
    return height

func _geometry_arrays(region: Rect2, step: float, fine: bool, morph_region: Rect2 = Rect2()) -> Array:
    var columns := int(region.size.x/step)+1
    var rows := int(region.size.y/step)+1
    var reduce_grid := adaptive_terrain and fine and step==2.0 and region!=fuji_rect and (columns-1)%2==0 and (rows-1)%2==0
    var morph := (morph_region if morph_region.has_area() else region) if fine else Rect2()
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var indices := PackedInt32Array()
    vertices.resize(columns*rows)
    normals.resize(columns*rows)
    uv.resize(columns*rows)
    var heights := PackedFloat64Array()
    var stride := columns+2
    heights.resize(stride*(rows+2))
    for y in range(-1,rows+1):
        for x in range(-1,columns+1):
            heights[(y+1)*stride+x+1] = _vertex_height(region.position+Vector2(x,y)*step,morph)
    for y in rows:
        for x in columns:
            var point := region.position+Vector2(x,y)*step
            var sample_index := (y+1)*stride+x+1
            var h := heights[sample_index]
            var dx := heights[sample_index+1]-heights[sample_index-1]
            var dz := heights[sample_index+stride]-heights[sample_index-stride]
            vertices[y*columns+x] = Vector3(point.x-CENTER.x,h,point.y-CENTER.y)
            normals[y*columns+x] = Vector3(-dx,2.0*step,-dz).normalized()
            uv[y*columns+x] = point/8192.0
    heights=PackedFloat64Array()
    if not reduce_grid:
        indices.resize((columns-1)*(rows-1)*6)
        for y in rows-1:
            for x in columns-1:
                var a := y*columns+x
                var i := (y*(columns-1)+x)*6
                indices[i]=a;indices[i+1]=a+1;indices[i+2]=a+columns
                indices[i+3]=a+1;indices[i+4]=a+columns+1;indices[i+5]=a+columns
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_INDEX] = indices
    if reduce_grid:
        return preload("res://scripts/map/terrain_grid_lod.gd").simplify(arrays,columns,rows,step,height_scale*3.0,0.97,0.01,fuji_rect.grow(32)).arrays
    return arrays

func _desired_fine_rect() -> Rect2:
    var center: Vector2 = (main.camera.position/128.0).floor()*128.0
    var desired := Rect2((center-Vector2(256,768)).max(Vector2.ZERO),Vector2(512,1024))
    desired.size = desired.size.min(Vector2(8192,8192)-desired.position)
    return desired

func _apply_fine_mesh(mesh: ArrayMesh, region: Rect2) -> void:
    fine_surface.mesh = mesh
    fine_rect = region
    marker_visibility.clear()
    last_state = []

func _update_fine() -> void:
    if get_meta("probe_freeze_near",false): return
    if chunked_terrain:
        terrain_chunks.update_near()
        return
    var active: bool = oblique and main.camera.zoom.x>=4.0
    var desired := _desired_fine_rect()
    if fine_job>=0 and main.cpu_jobs.is_complete(fine_key):
        var arrays: Array = main.cpu_jobs.take(fine_key)
        fine_worker.free()
        fine_worker = null
        fine_job = -1
        if active and fine_job_rect==desired:
            var mesh := ArrayMesh.new()
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
            fine_cache[fine_job_rect] = mesh
            while fine_cache.size()>2: fine_cache.erase(fine_cache.keys()[0])
            _apply_fine_mesh(mesh,fine_job_rect)
            geometry_builds += 1
        else: obsolete_fine_jobs += 1
    if active and desired!=fine_rect and fine_cache.has(desired):
        _apply_fine_mesh(fine_cache[desired],desired)
    fine_surface.visible = active and fine_rect.has_area()
    fuji_surface.visible = fine_surface.visible and fine_rect.encloses(fuji_rect.grow(32.0))
    var shader_state := [fine_surface.visible,fuji_surface.visible,fine_rect]
    if shader_state!=fine_shader_state:
        fine_shader_state = shader_state
        for material in [surface_material,fine_material,fuji_material]:
            material.set_shader_parameter("fuji_active",fuji_surface.visible)
            material.set_shader_parameter("fuji_rect",Vector4(fuji_rect.position.x,fuji_rect.position.y,fuji_rect.end.x,fuji_rect.end.y))
        surface_material.set_shader_parameter("fine_active",fine_surface.visible)
        surface_material.set_shader_parameter("fine_rect",Vector4(fine_rect.position.x,fine_rect.position.y,fine_rect.end.x,fine_rect.end.y))
        last_state = []
        marker_visibility.clear()
    if not active or fine_job>=0 or desired==fine_rect: return
    # Snapshot owns immutable packed data. Workers never read camera/scene state.
    var worker: Node3D = get_script().new()
    worker.height_data = height_data
    worker.height_scale = height_scale
    worker.adaptive_terrain = adaptive_terrain
    worker.fuji_data = fuji_data
    worker.fuji_rect = fuji_rect
    worker.fuji_step = fuji_step
    var key := "near-terrain:"+str(get_instance_id())+":"+str(fine_serial)
    if not main.cpu_jobs.submit(key,worker._geometry_arrays.bind(desired,2.0,true),9*1024*1024,fine_serial):
        worker.free()
        return
    fine_key = key
    fine_job_rect = desired
    fine_worker = worker
    fine_job = fine_serial
    fine_serial += 1

func advance(delta: float) -> void:
    _update_fine()
    var zoom_before: float = main.camera.zoom.x
    if not is_equal_approx(zoom_before,requested_zoom):
        var zoom := lerpf(zoom_before,requested_zoom,1.0-exp(-24.0*delta))
        if absf(zoom-requested_zoom)<0.001: zoom = requested_zoom
        updating_zoom = true
        main.set_map_zoom(zoom)
        updating_zoom = false
    if terrain_materials.update(main.camera.zoom.x,requested_zoom):
        terrain_materials.apply(surface_material)
        terrain_materials.apply(fine_material)
        terrain_materials.apply(fuji_material)
    var target := target_angle()
    var previous := angle
    angle = move_toward(angle,target,240.0*delta)
    sync()
    if anchor_world.is_finite():
        pin_anchor()
    if is_equal_approx(angle,target) and is_equal_approx(main.camera.zoom.x,requested_zoom) and fine_job<0: anchor_world = Vector2(INF,INF)

func sync(force: bool = false, pose_only: bool = false) -> void:
    var size: Vector2 = main.get_viewport_rect().size
    var zoom: float = main.camera.zoom.x
    var state: Array = [size,zoom,main.camera.position,angle,oblique,yaw]
    if not pose_only:
        if not force and state == last_state: return
        last_state = state
        marker_visibility.clear()
    var a := deg_to_rad(angle)
    var focus := position_for(main.camera.position)
    if oblique: focus.y += max_height*0.68*clampf((zoom-4.0)/4.0,0.0,1.0)
    view_camera.size = size.y/zoom
    view_camera.projection = Camera3D.PROJECTION_PERSPECTIVE if oblique else Camera3D.PROJECTION_ORTHOGONAL
    view_camera.fov = 35.0
    var distance := size.y/(2.0*zoom*tan(deg_to_rad(view_camera.fov*0.5))) if oblique else CAMERA_DISTANCE
    var heading := deg_to_rad(yaw) if oblique else 0.0
    var camera_offset := Vector3(sin(heading)*cos(a),sin(a),cos(heading)*cos(a))
    # Retreat along the viewing axis if the camera would sit inside a mountain.
    for attempt in 12:
        var candidate := focus+camera_offset*distance
        var ground := _triangle_height(Vector2(candidate.x,candidate.z)+CENTER,STEP)
        if candidate.y>ground+4.0 or not oblique: break
        distance *= 1.15
    view_camera.position = focus+camera_offset*distance
    environment_resource.fog_enabled = oblique and zoom>=4.0
    environment_resource.fog_depth_begin = distance+250.0
    environment_resource.fog_depth_end = distance+3200.0
    if angle >= 89.999:
        view_camera.rotation = Vector3(-PI/2,heading,0)
    else:
        view_camera.look_at(focus,Vector3.UP)
    if pose_only: return
    var height_shift := max_height*cos(a)/sin(a) if oblique else 0.0
    # Pixel density stays at the game's selected zoom, including the far side.
    # Fixed allocation across wheel animation avoids reallocating a render target
    # every frame. Only window resizing changes the atlas dimensions.
    var pixel_scale: float = float(main.get_viewport().size.x)/size.x
    var atlas_zoom := zoom*pixel_scale
    var atlas_size := Vector2i((Vector2(size.x+32,size.y*3.5+max_height*8.0+32)*pixel_scale).ceil()).min(Vector2i(4096,4096))
    var probe_scale: float = get_meta("probe_atlas_scale",1.0)
    atlas_size = Vector2i((Vector2(atlas_size)*probe_scale).ceil())
    atlas_zoom *= probe_scale
    source_view.size = atlas_size
    source_camera.position = main.camera.position+Vector2(0,-minf(60.0,height_shift*0.25)).rotated(-heading)
    source_camera.rotation = -heading
    source_camera.zoom = Vector2.ONE*atlas_zoom
    source_camera.force_update_scroll()
    var atlas_rect := Rect2(source_camera.position-Vector2(atlas_size)/(atlas_zoom*2.0),Vector2(atlas_size)/atlas_zoom)
    visible_rect = Rect2(source_camera.position,Vector2.ZERO)
    for corner in [Vector2.ZERO,Vector2(atlas_rect.size.x,0),atlas_rect.size,Vector2(0,atlas_rect.size.y)]:
        visible_rect = visible_rect.expand(source_camera.position+(corner-atlas_rect.size*0.5).rotated(-heading))
    visible_rect = visible_rect.grow(16.0/zoom)
    # In top-down mode the same geometry becomes a flat surface without a rebuild.
    for material in [surface_material,fine_material,fuji_material]:
        material.set_shader_parameter("source_origin",atlas_rect.position)
        material.set_shader_parameter("source_span",atlas_rect.size)
        material.set_shader_parameter("source_heading",heading)
        material.set_shader_parameter("focus_point",focus)
        material.set_shader_parameter("haze_strength",0.28 if oblique else 0.0)
        material.set_shader_parameter("height_factor",1.0 if oblique else 0.0)
        material.set_shader_parameter("material_strength",clampf(0.36+log(zoom)/log(2.0)*0.17,0.26,0.87))
    if chunked_terrain: terrain_chunks.update_visibility()
    markers.invalidate()

func project(world: Vector2) -> Vector2:
    return view_camera.unproject_position(position_for(world))

func position_for(world: Vector2) -> Vector3:
    var fine: bool = is_instance_valid(fine_surface) and fine_surface.visible and fine_rect.has_point(world)
    var h := _triangle_height(world,2,fine_rect) if fine else _triangle_height(world,STEP)
    if fuji_surface.visible and fuji_rect.has_point(world): h = _triangle_height(world,fuji_step,fuji_rect)
    if not oblique: h = 0.0
    return Vector3(world.x-CENTER.x,h,world.y-CENTER.y)

func pick(screen: Vector2) -> Vector2:
    var origin := view_camera.project_ray_origin(screen)
    var direction := view_camera.project_ray_normal(screen)
    if not oblique: return plane_intersection(origin,direction)
    # Clip the ray to the terrain's bounding box, then traverse its X/Z cells.
    # The first hit is the visible face; hills hide both markers and selections.
    var t_enter := 0.0
    var t_exit := view_camera.far
    for axis in 3:
        var lower: float = -4096.0 if axis!=1 else 0.0
        var upper: float = 4096.0 if axis!=1 else max_height+1.0
        if absf(direction[axis])<0.000001:
            if origin[axis]<lower or origin[axis]>upper: return plane_intersection(origin,direction)
        else:
            var t0: float = (lower-origin[axis])/direction[axis]
            var t1: float = (upper-origin[axis])/direction[axis]
            t_enter = maxf(t_enter,minf(t0,t1))
            t_exit = minf(t_exit,maxf(t0,t1))
    var t := t_enter+0.00001
    while t<t_exit:
        var point3 := origin+direction*t
        var point := Vector2(point3.x,point3.z)+CENTER
        # Skip air above conservative height boxes; all possible hit cells still
        # use the identical fine/Fuji triangles and intersection tolerances.
        var skipped := false
        if ray_bounds_enabled and not ray_bounds.is_empty() and point.x>=0.0 and point.y>=0.0 and point.x<8192.0 and point.y<8192.0:
            for tier in ray_tiers:
                var block_step: float = tier.step
                var block := Vector2i((point/block_step).floor())
                var highest := float(ray_bounds.decode_u16(int(tier.offset)+(block.y*int(tier.side)+block.x)*2))*height_scale+0.01
                if point3.y<=highest: continue
                var end_t := t_exit
                if absf(direction.x)>0.000001:
                    var edge := float(block.x+(1 if direction.x>0 else 0))*block_step-CENTER.x
                    end_t = minf(end_t,(edge-origin.x)/direction.x)
                if absf(direction.z)>0.000001:
                    var edge := float(block.y+(1 if direction.z>0 else 0))*block_step-CENTER.y
                    end_t = minf(end_t,(edge-origin.z)/direction.z)
                # Descend directly to the conservative height plane when the
                # ray enters a block high above it. Stopping before that plane
                # leaves all possible intersections to the exact triangle test.
                var height_t := (highest-origin.y)/direction.y if direction.y < -0.000001 else t_exit
                var safe_end := minf(end_t,height_t)
                if safe_end>t+0.0001:
                    t = safe_end if safe_end<end_t else end_t+0.00001
                    ray_blocks_skipped += 1
                    skipped = true
                    break
        if skipped: continue
        ray_cells_tested += 1
        var fine: bool = fine_surface.visible and fine_rect.has_point(point)
        var detailed: bool = fuji_surface.visible and fuji_rect.has_point(point)
        var step: float = fuji_step if detailed else (2.0 if fine else float(STEP))
        var cell := (point/step).floor()*step
        if cell.x<0 or cell.y<0 or cell.x>=8192 or cell.y>=8192: break
        var region := fine_rect if fine else Rect2()
        if detailed: region = fuji_rect
        var a := Vector3(cell.x-4096,_vertex_height(cell,region),cell.y-4096)
        var b := Vector3(a.x+step,_vertex_height(cell+Vector2(step,0),region),a.z)
        var c := Vector3(a.x,_vertex_height(cell+Vector2(0,step),region),a.z+step)
        var d := Vector3(a.x+step,_vertex_height(cell+Vector2(step,step),region),a.z+step)
        var best: Variant = null
        var closest := INF
        for triangle in [[a,c,b],[b,c,d]]:
            var hit: Variant = _ray_triangle(origin,direction,triangle[0],triangle[1],triangle[2])
            if hit!=null and origin.distance_squared_to(hit)<closest:
                best=hit;closest=origin.distance_squared_to(hit)
        if best!=null: return Vector2(best.x,best.z)+CENTER
        var next_x := INF
        var next_z := INF
        if absf(direction.x)>0.000001:
            var edge_x := cell.x+step if direction.x>0 else cell.x
            next_x = (edge_x-CENTER.x-origin.x)/direction.x
        if absf(direction.z)>0.000001:
            var edge_z := cell.y+step if direction.z>0 else cell.y
            next_z = (edge_z-CENTER.y-origin.z)/direction.z
        t = maxf(t+0.002,minf(next_x,next_z)+0.002)
    return plane_intersection(origin,direction)

func _load_ray_bounds() -> void:
    var path := "res://data/derived/elevation/terrain_ray_bounds.json"
    if not FileAccess.file_exists(path): return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary: return
    if terrain_hash!=data.get("terrain_sha256","") or fuji_hash!=data.get("fuji_sha256","") or geometry_hash!=data.get("geometry_sha256",""): return
    var bytes := FileAccess.get_file_as_bytes("res://data/derived/elevation/terrain_ray_bounds.bin")
    if bytes.size()!=int(data.get("bytes",0)): return
    ray_bounds = bytes
    ray_tiers = data.tiers

static func bytes_sha256(bytes: PackedByteArray) -> String:
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(bytes)
    return hash.finish().hex_encode()

func _baked_terrain(name: String, region: Rect2, step: float) -> Resource:
    var path := "res://data/derived/elevation/terrain_"+name+".res"
    if not ResourceLoader.exists(path): return null
    var chunk := load(path)
    if chunk==null or chunk.mesh==null: return null
    var data: Dictionary = chunk.data
    if int(data.get("version",0))!=1 or data.get("terrain_sha256","")!=terrain_hash or data.get("fuji_sha256","")!=fuji_hash or data.get("geometry_sha256","")!=geometry_hash: return null
    if data.region!=region or not is_equal_approx(data.step,step) or not is_equal_approx(data.height_scale,height_scale) or not is_equal_approx(data.fuji_step,fuji_step): return null
    return chunk

func _ray_triangle(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Variant:
    var ab := b-a
    var ac := c-a
    var p := direction.cross(ac)
    var determinant := ab.dot(p)
    if absf(determinant)<0.000001: return null
    var relative := origin-a
    var u := relative.dot(p)/determinant
    var q := relative.cross(ab)
    var v := direction.dot(q)/determinant
    # Shared edges need a small tolerance at national-coordinate float precision.
    if u < -0.0001 or v < -0.0001 or u+v > 1.0001: return null
    var distance := ac.dot(q)/determinant
    if distance<0: return null
    return origin+direction*distance

func plane_intersection(origin: Vector3, direction: Vector3) -> Vector2:
    if direction.y>=-0.00001: return Vector2(INF,INF)
    var hit := origin+direction*(-origin.y/direction.y)
    return Vector2(hit.x,hit.z)+CENTER

func pin_anchor() -> void:
    # Numerical camera Jacobian accounts for perspective and changing focus height.
    for iteration in 4:
        var base: Vector2 = main.camera.position
        var screen := project(anchor_world)
        var error := screen-anchor_screen
        if error.length()<0.02: break
        main.camera.position = base+Vector2(0.25,0)
        sync(true,true)
        var dx := (project(anchor_world)-screen)/0.25
        main.camera.position = base+Vector2(0,0.25)
        sync(true,true)
        var dy := (project(anchor_world)-screen)/0.25
        var jacobian := Transform2D(dx,dy,Vector2.ZERO)
        main.camera.position = base
        if absf(jacobian.determinant())>0.00001:
            main.camera.position -= jacobian.affine_inverse().basis_xform(error).limit_length(256.0)
        main._clamp_camera()
        sync(true,true)
    sync(true)

func marker_visible(world: Vector2) -> bool:
    if not world.is_finite(): return false
    var screen := project(world)
    if not main.get_viewport_rect().grow(-4).has_point(screen): return false
    if get_meta("probe_no_occlusion",false): return true
    if marker_visibility.has(world): return marker_visibility[world]
    var visible := not view_camera.is_position_behind(position_for(world)) and pick(screen).distance_squared_to(world)<0.01
    marker_visibility[world] = visible
    return visible

