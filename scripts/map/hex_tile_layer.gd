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
    visible = zoom >= Grid.MIN_DRAW_ZOOM
    if terrain_legend != null: terrain_legend.visible = visible
    queue_redraw()

func _draw() -> void:
    if main == null or bounds.size == Vector2.ZERO or zoom < Grid.MIN_DRAW_ZOOM: return
    var alpha := lerpf(0.08, 0.30, smoothstep(5.0, 24.0, Grid.RADIUS * zoom))
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
    if not lines.is_empty(): draw_multiline(lines, Color(0.93,0.86,0.66,alpha), 1.0/zoom, true)

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

