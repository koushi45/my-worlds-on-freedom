extends Node2D
## Screen-facing geographic annotations, independent of the ground atlas.
var main: Node2D

var armies_only := false
var army_markers: Node2D
var widths: Dictionary = {}
var draw_count := 0
var last_draw_us := 0

func _ready() -> void:
    if armies_only: return
    army_markers = get_script().new()
    army_markers.main = main
    army_markers.armies_only = true
    add_child(army_markers)
    main.army_campaign.changed.connect(army_markers.queue_redraw)
    main.diplomacy.changed.connect(army_markers.queue_redraw)
    main.settlement_layer.visibility_changed.connect(queue_redraw)

func invalidate() -> void:
    queue_redraw()
    if is_instance_valid(army_markers): army_markers.queue_redraw()

func text_width(font: Font, name: String, size: int) -> float:
    var key := str(size)+":"+name
    if not widths.has(key): widths[key] = font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
    return widths[key]

func _draw() -> void:
    if main == null or main.map_view == null: return
    if armies_only:
        _draw_armies()
        return
    var started := Time.get_ticks_usec()
    draw_count += 1
    var view: Node3D = main.map_view
    var zoom: float = main.camera.zoom.x
    var font := ThemeDB.fallback_font
    var labels: Array[Rect2] = []
    if zoom < 2.0 and main.territory_borders != null:
        for country in main.territory_borders.country_records.values():
            var anchor: Vector2 = country.anchor
            if not view.marker_visible(anchor): continue
            var id: String = country.representative_district
            if not main.governance_registry.districts.has(id): continue
            var house: String = main.governance_registry.districts[id].house_id
            var screen: Vector2 = view.project(anchor)
            draw_circle(screen,18.7,main.kamon_layer.kamon_background_color(house))
            draw_circle(screen,18.7,Color(1,1,1,0.82),false,1,true)
            _crest(house,screen,30.6)
    if zoom >= 2.0:
        var offices: Node2D = main.district_office_layer
        for id in offices.records:
            var point: Vector2 = offices.office_point(id)
            if not view.marker_visible(point): continue
            var screen: Vector2 = view.project(point)
            var house: String = str(main.governance_registry.districts.get(id,{}).get("house_id",""))
            _crest(house,screen,minf(24.0,main.HexGridScript.RADIUS*zoom*1.1))
            if zoom < 3.0: continue
            var name: String = offices.records[id].name
            var width := text_width(font,name,12)
            var offset := Vector2(-width*0.5,main.HexGridScript.RADIUS*zoom*sin(deg_to_rad(view.angle))+16)
            var box := Rect2(screen+offset-Vector2(0,13),Vector2(width,17))
            var crowded := false
            for other in labels:
                if box.intersects(other): crowded = true;break
            if crowded: continue
            labels.append(box)
            draw_string_outline(font,screen+offset,name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,4,Color("#24180c"))
            draw_string(font,screen+offset,name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#fff0bc"))
    var sites: Node2D = main.settlement_layer
    sites.drawn_ids.clear()
    sites.labeled_ids.clear()
    for site in sites.data.sites:
        if not sites.visible or not sites.eligible(site): continue
        if zoom < 0.2 and int(site.importance)>1 and site.id!=sites.selected_id: continue
        var point := Vector2(site.display_point[0],site.display_point[1])
        if not view.marker_visible(point): continue
        sites.drawn_ids.append(site.id)
        var screen: Vector2 = view.project(point)
        draw_circle(screen,9,Color("#253634"))
        draw_circle(screen,5,Color("#e4e8ba"))
        if site.id == sites.selected_id: draw_arc(screen,12,0,TAU,32,Color.WHITE,2,true)
        var name: String = site.display_name
        var width := text_width(font,name,16)
        var box := Rect2(screen+Vector2(14,-29),Vector2(width,22))
        var crowded := false
        for other in labels:
            if box.intersects(other): crowded = true;break
        if crowded: continue
        labels.append(box)
        sites.labeled_ids.append(site.id)
        draw_string_outline(font,screen+Vector2(14,-12),name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,5,Color("#27342d"))
        draw_string(font,screen+Vector2(14,-12),name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#e4e8ba"))
    last_draw_us = Time.get_ticks_usec()-started

func _draw_armies() -> void:
    var view: Node3D = main.map_view
    var armies: Node2D = main.army_campaign
    if armies == null: return
    var side: int = armies.icon_size()
    var scale: float = armies.pixel_scale()
    for id in armies.units:
        var unit: Dictionary = armies.units[id]
        var point: Vector2 = armies.unit_position(unit)
        if not view.marker_visible(point): continue
        var screen: Vector2 = view.project(point)
        var icon: Texture2D = armies.ARMY_ICONS[armies.icon_color_key(unit)][side]
        draw_set_transform(screen,armies.facing_angle(unit),Vector2.ONE/scale)
        draw_texture(icon,Vector2.ONE*(-side*0.5))
        if id == armies.selected_id: draw_arc(Vector2.ZERO,side*0.27,0,TAU,32,Color.WHITE,2,true)
        draw_set_transform(Vector2.ZERO)

func _crest(house: String, screen: Vector2, size: float) -> void:
    var entry: Dictionary = main.kamon_layer.kamon_by_house.get(house,{})
    var texture: Texture2D = main.kamon_layer.kamon_textures.get(entry.get("asset",""))
    if texture != null:
        draw_texture_rect(texture,Rect2(screen-Vector2.ONE*size*0.5,Vector2.ONE*size),false)
