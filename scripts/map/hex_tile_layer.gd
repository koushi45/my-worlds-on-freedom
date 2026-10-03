extends Node2D
## A separate world-space overlay; no border clipping or boundary-derived cells.
const Grid = preload("res://scripts/map/hex_grid.gd")
const Terrain = preload("res://scripts/map/hex_terrain.gd")
const EDGE_NEIGHBORS := [Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0)]
var visible_cells: Dictionary = {}
var high_mountain_cells: Dictionary = {}
var impassable_cells: Dictionary = {}
var main: Node2D
var terrain_legend: CanvasLayer
var bounds := Rect2()
var zoom := 1.0
var last_draw_us := 0
var draw_count := 0
var mesh_chunks: Dictionary = {}
var mesh_projection := false
var mesh_chunk_side := 128.0
const LineBatch = preload("res://scripts/map/line_mesh_batch.gd")
func _ready() -> void:
    z_index = 23
    visible = false
    var coverage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/detail_map/hex_coverage.json"))
    var terrain: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/detail_map/hex_terrain.json"))
    assert(is_equal_approx(float(coverage.radius), Grid.RADIUS), "Rebuild hex coverage after changing the tile radius")
    assert(is_equal_approx(float(terrain.radius), Grid.RADIUS) and int(terrain.tile_count) == int(coverage.visible_cells), "Rebuild hex terrain after changing coverage")
    for row in coverage.rows:
        var codes: String = terrain.rows[row]
        assert(codes.length() == coverage.rows[row].size(), "Hex terrain row does not match coverage")
        for index in coverage.rows[row].size():
            var cell := Vector2i(int(coverage.rows[row][index]), int(row))
            var kind := codes.unicode_at(index) - 48
            visible_cells[cell] = kind
            if kind == Terrain.HIGH_MOUNTAIN: high_mountain_cells[cell] = true
            if kind == Terrain.HIGH_MOUNTAIN or kind == Terrain.NO_LAND: impassable_cells[cell] = true
    _build_legend()

func terrain_for(cell: Vector2i) -> int:
    return int(visible_cells.get(cell, Terrain.NO_LAND))

func can_enter(cell: Vector2i) -> bool:
    return visible_cells.has(cell) and not impassable_cells.has(cell)

func update_view(rect: Rect2, view_zoom: float) -> void:
    bounds = rect.intersection(Grid.WORLD).grow(Grid.RADIUS * 2.0)
    zoom = view_zoom
    visible = zoom >= Grid.MIN_DRAW_ZOOM and not (main.map_view != null and main.map_view.get_meta("probe_no_hex",false))
    if terrain_legend != null: terrain_legend.visible = visible
    queue_redraw()

func _draw() -> void:
    var started := Time.get_ticks_usec()
    _draw_content()
    last_draw_us = Time.get_ticks_usec()-started
    draw_count += 1

func _draw_content() -> void:
    for node in mesh_chunks.values(): node.hide()
    if main != null and main.map_view != null and main.map_view.get_meta("probe_no_hex_lines",false): return
    if main == null or bounds.size == Vector2.ZERO or zoom < Grid.MIN_DRAW_ZOOM: return
    var alpha := lerpf(0.08, 0.30, smoothstep(5.0, 24.0, Grid.RADIUS * zoom))
    if main.map_view != null and main.map_view.get_meta("probe_hex_mesh",true):
        _draw_mesh_chunks(alpha)
        return
    var lines := PackedVector2Array()
    for r in range(floori(bounds.position.y / (Grid.RADIUS*1.5)), ceili(bounds.end.y / (Grid.RADIUS*1.5))+1):
        var left := floori(bounds.position.x / (Grid.ROOT_3*Grid.RADIUS)-r*0.5)
        var right := ceili(bounds.end.x / (Grid.ROOT_3*Grid.RADIUS)-r*0.5)
        for q in range(left, right+1):
            var cell := Vector2i(q,r)
            if not visible_cells.has(cell): continue
            var polygon := Grid.polygon(cell)
            # Shared edges once; all outer edges close the offshore perimeter.
            for edge in 6:
                if edge >= 3 and visible_cells.has(cell + EDGE_NEIGHBORS[edge]): continue
                lines.append(main.elevation.project(polygon[edge]))
                lines.append(main.elevation.project(polygon[(edge+1)%6]))
    var antialias: bool = not (main.map_view != null and main.map_view.get_meta("probe_hex_noaa",false))
    if not lines.is_empty(): draw_multiline(lines, Color(0.93,0.86,0.66,alpha), 1.0/zoom, antialias)

