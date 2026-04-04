extends Control


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			get_tree().change_scene_to_file("res://scenes/level_01.tscn")
