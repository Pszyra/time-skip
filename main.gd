extends Control

const EVENT_SCENE: PackedScene = preload("res://TimelineEvent.tscn")

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
@export var placement_option: OptionButton
@export var color_picker: ColorPickerButton
@export var delete_btn: Button

var active_event: TimelineEvent = null

func _ready():
	if not setup_dialog:
		return
		
	setup_dialog.confirmed.connect(_on_setup_confirmed)
	setup_dialog.popup_centered()
	
	timeline_canvas.timeline_double_clicked.connect(_create_event_at)
	timeline_canvas.timeline_single_clicked.connect(_on_timeline_bg_clicked)
		
	name_edit.text_changed.connect(_on_inspector_name_changed)
	date_edit.text_submitted.connect(_on_inspector_date_submitted)
	placement_option.item_selected.connect(_on_inspector_placement_selected)
	color_picker.color_changed.connect(_on_inspector_color_changed)
	delete_btn.pressed.connect(_on_inspector_delete_pressed)

func _process(_delta: float):
	if not timeline_canvas: return
	
	var axis_y: float = timeline_canvas.size.y * 0.5
	var events: Array[TimelineEvent] = []
	
	for child in events_layer.get_children():
		if child is TimelineEvent:
			var ev: TimelineEvent = child as TimelineEvent
			var x: float = timeline_canvas.time_to_x(float(ev.timestamp))
			ev.position = Vector2(x, axis_y)
			if x > -500 and x < timeline_canvas.size.x + 500:
				events.append(ev)
				ev.visible = true
			else:
				ev.visible = false
				
	_recalculate_stacking(events)

func _recalculate_stacking(events: Array[TimelineEvent]):
	events.sort_custom(func(a, b): return a.position.x < b.position.x)
	
	var above_events = events.filter(func(e): return e.is_above)
	var below_events = events.filter(func(e): return not e.is_above)
	
	var above_lanes: Array[float] = []
	var below_lanes: Array[float] = []
	
	var base_height: float = 50.0
	var lane_spacing: float = 65.0
	var horizontal_padding: float = 10.0
	
	for ev in above_events:
		var card_width: float = ev.card.size.x
		var left_x: float = ev.position.x - (card_width / 2.0)
		var right_x: float = ev.position.x + (card_width / 2.0)
		
		var assigned_lane: int = _find_free_lane(above_lanes, left_x, horizontal_padding)
		ev.current_stalk_height = base_height + (assigned_lane * lane_spacing)
		above_lanes[assigned_lane] = right_x
		ev._update_visuals()

	for ev in below_events:
		var card_width: float = ev.card.size.x
		var left_x: float = ev.position.x - (card_width / 2.0)
		var right_x: float = ev.position.x + (card_width / 2.0)
		
		var assigned_lane: int = _find_free_lane(below_lanes, left_x, horizontal_padding)
		ev.current_stalk_height = base_height + (assigned_lane * lane_spacing)
		below_lanes[assigned_lane] = right_x
		ev._update_visuals()

func _find_free_lane(lanes: Array[float], left_x: float, padding: float) -> int:
	for i in range(lanes.size()):
		if left_x > lanes[i] + padding:
			return i
	lanes.append(-1000000.0)
	return lanes.size() - 1

func _on_setup_confirmed():
	timeline_canvas.setup_range(int(start_year_spin.value), int(end_year_spin.value))

func _create_event_at(timestamp: int):
	var ev: TimelineEvent = EVENT_SCENE.instantiate() as TimelineEvent
	events_layer.add_child(ev)
	ev.set_event_data("New Event", timestamp, true, Color(0.2, 0.6, 0.86))
	ev.selected.connect(_select_event)
	_select_event(ev)

func _select_event(ev: TimelineEvent):
	active_event = ev
	inspector_panel.visible = true
	name_edit.text = ev.event_name
	
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ev.timestamp) as Dictionary
	date_edit.text = "%04d-%02d-%02d %02d:%02d" % [
		int(dt["year"]), int(dt["month"]), int(dt["day"]), int(dt["hour"]), int(dt["minute"])
	]
	
	placement_option.selected = 0 if ev.is_above else 1
	color_picker.color = ev.event_color

func _on_inspector_name_changed():
	if is_instance_valid(active_event):
		active_event.event_name = name_edit.text
		active_event._update_visuals()

func _on_inspector_date_submitted(new_date_str: String):
	if not is_instance_valid(active_event): return
	var parts: PackedStringArray = new_date_str.strip_edges().split(" ")
	if parts.size() >= 1:
		var d_parts: PackedStringArray = parts[0].split("-")
		var h_parts: PackedStringArray = parts[1].split(":") if parts.size() > 1 else PackedStringArray(["00", "00"])
		if d_parts.size() == 3:
			var date_dict: Dictionary = {
				"year": int(d_parts[0]), "month": int(d_parts[1]), "day": int(d_parts[2]),
				"hour": int(h_parts[0]) if h_parts.size() > 0 else 0,
				"minute": int(h_parts[1]) if h_parts.size() > 1 else 0, "second": 0
			}
			active_event.timestamp = int(Time.get_unix_time_from_datetime_dict(date_dict))
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
