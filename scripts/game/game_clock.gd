extends Node
## Game calendar: proleptic Gregorian dates, starting in Nobunaga's coming-of-age year.
## Consumers can subscribe to day_advanced for daily simulation updates at every speed.

signal day_advanced(year: int, month: int, day: int)
signal state_restored(year: int, month: int, day: int)
signal speed_changed(speed: int)
signal pause_changed(paused: bool)

const SPEEDS := [1, 2, 4, 8]
const MONTH_LENGTHS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
var year := 1546
var month := 1
var day := 1
var elapsed_days := 0
var speed := 1
var paused := false
var _day_fraction := 0.0
var _last_tick_usec := 0


func _ready() -> void:
	_last_tick_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	_sync_elapsed_time()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_UNPAUSED:
		_last_tick_usec = Time.get_ticks_usec()


func _sync_elapsed_time() -> void:
	var now := Time.get_ticks_usec()
	var seconds := float(now - _last_tick_usec) / 1000000.0
	_last_tick_usec = now
	advance_real_seconds(seconds)


func set_speed(value: int) -> void:
	if value not in SPEEDS or value == speed:
		return
	# Attribute time before the click to the previous speed; preserve partial days.
	if is_inside_tree() and is_processing():
		_sync_elapsed_time()
	speed = value
	speed_changed.emit(speed)


func advance_real_seconds(seconds: float) -> void:
	if paused or not is_finite(seconds) or seconds <= 0.0:
		return
	_day_fraction += seconds * speed
	while _day_fraction >= 1.0:
		_day_fraction -= 1.0
		day += 1
		if day > days_in_month(year, month):
			day = 1
			month += 1
			if month > 12:
				month = 1
				year += 1
		elapsed_days += 1
		day_advanced.emit(year, month, day)


func toggle_paused() -> void:
	if is_inside_tree() and is_processing():
		_sync_elapsed_time()
	paused = not paused
	pause_changed.emit(paused)


func change_speed(direction: int) -> void:
	var index := clampi(SPEEDS.find(speed) + direction, 0, SPEEDS.size() - 1)
	set_speed(SPEEDS[index])


static func days_in_month(date_year: int, date_month: int) -> int:
	if date_month == 2 and date_year % 4 == 0 and (date_year % 100 != 0 or date_year % 400 == 0):
		return 29
	return MONTH_LENGTHS[date_month - 1]


func date_text() -> String:
	return "%d年 %d月 %d日" % [year, month, day]


func restore_state(state: Dictionary) -> void:
	year = int(state.year)
	month = int(state.month)
	day = int(state.day)
	elapsed_days = int(state.elapsed_days)
	speed = int(state.speed)
	paused = state.paused
	_day_fraction = float(state.fraction)
	_last_tick_usec = Time.get_ticks_usec()
	state_restored.emit(year,month,day)
	speed_changed.emit(speed)
	pause_changed.emit(paused)
