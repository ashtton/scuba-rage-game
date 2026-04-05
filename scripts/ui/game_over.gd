extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var back_to_menu_button: Button = $Panel/BackToMainMenuButton


func _ready() -> void:
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_back_to_menu_pressed()


func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
