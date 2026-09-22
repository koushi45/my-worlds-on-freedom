extends Node
## Plays the shared operation sound for clickable UI and map selections.

const CLICK_STREAM := preload("res://assets/audio/ui_click_breviceps.ogg")

var player: AudioStreamPlayer
var play_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "InteractionClick"
	player.stream = CLICK_STREAM
	add_child(player)
	DisplaySettings.sfx_volume_changed.connect(_set_volume)
	_set_volume(DisplaySettings.sfx_volume)
	get_tree().node_added.connect(_hook_control)
	call_deferred("_hook_existing_controls")

func play_click() -> void:
	play_count += 1
	player.play()

func _set_volume(value: float) -> void:
	if player != null: player.volume_linear = value

func _hook_existing_controls() -> void:
	_hook_descendants(get_tree().root)

func _hook_descendants(node: Node) -> void:
	_hook_control(node)
	for child in node.get_children(): _hook_descendants(child)

func _hook_control(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		if not button.pressed.is_connected(play_click): button.pressed.connect(play_click)
	elif node is ItemList:
		var items := node as ItemList
		if not items.item_selected.is_connected(_on_item_selected): items.item_selected.connect(_on_item_selected)
	elif node is Slider:
		var slider := node as Slider
		if not slider.drag_ended.is_connected(_on_slider_drag_ended): slider.drag_ended.connect(_on_slider_drag_ended)

func _on_item_selected(_index: int) -> void:
	play_click()

func _on_slider_drag_ended(_value_changed: bool) -> void:
	play_click()
