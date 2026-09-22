extends RefCounted
static func settled(main: Node) -> void:
	await main.get_tree().process_frame
	var deadline:=Time.get_ticks_msec()+15000
	while main.has_pending_map_work() and Time.get_ticks_msec()<deadline:
		await main.get_tree().process_frame
	assert(not main.has_pending_map_work(),"map streaming timed out")
	await main.get_tree().process_frame

static func parent(layer: Node, id: String) -> void:
	layer.load_parent(id)
	var deadline:=Time.get_ticks_msec()+15000
	while not layer.loaded.has(id) and Time.get_ticks_msec()<deadline:
		await layer.get_tree().process_frame
	assert(layer.loaded.has(id),"district parent timed out")

static func fill(layer: Node) -> void:
	var deadline:=Time.get_ticks_msec()+15000
	while layer.fill_mesh()==null and Time.get_ticks_msec()<deadline:
		await layer.get_tree().process_frame
	assert(layer.fill_mesh()!=null,"district fill timed out")
