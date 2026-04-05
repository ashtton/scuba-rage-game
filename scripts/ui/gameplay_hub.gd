extends Control

const LEVEL_ONE_NEW := "res://scenes/level_01new.tscn"
const LEVEL_TWO := "res://scenes/level_2.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

func _ready() -> void:
	$Center/HubPanel/Padding/Actions/LevelOneButton.pressed.connect(func() -> void: _go_to_scene(LEVEL_ONE_NEW))
	$Center/HubPanel/Padding/Actions/LevelTwoButton.pressed.connect(func() -> void: _go_to_scene(LEVEL_TWO))
	$Center/HubPanel/Padding/Actions/BackButton.pressed.connect(func() -> void: _go_to_scene(MAIN_MENU))
	_play_intro_animation()


func _play_intro_animation() -> void:
	var panel: Panel = $Center/HubPanel
	var actions: VBoxContainer = $Center/HubPanel/Padding/Actions
	panel.modulate.a = 0.0
	actions.modulate.a = 0.0

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	tween.tween_property(actions, "modulate:a", 1.0, 0.35)


func _go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
