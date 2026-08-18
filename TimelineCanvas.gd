class_name TimelineCanvas
extends Control

signal timeline_double_clicked(timestamp: int)
signal timeline_single_clicked()

var start_time: int = 0
var end_time: int = 0
var zoom: float = 0.0001
var view_offset_time: float = 0.0

var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_offset: float = 0.0

const sec_hour: int = 3600
const sec_day: int = 86400
const month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

func get_days_in_month(month: int, year: int) -> int:
	if month in [1, 3, 5, 7, 8, 10, 12]: return 31
	if month in [4, 6, 9, 11]: return 30
	if month == 2:
		var is_leap: bool = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
		return 29 if is_leap else 28
	return 30

func setup_range(start_year: int, end_year: int):
	start_time = int(Time.get_unix_time_from_datetime_dict({"year": start_year, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0}))
	end_time = int(Time.get_unix_time_from_datetime_dict({"year": end_year, "month": 12, "day": 31, "hour": 23, "minute": 59, "second": 59}))
	
	var total_seconds: float = maxf(1.0, float(end_time - start_time))
	zoom = size.x / total_seconds
	
	view_offset_time = float(start_time)
	queue_redraw()

func time_to_x(t: float) -> float:
	return (t - view_offset_time) * zoom

func x_to_time(x: float) -> float:
	return (x / zoom) + view_offset_time

func _clamp_view():
	var total_range_sec: float = float(end_time - start_time)
	var screen_width_in_seconds: float = size.x / zoom
	
	if screen_width_in_seconds > total_range_sec:
		zoom = size.x / total_range_sec
		screen_width_in_seconds = total_range_sec
	
	view_offset_time = clampf(view_offset_time, float(start_time), float(end_time) - screen_width_in_seconds)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and mouse_event.pressed:
			var zoom_factor: float = 1.25 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8
			var mouse_time: float = x_to_time(mouse_event.position.x)
			
			zoom = clampf(zoom * zoom_factor, 0.000000001, 0.2)
			view_offset_time = mouse_time - (mouse_event.position.x / zoom)
			
			_clamp_view()
			queue_redraw()
			accept_event()
			
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if mouse_event.double_click:
					var click_time: int = int(x_to_time(mouse_event.position.x))
					if click_time >= start_time and click_time <= end_time:
						timeline_double_clicked.emit(click_time)
					_is_dragging = false 
				else:
					_is_dragging = true
					_drag_start_pos = mouse_event.position
					_drag_start_offset = view_offset_time
			else:
				if _is_dragging:
					if mouse_event.position.distance_to(_drag_start_pos) < 5.0:
						timeline_single_clicked.emit()
					_is_dragging = false

	elif event is InputEventMouseMotion and _is_dragging:
		var motion_event := event as InputEventMouseMotion
		var delta_x: float = motion_event.position.x - _drag_start_pos.x
		view_offset_time = _drag_start_offset - (delta_x / zoom)
		_clamp_view()
		queue_redraw()

