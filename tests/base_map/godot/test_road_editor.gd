extends SceneTree
const Grid = preload("res://scripts/map/hex_grid.gd")
const Network = preload("res://scripts/map/hex_road_network.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	printerr("FAIL: " + message)

func click(main: Node, screen: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = screen
		event.pressed = down
		main._unhandled_input(event)

func run() -> void:
	var network := Network.new()
	var center := Vector2i(100,100)
	var coverage := {center:true}
	for delta in Network.NEIGHBORS: coverage[center+delta] = true
	network.setup([],coverage)
	for cell in coverage: check(network.toggle(cell),"add road tile")
	for delta in Network.NEIGHBORS: check(network.connected(center,center+delta),"connect all six adjacent centers")
	check(not network.connected(center,center+Vector2i(2,0)),"never connect nonadjacent cells")
	var neighbor := center+Vector2i(1,0)
	check(network.toggle_edge(center,neighbor),"exclude individual triangle edge")
	check(not network.connected(neighbor,center),"exclusion is undirected")
	check(network.connected(center,center+Vector2i(0,1)),"other triangle edges remain")
	check(network.cells.has(center) and network.cells.has(neighbor),"edge deletion preserves tiles")
	network.undo()
	check(network.connected(center,neighbor),"undo edge deletion")
	network.redo()
	check(not network.connected(center,neighbor),"redo edge deletion")
	network.toggle(center)
	for delta in Network.NEIGHBORS: check(not network.connected(center,center+delta),"deleting a tile removes every incident edge")
	network.undo()
	check(network.cells.has(center),"undo deletion")
	network.redo()
	check(not network.cells.has(center),"redo deletion")
	var before: Dictionary = network.document()
	check(not network.load_document({}),"reject malformed import")
	check(network.document() == before,"failed import preserves edits")
	var path := "user://qa_hex_roads_%d.json" % OS.get_process_id()
	check(network.export_file(path) == OK,"export JSON")
	var restored := Network.new()
	restored.setup([],coverage)
	check(restored.load_document(JSON.parse_string(FileAccess.get_file_as_string(path))),"import exported JSON")
	check(restored.document() == before,"export/import preserves exact occupancy")
	check(restored.excluded_edges == network.excluded_edges,"export/import preserves exclusions")
	var malformed := before.duplicate(true)
	malformed.excluded_edges = [[[100,100],[102,100]]]
	check(not restored.load_document(malformed),"reject nonadjacent excluded edge")
	check(restored.document() == before,"invalid edge import is atomic")
	DirAccess.remove_absolute(path)
	change_scene_to_file("res://scenes/main/main.tscn")
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline and (current_scene==null or current_scene.game_menu==null): await process_frame
	if current_scene==null or current_scene.game_menu==null: printerr("Map ready timed out"); quit(1); return
	var main = current_scene
	var dev = main.developer_tools
	var official := Network.new()
	official.setup([],dev.network.allowed)
	check(official.load_document(JSON.parse_string(FileAccess.get_file_as_string(Network.DEFAULT_PATH))),"packaged official road data is valid")
	check(dev.network.document() == official.document(),"normal startup uses official roads without manual import")
	check(dev.network_active and dev.road_layer.visible and not main.shared_road_layer.visible,"official renderer active before developer mode")
	check(main.territory_borders.disconnected_offices.is_empty(),"normal mode has no connectivity overlay")
	check(not dev.enabled and not dev.road_editing,"developer mode initially disabled")
	main.game_menu.toggle()
	var menu_button: Button
	for button in main.game_menu.find_children("*","Button",true,false):
		if button.text == "開発者モード": menu_button = button; break
	check(menu_button != null,"developer mode is accessible from game menu")
	if menu_button != null: menu_button.pressed.emit()
	check(dev.enabled and not paused,"menu opens developer tools and returns map input")
	var office_id := "kai/unresolved-c074c2107bc1fabe"
	var office_cell := Grid.cell_at(main.district_office_layer.office_point(office_id))
	var adjacent := office_cell+Vector2i(1,0)
	var isolated := official.document()
	isolated.cells = [[office_cell.x,office_cell.y]]
	isolated.excluded_edges = []
	check(dev.network.load_document(isolated),"load isolated office")
	check(main.territory_borders.disconnected_offices.has(office_id),"isolated office is highlighted with editing off")
	dev.network.toggle(adjacent)
	check(not main.territory_borders.disconnected_offices.has(office_id),"adding connecting road removes highlight immediately")
	dev.network.toggle_edge(office_cell,adjacent)
	check(main.territory_borders.disconnected_offices.has(office_id),"excluded last edge restores highlight")
	dev.network.undo()
	check(not main.territory_borders.disconnected_offices.has(office_id),"undo updates highlight")
	dev.network.toggle(office_cell)
	check(main.territory_borders.disconnected_offices.has(office_id),"missing office road is highlighted even with neighboring road")
	dev.close()
	check(main.territory_borders.disconnected_offices.is_empty(),"closing developer mode clears highlight")
	dev.open()
	check(main.territory_borders.disconnected_offices.has(office_id),"reopening recomputes highlight")
	main.set_map_zoom(4.0)
	main.camera.position = main.elevation.project(Grid.center(office_cell))
	main._refresh_visible_tiles()
	for frame in 4: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/disconnected_offices.png")
	check(dev.network.load_document(official.document()),"restore official data for map tests")
	dev.set_road_editing(true)
	check(main.camera.zoom.x >= 2.0 and not main.game_clock.is_processing(),"editing zooms in and suspends time")
	check(not main.shared_road_layer.visible and dev.road_layer.visible,"one road renderer active")
	var focus: Vector2 = main.district_office_layer.office_point("kai/unresolved-c074c2107bc1fabe")
	main.set_map_zoom(4.0)
	main.camera.position = main.elevation.project(focus)
	main._refresh_visible_tiles()
	for frame in 4: await process_frame
	var cell := Grid.cell_at(focus)
	var had: bool = dev.network.cells.has(cell)
	var screen: Vector2 = main.get_global_transform_with_canvas()*main.elevation.project(focus)
	click(main,screen)
	check(dev.network.cells.has(cell) != had,"map click toggles road instead of selecting office")
	click(main,screen)
	check(dev.network.cells.has(cell) == had,"second click reverses toggle")
	var other := cell+Vector2i(1,0)
	if not dev.network.cells.has(cell): dev.network.toggle(cell)
	if not dev.network.cells.has(other): dev.network.toggle(other)
	dev.set_edge_editing(true)
	var midpoint := (Grid.center(cell)+Grid.center(other))*0.5
	var edge_screen: Vector2 = main.get_global_transform_with_canvas()*main.elevation.project(midpoint)
	click(main,edge_screen)
	check(not dev.network.connected(cell,other),"screen click deletes only connection")
	check(dev.network.cells.has(cell) and dev.network.cells.has(other),"edge click preserves occupancy")
	click(main,edge_screen)
	check(dev.network.connected(cell,other),"click dashed edge restores connection")
	click(main,edge_screen)
	dev.set_edge_editing(false)
	had = dev.network.cells.has(cell)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = screen
	down.pressed = true
	main._unhandled_input(down)
	var motion := InputEventMouseMotion.new()
	motion.position = screen + Vector2(20,0)
	motion.relative = Vector2(20,0)
	main._unhandled_input(motion)
	down.pressed = false
	down.position = motion.position
	main._unhandled_input(down)
	check(dev.network.cells.has(cell) == had,"dragging pans without toggling roads")
	main.set_map_zoom(1.99)
	dev.click_world(focus)
	check(dev.network.cells.has(cell) == had,"below 200 percent click cannot modify roads")
	main.set_map_zoom(4.0)
	main._refresh_visible_tiles()
	dev._refresh()
	dev.set_edge_editing(true)
	for frame in 15: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/road_editor.png")
	dev.close()
	check(not dev.road_editing and main.district_office_layer.visible,"exit restores normal map interaction")
	check(main.territory_borders.disconnected_offices.is_empty(),"exit hides connectivity overlay")
	check(main.game_clock.is_processing(),"exit restores clock processing")
	print("Road editor tests: %d failures" % failures)
	quit(1 if failures else 0)
