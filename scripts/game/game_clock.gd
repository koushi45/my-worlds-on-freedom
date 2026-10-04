extends Node
## Game calendar: proleptic Gregorian dates, starting in Nobunaga's coming-of-age year.
## Start current-day work once; advance the date only after simulation and display settle.

signal day_advanced(year: int, month: int, day: int)
signal day_started(year: int, month: int, day: int)
signal simulation_advanced(game_days: float)
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
var work_started := false
var day_work_pending: Callable
var _completion_frame := -1


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
	advance_real_seconds(minf(seconds, 0.1))


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
	if not work_started:
		work_started = true
		day_started.emit(year, month, day)
	# Consume time only within this day. Stalls never create a catch-up backlog.
	var accepted := minf(seconds * speed, maxf(0.0, 1.0 - _day_fraction))
	if accepted > 0.0:
		simulation_advanced.emit(accepted)
		_day_fraction = minf(1.0, _day_fraction + accepted)
		_completion_frame = -1
	if _day_fraction < 1.0:
		return
	if day_work_pending.is_valid() and day_work_pending.call():
		_completion_frame = -1
		return
	if is_inside_tree():
		if _completion_frame < 0:
			_completion_frame = Engine.get_process_frames()
			_last_tick_usec = Time.get_ticks_usec()
			return
		# Leave a complete frame for input, HUD and map drawing before changing date.
		if Engine.get_process_frames() <= _completion_frame + 1:
			_last_tick_usec = Time.get_ticks_usec()
			return
	_day_fraction = 0.0
	work_started = false
	_completion_frame = -1
	day += 1
	if day > days_in_month(year, month):
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1
	elapsed_days += 1
	_last_tick_usec = Time.get_ticks_usec()
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
	work_started = bool(state.work_started)
	_completion_frame = -1
	_last_tick_usec = Time.get_ticks_usec()
	state_restored.emit(year,month,day)
	speed_changed.emit(speed)
	pause_changed.emit(paused)
