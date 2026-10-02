extends RefCounted
## Native PNGs for each zoom. At most active/current/target sets are retained.
const ROOT := "res://assets/map/materials/"
const MATERIALS := ["grass","forest","rock","snow"]
var resident: Dictionary = {}
var waiting: Dictionary = {}
var active := 100
var manifest: Dictionary
var stream = preload("res://scripts/map/bounded_texture_stream.gd").new()

static func tier_for_zoom(zoom: float) -> int:
    if zoom<=1.001: return 100
    if zoom<=2.001: return 200
    if zoom<=4.001: return 400
    if zoom<=6.001: return 600
    return 800

func _init() -> void:
    manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
    var textures := {}
    for kind in ["albedo","normal"]:
        for material in MATERIALS:
            textures[material+"_"+kind] = load(manifest.tiers["100"][kind][material])
    resident[100] = textures

func request(percent: int) -> void:
    if resident.has(percent) or waiting.has(percent): return
    var paths := {}
    for kind in ["albedo","normal"]:
        for material in MATERIALS:
            paths[material+"_"+kind] = manifest.tiers[str(percent)][kind][material]
    waiting[percent] = paths

func update(zoom: float, target_zoom: float) -> bool:
    var desired := tier_for_zoom(zoom)
    var target := tier_for_zoom(target_zoom)
    request(desired)
    request(target)
    for percent in waiting.keys():
        if percent not in [desired,target]: waiting.erase(percent)
    for percent in resident.keys():
        if percent not in [active,desired,target]: resident.erase(percent)
    var paths := {}
    for percent in [desired,target,active]:
        var size := int(manifest.tiers[str(percent)].size)
        var cost := int(ceil(float(size*size*4)*4.0/3.0))
        if resident.has(percent):
            for texture in resident[percent].values(): paths[texture.resource_path] = cost
        elif waiting.has(percent):
            for path in waiting[percent].values(): paths[path] = cost
    stream.keep(paths)
    for textures in resident.values():
        for texture in textures.values(): stream.adopt(texture.resource_path,texture)
    stream.poll()
    for percent in waiting.keys():
        var complete := true
        var failure := false
        for path in waiting[percent].values():
            if stream.failed.has(path): failure = true
            if stream.texture(path)==null: complete = false
        if failure:
            waiting.erase(percent)
            continue
        if not complete: continue
        var textures := {}
        for key in waiting[percent]: textures[key] = stream.texture(waiting[percent][key])
        waiting.erase(percent)
        resident[percent] = textures
    var changed := resident.has(desired) and active!=desired
    if changed: active = desired
    return changed

func shutdown() -> void:
    stream.shutdown()
    waiting.clear()
    resident.clear()

func apply(material: ShaderMaterial) -> void:
    for key in resident[active]: material.set_shader_parameter(key,resident[active][key])
    material.set_shader_parameter("material_world_span",float(manifest.tiling_world))
