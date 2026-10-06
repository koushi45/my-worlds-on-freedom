extends Node
## Game calendar: proleptic Gregorian dates, starting in Nobunaga's coming-of-age year.
## Daily rules are ordered; elapsed time is retained within a bounded backlog.

signal day_advanced(year: int, month: int, day: int)
signal day_started(year: int, month: int, day: int)
signal simulation_advanced(game_days: float)
signal state_restored(year: int, month: int, day: int)
signal speed_changed(speed: int)
signal pause_changed(paused: bool)

const SPEEDS := [1, 2, 4, 8, 16]
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
var day_wait_reason: Callable
var diagnostic_draw_wait := false
var diagnostic_frame := -1
const MAX_BACKLOG_DAYS := 8.0 # One real second at 8x; live catch-up is still sliced.
const MAX_DAYS_PER_CALL := 4
const MAX_LIVE_SIMULATION_DAYS := 0.4
const MAX_LIVE_CATCHUP_DAYS := 1.0
var backlog_days := 0.0
var suspended := false
var profile_enabled := false
var wait_usec: Dictionary = {}
var simulation_usec := 0
var daily_events := 0
var blocked_since_usec := 0
var blocked_reason := ""
var blocked_wall_usec: Dictionary = {}
var discarded_input_usec := 0
var discarded_backlog_days := 0.0


func _ready() -> void:
	_last_tick_usec = Time.get_ticks_usec()
	profile_enabled = "--cpu-profile" in OS.get_cmdline_user_args()


func _process(_delta: float) -> void:
	_sync_elapsed_time()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED]:
		suspended = true
		backlog_days = 0.0
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_UNPAUSED]:
		suspended = false
		_last_tick_usec = Time.get_ticks_usec()

func _sync_elapsed_time() -> void:
	var now := Time.get_ticks_usec()
	var seconds := float(now - _last_tick_usec) / 1000000.0
	_last_tick_usec = now
	if suspended or (DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED):
		if profile_enabled: _profile_barrier("")
		backlog_days = 0.0
		return
	if profile_enabled: discarded_input_usec += int(maxf(0.0, seconds - 0.25) * 1000000.0)
	advance_real_seconds(minf(seconds, 0.25), simulation_budget_for_elapsed(seconds))

func simulation_budget_for_elapsed(seconds: float) -> float:
	# A 30 FPS frame can finish one date. A smaller cap adds a second movement
	# frame even when mandatory work already completed, wasting catch-up capacity.
	# At 16x, a half-day cap can consume two movement frames per date and leave
	# too little capacity for the required-day barrier. Keep the same finite
	# one-day maximum, but allow a full date at 60 FPS when accelerating to 16x.
	return clampf(seconds * 30.0 * maxf(1.0, float(speed) / 8.0), MAX_LIVE_SIMULATION_DAYS, MAX_LIVE_CATCHUP_DAYS)

func set_speed(value: int) -> void:
	if value not in SPEEDS or value == speed:
		return
	# Attribute time before the click to the previous speed; preserve partial days.
	if is_inside_tree() and is_processing():
		_sync_elapsed_time()
	speed = value
	speed_changed.emit(speed)


func advance_real_seconds(seconds: float, simulation_budget_days := INF) -> void:
	if paused:
		if profile_enabled: _profile_barrier("")
		return
	if not is_finite(seconds) or seconds < 0.0: return
	var requested := backlog_days + seconds * speed
	if profile_enabled: discarded_backlog_days += maxf(0.0, requested - MAX_BACKLOG_DAYS)
	backlog_days = minf(MAX_BACKLOG_DAYS, requested)
	for index in range(MAX_DAYS_PER_CALL):
		if not work_started:
			if backlog_days <= 0.0000001: return
			work_started = true
			day_started.emit(year, month, day)
		# Required rules finish before movement/combat use the day's state.
		if day_work_pending.is_valid() and day_work_pending.call():
			if profile_enabled:
				var reason: String = day_wait_reason.call() if day_wait_reason.is_valid() else "daily_rules"
				wait_usec[reason] = int(wait_usec.get(reason, 0)) + int(seconds * 1000000.0)
				_profile_barrier(reason)
			return
		if profile_enabled: _profile_barrier("")
		var accepted := minf(minf(backlog_days, maxf(0.0, 1.0 - _day_fraction)), simulation_budget_days)
		if accepted > 0.0:
			var started := Time.get_ticks_usec()
			simulation_advanced.emit(accepted)
			if profile_enabled: simulation_usec += Time.get_ticks_usec() - started
			_day_fraction = minf(1.0, _day_fraction + accepted)
			backlog_days = maxf(0.0, backlog_days - accepted)
			simulation_budget_days = maxf(0.0, simulation_budget_days - accepted)
		if _day_fraction < 1.0 - 0.0000001: return
		if diagnostic_draw_wait and is_inside_tree():
			if diagnostic_frame < 0: diagnostic_frame = Engine.get_process_frames()
			if Engine.get_process_frames() <= diagnostic_frame + 1:
				if profile_enabled: wait_usec["diagnostic_draw"] = int(wait_usec.get("diagnostic_draw", 0)) + int(seconds * 1000000.0)
				return
			diagnostic_frame = -1
			backlog_days = 0.0
		_day_fraction = 0.0
		work_started = false
		day += 1
		if day > days_in_month(year, month):
			day = 1
			month += 1
			if month > 12:
				month = 1
				year += 1
		elapsed_days += 1
		daily_events += 1
		day_advanced.emit(year, month, day)
		if paused: return

func reset_profile() -> void:
	wait_usec.clear()
	blocked_wall_usec.clear()
	blocked_since_usec = 0
	blocked_reason = ""
	discarded_input_usec = 0
	discarded_backlog_days = 0.0
	simulation_usec = 0
	daily_events = 0

func _profile_barrier(reason: String) -> void:
	if reason == blocked_reason: return
	var now := Time.get_ticks_usec()
	if blocked_since_usec > 0:
		blocked_wall_usec[blocked_reason] = int(blocked_wall_usec.get(blocked_reason, 0)) + now - blocked_since_usec
	blocked_reason = reason
	blocked_since_usec = now if not reason.is_empty() else 0

func profile_report() -> Dictionary:
	var wall := blocked_wall_usec.duplicate()
	if blocked_since_usec > 0: wall[blocked_reason] = int(wall.get(blocked_reason, 0)) + Time.get_ticks_usec() - blocked_since_usec
	return {"wait_usec":wait_usec.duplicate(), "blocked_wall_usec":wall, "discarded_input_usec":discarded_input_usec, "discarded_backlog_days":discarded_backlog_days, "simulation_ms":simulation_usec / 1000.0, "day_events":daily_events, "backlog_days":backlog_days, "fixed_draw_wait_ms":0}

func toggle_paused() -> void:
	if is_inside_tree() and is_processing():
		_sync_elapsed_time()
	paused = not paused
	backlog_days = 0.0
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
	if profile_enabled: _profile_barrier("")
	year = int(state.year)
	month = int(state.month)
	day = int(state.day)
	elapsed_days = int(state.elapsed_days)
	speed = int(state.speed)
	paused = state.paused
	_day_fraction = float(state.fraction)
	work_started = bool(state.work_started)
	backlog_days = float(state.backlog)
	diagnostic_frame = -1
	_last_tick_usec = Time.get_ticks_usec()
	state_restored.emit(year,month,day)
	speed_changed.emit(speed)
	pause_changed.emit(paused)
