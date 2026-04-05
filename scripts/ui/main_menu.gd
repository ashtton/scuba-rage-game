extends Control

const GAMEPLAY_HUB_SCENE := "res://scenes/ui/gameplay_hub.tscn"

@export var robert_github_url := "https://github.com/RobertOrmand"
@export var robert_linkedin_url := "https://www.linkedin.com/in/robert-ormand/"
@export var ashton_github_url := "https://github.com/ashtoninman"
@export var ashton_linkedin_url := "https://www.linkedin.com/in/ashton-inman/"

@onready var shell: Panel = $Center/Shell
@onready var heading_group: VBoxContainer = $Center/Shell/Content/RootVBox/HeadingGroup
@onready var play_button: Button = $Center/Shell/Content/RootVBox/PlayButton
@onready var credits_group: VBoxContainer = $Center/Shell/Content/RootVBox/CreditsGroup
@onready var accent_a: Control = $AccentA
@onready var accent_b: Control = $AccentB
@onready var accent_c: Control = $AccentC

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	_connect_social_buttons()
	_setup_intro_state()
	_play_intro_animation()
	_start_ambient_motion()


func _connect_social_buttons() -> void:
	$Center/Shell/Content/RootVBox/CreditsGroup/RobertRow/RobertGithubButton.pressed.connect(func() -> void: _open_url(robert_github_url))
	$Center/Shell/Content/RootVBox/CreditsGroup/RobertRow/RobertLinkedInButton.pressed.connect(func() -> void: _open_url(robert_linkedin_url))
	$Center/Shell/Content/RootVBox/CreditsGroup/AshtonRow/AshtonGithubButton.pressed.connect(func() -> void: _open_url(ashton_github_url))
	$Center/Shell/Content/RootVBox/CreditsGroup/AshtonRow/AshtonLinkedInButton.pressed.connect(func() -> void: _open_url(ashton_linkedin_url))


func _setup_intro_state() -> void:
	shell.modulate.a = 0.0
	heading_group.modulate.a = 0.0
	play_button.modulate.a = 0.0
	credits_group.modulate.a = 0.0


func _play_intro_animation() -> void:
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shell, "modulate:a", 1.0, 0.45)
	tween.parallel().tween_property(heading_group, "modulate:a", 1.0, 0.45)
	tween.tween_interval(0.06)
	tween.tween_property(play_button, "modulate:a", 1.0, 0.35)
	tween.tween_interval(0.04)
	tween.tween_property(credits_group, "modulate:a", 1.0, 0.42)


func _start_ambient_motion() -> void:
	_pulse_control(accent_a, 12.0, 2.8)
	_pulse_control(accent_b, -10.0, 3.2)
	_pulse_control(accent_c, 8.0, 2.4)


func _pulse_control(node: Control, travel: float, duration: float) -> void:
	var start_y := node.position.y
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", start_y + travel, duration)
	tween.tween_property(node, "position:y", start_y, duration)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAMEPLAY_HUB_SCENE)


func _open_url(url: String) -> void:
	if url.strip_edges().is_empty():
		return
	OS.shell_open(url)