func _draw():
	var axis_y: float = size.y * 0.5
	var width: float = size.x
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 12
	
	var start_x: float = time_to_x(float(start_time))
	var end_x: float = time_to_x(float(end_time))
	
	if start_x > 0:
		draw_rect(Rect2(0, 0, start_x, size.y), Color(0.1, 0.1, 0.1, 0.1))
	if end_x < width:
		draw_rect(Rect2(end_x, 0, width - end_x, size.y), Color(0.1, 0.1, 0.1, 0.1))
	
	draw_line(Vector2(maxf(0, start_x), axis_y), Vector2(minf(width, end_x), axis_y), Color(0.2, 0.2, 0.2), 2.0)
	
	var visible_start_t: int = int(maxf(float(start_time), x_to_time(0)))
	var visible_end_t: int = int(minf(float(end_time), x_to_time(width)))
	
	var dt_start: Dictionary = Time.get_datetime_dict_from_unix_time(visible_start_t) as Dictionary
	var dt_end: Dictionary = Time.get_datetime_dict_from_unix_time(visible_end_t) as Dictionary
	
	var px_per_day: float = zoom * sec_day
	var px_per_hour: float = zoom * sec_hour

	for y: int in range(int(dt_start.year), int(dt_end.year) + 1):
		var year_ts: int = int(Time.get_unix_time_from_datetime_dict({"year": y, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0}))
		if year_ts > end_time: break
		
		for m: int in range(1, 13):
			var month_ts: int = int(Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": 1, "hour": 0, "minute": 0, "second": 0}))
			if month_ts < start_time - (31 * sec_day): continue
			if month_ts > end_time: break
			
			var month_x: float = time_to_x(float(month_ts))
			
			if zoom * (sec_day * 28) > 20.0 and month_x >= 0 and month_x <= width:
				draw_line(Vector2(month_x, axis_y - 12), Vector2(month_x, axis_y + 12), Color(0.4, 0.4, 0.4, 0.5), 2.0)
				if zoom * (sec_day * 28) > 60.0:
					draw_string(font, Vector2(month_x + 5, axis_y - 25), month_names[m - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color.BLACK)			
			
			if px_per_day > 10.0:
				var days_in_month: int = get_days_in_month(m, y)
				var day_step: int = 1
				if px_per_day < 20.0: day_step = 5
				elif px_per_day < 40.0: day_step = 2
				
				for d: int in range(1, days_in_month + 1):
					var day_ts: int = month_ts + ((d - 1) * sec_day)
					if day_ts < start_time: continue
					if day_ts > end_time: break
					
					var day_x: float = time_to_x(float(day_ts))
					if d % day_step == 0 and day_x >= 0 and day_x <= width:
						draw_line(Vector2(day_x, axis_y - 8), Vector2(day_x, axis_y + 8), Color(0.5, 0.5, 0.5, 0.6), 1.0)
						if px_per_day > 10.0:
							draw_string(font, Vector2(day_x + 5, axis_y + 20), str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color(0.2, 0.2, 0.2))
					
					if px_per_hour > 5.0:
						var hour_step: int = 6
						if px_per_hour > 30.0: hour_step = 1
						elif px_per_hour > 15.0: hour_step = 3
						
						for h: int in range(0, 24, hour_step):
							if h == 0: continue
							var hr_ts: int = day_ts + (h * sec_hour)
							if hr_ts < start_time or hr_ts > end_time: continue
							
							var hr_x: float = time_to_x(float(hr_ts))
							if hr_x >= 0 and hr_x <= width:
								draw_line(Vector2(hr_x, axis_y - 4), Vector2(hr_x, axis_y + 4), Color(0.6, 0.6, 0.6, 0.5), 1.0)
								
								if px_per_hour > 10.0:
									var hr_label: String = str(h) + ":00"
									draw_string(font, Vector2(hr_x - 10, axis_y - 12), hr_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 3, Color(0.3, 0.3, 0.3))
		var year_x: float = time_to_x(float(year_ts))
		if year_x >= 0 and year_x <= width:
			draw_line(Vector2(year_x, 0), Vector2(year_x, size.y), Color(0, 0, 0, 0.2), 1.5)
			draw_string(font, Vector2(year_x + 5, 25), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 4, Color.BLACK)
	_current_time_dot()

func _current_time_dot():
	var utc_time: float = Time.get_unix_time_from_system()
	var tz_offset: float = Time.get_time_zone_from_system().bias * 60.0
	var local_time: float = utc_time + tz_offset
	var current_time_x: float = time_to_x(local_time)
	var width: float = size.x
	var axis_y: float = size.y * 0.5
	if current_time_x >= 0 and current_time_x <= width:
		draw_circle(Vector2(current_time_x, axis_y), 6.0, Color(1.0, 0.0, 0.0, 0.5))

func _process(_delta: float):
	queue_redraw()
