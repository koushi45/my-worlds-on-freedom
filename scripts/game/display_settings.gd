extends Node
## Persistent window resolution shared by the title screen and in-game options.
signal bgm_volume_changed(value: float)
signal sfx_volume_changed(value: float)
const SETTINGS_PATH := "user://display_settings.cfg"
const DEFAULT_INDEX := 1
const DEFAULT_BGM_VOLUME := 0.4
const DEFAULT_SFX_VOLUME := 1.0
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280,720),
	Vector2i(1920,1080),
	Vector2i(2560,1440),
	Vector2i(3840,2160),
]
const LABELS: Array[String] = [
	"1280 × 720",
	"1920 × 1080（標準）",
	"2560 × 1440",
	"3840 × 2160（4K）",
]
var current_index := DEFAULT_INDEX
var bgm_volume := DEFAULT_BGM_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var settings_path := SETTINGS_PATH

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		current_index = clampi(int(config.get_value("display","resolution_index",DEFAULT_INDEX)),0,RESOLUTIONS.size()-1)
		bgm_volume = clampf(float(config.get_value("audio","bgm_volume",DEFAULT_BGM_VOLUME)),0.0,1.0)
		sfx_volume = clampf(float(config.get_value("audio","sfx_volume",DEFAULT_SFX_VOLUME)),0.0,1.0)
	apply_resolution.call_deferred(current_index,false)

func apply_resolution(index: int, persist := true) -> void:
	current_index = clampi(index,0,RESOLUTIONS.size()-1)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(RESOLUTIONS[current_index])
		_center_window()
	if persist:
		_save()

func set_bgm_volume(value: float, persist := true) -> void:
	bgm_volume = clampf(value,0.0,1.0)
	bgm_volume_changed.emit(bgm_volume)
	if persist: _save()

func set_sfx_volume(value: float, persist := true) -> void:
	sfx_volume = clampf(value,0.0,1.0)
	sfx_volume_changed.emit(sfx_volume)
	if persist: _save()

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("display","resolution_index",current_index)
	config.set_value("audio","bgm_volume",bgm_volume)
	config.set_value("audio","sfx_volume",sfx_volume)
	config.save(settings_path)

func _center_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	var window_size := DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen_position + (screen_size-window_size)/2)
