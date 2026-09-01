extends Control
class_name MenuBarUI

signal today_requested

@export var texture_button: TextureButton
@export var anim_player: AnimationPlayer
@export var year_label: Label
@export var today_button: Button

func _ready() -> void:
	if today_button:
		today_button.pressed.connect(func(): today_requested.emit())

func _on_texture_button_toggled(_toggled_on: bool) -> void:
	if texture_button.button_pressed:
		anim_player.play("Slide")
	else:
		anim_player.play("Slide_up")

func set_year(year: int) -> void:
	if year_label:
		year_label.text = str(year)
