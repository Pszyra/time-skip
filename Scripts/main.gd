extends Control

const EVENT_SCENE: PackedScene = preload("res://Scenes/TimelineEvent.tscn")

@export_group("Core")
@export var timeline_canvas: TimelineCanvas
@export var events_layer: Control

@export_group("Setup Dialog")
@export var setup_dialog: AcceptDialog
@export var start_year_spin: SpinBox
@export var end_year_spin: SpinBox

@export_group("Inspector Panel")
@export var inspector_panel: PanelContainer
@export var name_edit: TextEdit
@export var date_edit: LineEdit
@export var end_date_edit: LineEdit
@export var placement_option: OptionButton
@export var color_picker: ColorPickerButton
@export var delete_btn: Button

var active_event: TimelineEvent = null

func _ready():
	if not setup_dialog: return
	setup_dialog.confirmed.connect(_on_setup_confirmed)
	setup_dialog.popup_centered()
	
	timeline_canvas.timeline_double_clicked.connect(_create_event_at)
	timeline_canvas.timeline_single_clicked.connect(_on_timeline_bg_clicked)
	name_edit.text_changed.connect(_on_inspector_name_changed)
	date_edit.text_submitted.connect(_on_inspector_date_submitted)
	end_date_edit.text_submitted.connect(_on_inspector_end_date_submitted)
	placement_option.item_selected.connect(_on_inspector_placement_selected)
	color_picker.color_changed.connect(_on_inspector_color_changed)
	delete_btn.pressed.connect(_on_inspector_delete_pressed)
	
	start_year_spin.value = Time.get_date_dict_from_system().year
	end_year_spin.value = Time.get_date_dict_from_system().year

func _process(_delta: float):
	if not timeline_canvas: return
	
	var axis_y: float = timeline_canvas.size.y * 0.5
	var events: Array[TimelineEvent] = []
	
	for child in events_layer.get_children():
		if child is TimelineEvent:
			var ev: TimelineEvent = child as TimelineEvent
			
			var start_x: float = timeline_canvas.time_to_x(float(ev.timestamp))
			var final_x: float = start_x
			
			if ev.end_timestamp > ev.timestamp:
				var end_x: float = timeline_canvas.time_to_x(float(ev.end_timestamp))
				final_x = (start_x + end_x) / 2.0
			
			ev.position = Vector2(final_x, axis_y)
			
			ev.update_span_visual(timeline_canvas)
			
			if final_x > -1000 and final_x < timeline_canvas.size.x + 1000:
				events.append(ev)
				ev.visible = true
			else:
				ev.visible = false
				
	_recalculate_stacking(events)

func _recalculate_stacking(events: Array[TimelineEvent]):
	events.sort_custom(func(a, b): return a.position.x < b.position.x)
	var above_events = events.filter(func(e): return e.is_above)
	var below_events = events.filter(func(e): return not e.is_above)
	_layout_stacking(above_events)
	_layout_stacking(below_events)

func _layout_stacking(side_events: Array):
	var lanes_right_x: Array[float] = []
	var lanes_max_height: Array[float] = []
	
	var base_offset: float = 50.0
	var vertical_padding: float = 20.0
	var horizontal_padding: float = 15.0
	
	for ev in side_events:
		var card_size: Vector2 = ev.card.get_combined_minimum_size()
		
		var footprint_left: float = ev.position.x - (card_size.x / 2.0)
		var footprint_right: float = ev.position.x + (card_size.x / 2.0)
		
		var lane_idx: int = _find_free_lane(lanes_right_x, footprint_left, horizontal_padding)
		lanes_right_x[lane_idx] = footprint_right
		
		while lanes_max_height.size() <= lane_idx:
			lanes_max_height.append(0.0)
		lanes_max_height[lane_idx] = max(lanes_max_height[lane_idx], card_size.y)
		
		var total_stalk_height: float = base_offset
		for i in range(lane_idx):
			total_stalk_height += lanes_max_height[i] + vertical_padding
			
		ev.current_stalk_height = total_stalk_height
		ev._update_visuals()

func _find_free_lane(lanes: Array[float], left_x: float, padding: float) -> int:
	for i in range(lanes.size()):
		if left_x > lanes[i] + padding:
			return i
	lanes.append(-10000000.0)
	return lanes.size() - 1

func _parse_date_string(date_str: String) -> int:
	var parts = date_str.strip_edges().split(" ")
	if parts.size() < 1: return 0
	var d_parts = parts[0].split("-")
	if d_parts.size() != 3: return 0
	var h_parts = parts[1].split(":") if parts.size() > 1 else ["00", "00"]
	var date_dict = {
		"year": int(d_parts[0]), "month": int(d_parts[1]), "day": int(d_parts[2]),
		"hour": int(h_parts[0]), "minute": int(h_parts[1]), "second": 0
	}
	return int(Time.get_unix_time_from_datetime_dict(date_dict))

func _format_date(ts: int) -> String:
	var dt = Time.get_datetime_dict_from_unix_time(ts)
	return "%04d-%02d-%02d %02d:%02d" % [int(dt.year), int(dt.month), int(dt.day), int(dt.hour), int(dt.minute)]

func _create_event_at(timestamp: int):
	var ev: TimelineEvent = EVENT_SCENE.instantiate()
	events_layer.add_child(ev)
	ev.set_event_data("New Event", timestamp, true, Color(0.2, 0.6, 0.86))
	ev.selected.connect(_select_event)
	_select_event(ev)

func _select_event(ev: TimelineEvent):
	active_event = ev
	inspector_panel.visible = true
	name_edit.text = ev.event_name
	date_edit.text = _format_date(ev.timestamp)
	end_date_edit.text = _format_date(ev.end_timestamp) if ev.end_timestamp > ev.timestamp else ""
	placement_option.selected = 0 if ev.is_above else 1
	color_picker.color = ev.event_color

func _on_inspector_name_changed():
	if is_instance_valid(active_event):
		active_event.event_name = name_edit.text
		active_event._update_visuals()

func _on_inspector_date_submitted(new_date_str: String):
	if not is_instance_valid(active_event): return
	var ts = _parse_date_string(new_date_str)
	if ts > 0:
		active_event.timestamp = ts
		active_event._update_visuals()

func _on_inspector_end_date_submitted(new_date_str: String):
	if not is_instance_valid(active_event): return
	if new_date_str.strip_edges() == "":
		active_event.end_timestamp = 0
	else:
		var ts = _parse_date_string(new_date_str)
		if ts > active_event.timestamp:
			active_event.end_timestamp = ts
	active_event._update_visuals()

func _on_inspector_placement_selected(idx: int):
	if is_instance_valid(active_event):
		active_event.is_above = (idx == 0)
		active_event._update_visuals()

func _on_inspector_color_changed(n_color: Color):
	if is_instance_valid(active_event):
		active_event.event_color = n_color
		active_event._update_visuals()

func _on_inspector_delete_pressed():
	if is_instance_valid(active_event):
		active_event.queue_free()
		active_event = null
		inspector_panel.visible = false

func _on_timeline_bg_clicked():
	active_event = null
	inspector_panel.visible = false
	
func _on_setup_confirmed():
	timeline_canvas.setup_range(int(start_year_spin.value), int(end_year_spin.value))
