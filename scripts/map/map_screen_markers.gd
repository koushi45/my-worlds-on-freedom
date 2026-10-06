extends Node2D
## Screen-facing geographic annotations, independent of the ground atlas.
var main: Node2D

var armies_only := false
var army_markers: Node2D
var widths: Dictionary = {}
var draw_count := 0
var last_draw_us := 0
var total_draw_us := 0
var invalidated_frame := -1

func _ready() -> void:
    if armies_only: return
    army_markers = get_script().new()
    army_markers.main = main
    army_markers.armies_only = true
    add_child(army_markers)
    main.army_campaign.changed.connect(army_markers.invalidate)
    main.diplomacy.changed.connect(army_markers.invalidate)
    main.game_clock.pause_changed.connect(func(_paused: bool): army_markers.invalidate())
    main.settlement_layer.visibility_changed.connect(invalidate)
    main.district_layer.selection_changed.connect(invalidate)

func invalidate() -> void:
    if main.map_view.get_meta("probe_single_marker_redraw",true):
        var frame := Engine.get_process_frames()
        if invalidated_frame == frame: return
        invalidated_frame = frame
    queue_redraw()
    if is_instance_valid(army_markers): army_markers.invalidate()

func text_width(font: Font, name: String, size: int) -> float:
    var key := str(size)+":"+name
    if not widths.has(key): widths[key] = font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
    return widths[key]

func office_selected(id: String) -> bool:
    return id == main.district_layer.selected_key or (main.district_info != null and main.district_info.panel.visible and id == main.district_info.district_id)

func _draw() -> void:
    if main == null or main.map_view == null: return
    if armies_only:
        _draw_armies()
        _draw_occupations()
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
            if not view.marker_visible(point,office_selected(id),"office:"+str(id)): continue
            var screen: Vector2 = view.project(point)
            var house: String = str(main.governance_registry.districts.get(id,{}).get("house_id",""))
            _crest(house,screen,minf(24.0,main.HexGridScript.RADIUS*zoom*1.1))
            if zoom < 3.0 or view.get_meta("probe_no_marker_text",false): continue
            var name: String = offices.records[id].name
            var width := text_width(font,name,12)
            var offset := Vector2(-width*0.5,main.HexGridScript.RADIUS*zoom*sin(deg_to_rad(view.angle))+16)
            var box := Rect2(screen+offset-Vector2(0,13),Vector2(width,17))
            var crowded := false
            for other in labels:
                if box.intersects(other): crowded = true;break
            if crowded and not office_selected(id): continue
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
        if not view.marker_visible(point,site.id == sites.selected_id,"site:"+str(site.id)): continue
        sites.drawn_ids.append(site.id)
        var screen: Vector2 = view.project(point)
        draw_circle(screen,9,Color("#253634"))
        draw_circle(screen,5,Color("#e4e8ba"))
        if site.id == sites.selected_id: draw_arc(screen,12,0,TAU,32,Color.WHITE,2,true)
        if view.get_meta("probe_no_marker_text",false): continue
        var name: String = site.display_name
        var width := text_width(font,name,16)
        var box := Rect2(screen+Vector2(14,-29),Vector2(width,22))
        var crowded := false
        for other in labels:
            if box.intersects(other): crowded = true;break
        if crowded and site.id != sites.selected_id: continue
        labels.append(box)
        sites.labeled_ids.append(site.id)
        draw_string_outline(font,screen+Vector2(14,-12),name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,5,Color("#27342d"))
        draw_string(font,screen+Vector2(14,-12),name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#e4e8ba"))
    last_draw_us = Time.get_ticks_usec()-started
    total_draw_us += last_draw_us

func _draw_armies() -> void:
    var view: Node3D = main.map_view
    var armies: Node2D = main.army_campaign
    if armies == null: return
    var side: int = armies.icon_size()
    var scale: float = armies.pixel_scale()
    for id in armies.units:
        var unit: Dictionary = armies.units[id]
        var point: Vector2 = armies.unit_position(unit)
        if not view.marker_visible(point,id == armies.selected_id,"army:"+str(id)): continue
        var screen: Vector2 = view.project(point)
        var icon: Texture2D = armies.ARMY_ICONS[armies.icon_color_key(unit)][side]
        draw_set_transform(screen,armies.facing_angle(unit),Vector2.ONE/scale)
        draw_texture(icon,Vector2.ONE*(-side*0.5))
        if id == armies.selected_id: draw_arc(Vector2.ZERO,side*0.27,0,TAU,32,Color.WHITE,2,true)
        draw_set_transform(Vector2.ZERO)

func _crest(house: String, screen: Vector2, size: float) -> void:
    if main.map_view.get_meta("probe_no_crests",false): return
    var entry: Dictionary = main.kamon_layer.kamon_by_house.get(house,{})
    var texture: Texture2D = main.kamon_layer.kamon_textures.get(entry.get("asset",""))
    if texture != null:
        draw_texture_rect(texture,Rect2(screen-Vector2.ONE*size*0.5,Vector2.ONE*size),false)

func occupation_badge_rect(district_id: String) -> Rect2:
    var point: Vector2 = main.district_office_layer.office_point(district_id)
    var screen: Vector2 = main.map_view.project(point)
    var top: float = screen.y
    for vertex in main.HexGridScript.polygon(main.HexGridScript.cell_at(point)):
        top = minf(top, main.map_view.project(vertex).y)
    return Rect2(Vector2(screen.x - 100, top - 82), Vector2(200, 74))

func _draw_occupations() -> void:
    if main.camera.zoom.x < 2.0: return
    var army: Node2D = main.army_campaign
    var view: Node3D = main.map_view
    var font := ThemeDB.fallback_font
    var background := StyleBoxFlat.new()
    background.bg_color = Color("#0c1422f5")
    background.border_color = Color("#d7ad64")
    background.set_border_width_all(1)
    background.set_corner_radius_all(4)
    for id in army.occupations:
        if not main.district_office_layer.records.has(id): continue
        var info: Dictionary = army.occupation_display(id)
        if info.is_empty(): continue
        var point: Vector2 = main.district_office_layer.office_point(id)
        if not view.marker_visible(point, office_selected(id), "office:" + str(id)): continue
        var box := occupation_badge_rect(id)
        draw_style_box(background, box)
        var caption := "%s %.0f%%" % [info.badge, info.progress]
        var width := text_width(font, caption, 15)
        draw_string(font, box.position + Vector2((box.size.x-width)*0.5, 22), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f4e8cd"))
        var track := Rect2(box.position + Vector2(12, 31), Vector2(176, 10))
        draw_rect(track, Color("#29303a"))
        draw_rect(Rect2(track.position, Vector2(track.size.x * float(info.progress) / 100.0, track.size.y)), Color("#d7ad64"))
        var detail: String = info.estimate if float(info.rate) > 0.0 else info.change
        if main.game_clock.paused: detail = "時間を進めると再開"
        width = text_width(font, detail, 13)
        draw_string(font, box.position + Vector2((box.size.x-width)*0.5, 62), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f4e8cd"))
