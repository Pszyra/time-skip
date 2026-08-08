class_name TimelineEvent
extends Control

signal selected(event_node: TimelineEvent)

@export var event_name: String = "New Event"
@export var timestamp: int = 0
@export var is_above: bool = true
@export var event_color: Color = Color(0.2, 0.6, 0.86)

@onready var card: PanelContainer = $Card
@onready var stalk_line: Line2D = $Line
@onready var title_label: Label = $Card/MarginContainer/VBoxContainer/TitleLabel
@onready var date_label: Label = $Card/MarginContainer/VBoxContainer/DateLabel

var current_stalk_height: float = 90.0

func _ready():
	card.gui_input.connect(_on_card_gui_input)
	_update_visuals()

func _on_card_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)
		get_viewport().set_input_as_handled()

func set_event_data(n_name: String, n_ts: int, n_above: bool, n_color: Color):
	event_name = n_name
	timestamp = n_ts
	is_above = n_above
	event_color = n_color
	_update_visuals()

func _update_visuals():
	if not is_inside_tree():
		return
	title_label.text = event_name
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp) as Dictionary
	date_label.text = "%04d-%02d-%02d %02d:%02d" % [int(dt.year), int(dt.month), int(dt.day), int(dt.hour), int(dt.minute)]
	
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = event_color
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.corner_radius_bottom_right = 6
	style_box.content_margin_left = 8
	style_box.content_margin_right = 8
	style_box.content_margin_top = 4
	style_box.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style_box)

	var y_dir: float = -1.0 if is_above else 1.0
	var target_y: float = y_dir * current_stalk_height
	
	stalk_line.clear_points()
	stalk_line.add_point(Vector2.ZERO)
	stalk_line.add_point(Vector2(0, target_y))
	stalk_line.default_color = event_color
	stalk_line.width = 2.0
	
	card.reset_size()
	card.position = Vector2(-card.size.x * 0.5, target_y - (card.size.y if is_above else 0.0))
