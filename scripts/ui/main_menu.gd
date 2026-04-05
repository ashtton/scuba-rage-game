extends Control

const GAMEPLAY_HUB_SCENE := "res://scenes/ui/gameplay_hub.tscn"

@export var robert_github_url := "https://github.com/RobertOrmand"
@export var robert_linkedin_url := "https://www.linkedin.com/in/robert-ormand/"
@export var ashton_github_url := "https://github.com/ashtoninman"
@export var ashton_linkedin_url := "https://www.linkedin.com/in/ashton-inman/"

@onready var safe_area: MarginContainer = $SafeArea
@onready var shell: Panel = $SafeArea/Center/Shell
@onready var heading_group: VBoxContainer = $SafeArea/Center/Shell/Content/RootVBox/HeadingGroup
@onready var play_button: Button = $SafeArea/Center/Shell/Content/RootVBox/PlayButton
@onready var credits_group: VBoxContainer = $SafeArea/Center/Shell/Content/RootVBox/CreditsGroup
@onready var game_title: Label = $SafeArea/Center/Shell/Content/RootVBox/HeadingGroup/GameTitle
@onready var tagline: Label = $SafeArea/Center/Shell/Content/RootVBox/HeadingGroup/Tagline
@onready var jam_line: Label = $SafeArea/Center/Shell/Content/RootVBox/HeadingGroup/JamLine
@onready var created_by: Label = $SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/CreatedBy
@onready var robert_label: Label = $SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/RobertCard/RobertPad/RobertRow/RobertLabel
@onready var ashton_label: Label = $SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/AshtonCard/AshtonPad/AshtonRow/AshtonLabel
@onready var accent_a: Control = $AccentA
@onready var accent_b: Control = $AccentB
@onready var accent_c: Control = $AccentC

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	_connect_social_buttons()
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_setup_intro_state()
	_play_intro_animation()
	_start_ambient_motion()


func _connect_social_buttons() -> void:
	$SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/RobertCard/RobertPad/RobertRow/RobertGithubButton.pressed.connect(func() -> void: _open_url(robert_github_url))
	$SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/RobertCard/RobertPad/RobertRow/RobertLinkedInButton.pressed.connect(func() -> void: _open_url(robert_linkedin_url))
	$SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/AshtonCard/AshtonPad/AshtonRow/AshtonGithubButton.pressed.connect(func() -> void: _open_url(ashton_github_url))
	$SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/AshtonCard/AshtonPad/AshtonRow/AshtonLinkedInButton.pressed.connect(func() -> void: _open_url(ashton_linkedin_url))


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var short_edge := minf(viewport_size.x, viewport_size.y)
	var ui_scale := clampf(short_edge / 1080.0, 0.68, 1.55)

	var margin_x := int(clampf(viewport_size.x * 0.04, 24.0, 140.0))
	var margin_y := int(clampf(viewport_size.y * 0.04, 20.0, 108.0))
	safe_area.add_theme_constant_override("margin_left", margin_x)
	safe_area.add_theme_constant_override("margin_right", margin_x)
	safe_area.add_theme_constant_override("margin_top", margin_y)
	safe_area.add_theme_constant_override("margin_bottom", margin_y)

	var shell_width := clampf(viewport_size.x * 0.62, 760.0, 1220.0)
	var shell_height := clampf(viewport_size.y * 0.78, 620.0, 920.0)
	shell.custom_minimum_size = Vector2(shell_width, shell_height)

	var title_size := int(clampf(84.0 * ui_scale, 48.0, 132.0))
	var subtitle_size := int(clampf(28.0 * ui_scale, 18.0, 42.0))
	var jam_size := int(clampf(20.0 * ui_scale, 14.0, 30.0))
	var button_text_size := int(clampf(34.0 * ui_scale, 22.0, 48.0))
	var credit_text_size := int(clampf(22.0 * ui_scale, 15.0, 32.0))

	game_title.add_theme_font_size_override("font_size", title_size)
	tagline.add_theme_font_size_override("font_size", subtitle_size)
	jam_line.add_theme_font_size_override("font_size", jam_size)
	created_by.add_theme_font_size_override("font_size", credit_text_size)
	robert_label.add_theme_font_size_override("font_size", credit_text_size)
	ashton_label.add_theme_font_size_override("font_size", credit_text_size)
	play_button.add_theme_font_size_override("font_size", button_text_size)

	play_button.custom_minimum_size = Vector2(clampf(shell_width * 0.42, 280.0, 540.0), clampf(88.0 * ui_scale, 64.0, 110.0))

	var icon_size := int(clampf(56.0 * ui_scale, 40.0, 74.0))
	for button in [
		$SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/RobertCard/RobertPad/RobertRow/RobertGithubButton,
		$SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/RobertCard/RobertPad/RobertRow/RobertLinkedInButton,
		$SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/AshtonCard/AshtonPad/AshtonRow/AshtonGithubButton,
		$SafeArea/Center/Shell/Content/RootVBox/CreditsGroup/AshtonCard/AshtonPad/AshtonRow/AshtonLinkedInButton
	]:
		button.custom_minimum_size = Vector2(icon_size, icon_size)

	_deferred_sync_pivots.call_deferred()


func _deferred_sync_pivots() -> void:
	shell.pivot_offset = shell.size * 0.5
	play_button.pivot_offset = play_button.size * 0.5


func _setup_intro_state() -> void:
	shell.modulate.a = 0.0
	shell.scale = Vector2(0.97, 0.97)
	heading_group.modulate.a = 0.0
	play_button.modulate.a = 0.0
	play_button.scale = Vector2(0.95, 0.95)
	credits_group.modulate.a = 0.0


func _play_intro_animation() -> void:
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shell, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(shell, "scale", Vector2.ONE, 0.5)
	tween.parallel().tween_property(heading_group, "modulate:a", 1.0, 0.46)
	tween.tween_interval(0.06)
	tween.tween_property(play_button, "modulate:a", 1.0, 0.36)
	tween.parallel().tween_property(play_button, "scale", Vector2.ONE, 0.42)
	tween.tween_interval(0.06)
	tween.tween_property(credits_group, "modulate:a", 1.0, 0.45)


func _start_ambient_motion() -> void:
	_pulse_control(accent_a, 14.0, 3.0)
	_pulse_control(accent_b, -11.0, 3.6)
	_pulse_control(accent_c, 9.0, 2.8)
	_pulse_play_button()


func _pulse_control(node: Control, travel: float, duration: float) -> void:
	var start_y := node.position.y
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", start_y + travel, duration)
	tween.tween_property(node, "position:y", start_y, duration)


func _pulse_play_button() -> void:
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(1.4)
	tween.tween_property(play_button, "scale", Vector2(1.02, 1.02), 0.65)
	tween.tween_property(play_button, "scale", Vector2.ONE, 0.65)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAMEPLAY_HUB_SCENE)


func _open_url(url: String) -> void:
	if url.strip_edges().is_empty():
		return
	OS.shell_open(url)
