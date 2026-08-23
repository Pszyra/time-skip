extends Control

@export var create_button: Button
@export var load_button: Button

func _on_create_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
	queue_free()