func _draw_mesh_chunks(alpha: float) -> void:
    var side := 128.0
    while (ceili(bounds.size.x/side)+1)*(ceili(bounds.size.y/side)+1)>64: side *= 2.0
    if mesh_projection != main.elevation.enabled or side != mesh_chunk_side:
        for node in mesh_chunks.values(): node.queue_free()
        mesh_chunks.clear()
        mesh_projection = main.elevation.enabled
        mesh_chunk_side = side
    for node in mesh_chunks.values(): node.hide()
    var wanted := {}
    for cy in range(floori(bounds.position.y/side),ceili(bounds.end.y/side)):
        for cx in range(floori(bounds.position.x/side),ceili(bounds.end.x/side)):
            var key := Vector2i(cx,cy)
            wanted[key] = true
            if not mesh_chunks.has(key):
                var region := Rect2(Vector2(cx,cy)*side,Vector2.ONE*side)
                var points := PackedVector2Array()
                for r in range(floori(region.position.y/(Grid.RADIUS*1.5))-1,ceili(region.end.y/(Grid.RADIUS*1.5))+1):
                    var left := floori(region.position.x/(Grid.ROOT_3*Grid.RADIUS)-r*0.5)-1
                    var right := ceili(region.end.x/(Grid.ROOT_3*Grid.RADIUS)-r*0.5)+1
                    for q in range(left,right+1):
                        var cell := Vector2i(q,r)
                        if not visible_cells.has(cell) or not region.has_point(Grid.center(cell)): continue
                        var polygon := Grid.polygon(cell)
                        for edge in 6:
                            if edge>=3 and visible_cells.has(cell+EDGE_NEIGHBORS[edge]): continue
                            points.append(main.elevation.project(polygon[edge]))
                            points.append(main.elevation.project(polygon[(edge+1)%6]))
                var node := LineBatch.new()
                add_child(node)
                node.configure(points,1.0,Color(0.93,0.86,0.66,alpha),zoom)
                mesh_chunks[key] = node
            var node: MeshInstance2D = mesh_chunks[key]
            node.show()
            node.style.set_shader_parameter("view_zoom",zoom)
            node.style.set_shader_parameter("line_color",Color(0.93,0.86,0.66,alpha))
    for key in mesh_chunks.keys():
        if mesh_chunks.size()<=64: break
        if not wanted.has(key):
            mesh_chunks[key].queue_free()
            mesh_chunks.erase(key)

func _build_legend() -> void:
    terrain_legend = CanvasLayer.new()
    terrain_legend.layer = 18
    terrain_legend.visible = false
    add_child(terrain_legend)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    panel.offset_left = -224
    panel.offset_right = -16
    panel.offset_top = -240
    panel.offset_bottom = -88
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background := StyleBoxFlat.new()
    background.bg_color = Color("#171311ed")
    background.border_color = Color("#c5a15f")
    background.set_border_width_all(2)
    background.set_corner_radius_all(6)
    background.set_content_margin_all(11)
    panel.add_theme_stylebox_override("panel", background)
    terrain_legend.add_child(panel)
    var rows := VBoxContainer.new()
    rows.add_theme_constant_override("separation", 4)
    rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(rows)
    var title := Label.new()
    title.text = "六角形の地形"
    title.add_theme_color_override("font_color", Color("#d7ad64"))
    title.add_theme_font_size_override("font_size", 15)
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rows.add_child(title)
    for row in ["草地　平地", "森・岩肌　山地", "雪の峰　高山地・通行不可", "水路　川", "海域　陸地なし・通行不可"]:
        var name := Label.new()
        name.text = row
        name.add_theme_color_override("font_color", Color("#f4e8cd"))
        name.add_theme_font_size_override("font_size", 13)
        name.mouse_filter = Control.MOUSE_FILTER_IGNORE
        rows.add_child(name)

