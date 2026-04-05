extends Control

const GAME_SCENE := "res://scenes/game.tscn"

@export var robert_github_url := "https://github.com/ROrmand"
@export var robert_linkedin_url := "https://www.linkedin.com/in/robertormand/"
@export var ashton_github_url := "https://github.com/ashtton"
@export var ashton_linkedin_url := "https://www.linkedin.com/in/ashton-inman/"

@onready var start_game_button: Button = $ButtonLayer/StartGameButton
@onready var quit_game_button: Button = $ButtonLayer/QuitGameButton
@onready var footer: PanelContainer = $Footer
@onready var jam_label: Label = $Footer/FooterMargin/FooterVBox/JamLabel
@onready var robert_name: Label = $Footer/FooterMargin/FooterVBox/CreditsRow/RobertRow/RobertName
@onready var ashton_name: Label = $Footer/FooterMargin/FooterVBox/CreditsRow/AshtonRow/AshtonName

func _ready() -> void:
	start_game_button.pressed.connect(_on_play_pressed)
	quit_game_button.pressed.connect(_on_quit_pressed)
	_connect_social_buttons()
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_play_intro_animation()


func _connect_social_buttons() -> void:
	$Footer/FooterMargin/FooterVBox/CreditsRow/RobertRow/RobertGithubButton.pressed.connect(func() -> void: _open_url(robert_github_url))
	$Footer/FooterMargin/FooterVBox/CreditsRow/RobertRow/RobertLinkedInButton.pressed.connect(func() -> void: _open_url(robert_linkedin_url))
	$Footer/FooterMargin/FooterVBox/CreditsRow/AshtonRow/AshtonGithubButton.pressed.connect(func() -> void: _open_url(ashton_github_url))
	$Footer/FooterMargin/FooterVBox/CreditsRow/AshtonRow/AshtonLinkedInButton.pressed.connect(func() -> void: _open_url(ashton_linkedin_url))


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var scale_factor := clampf(viewport_size.y / 1080.0, 0.55, 1.6)
	var start_width := clampf(660.0 * scale_factor, 420.0, 1040.0)
	var start_height := clampf(104.0 * scale_factor, 70.0, 164.0)
	var quit_width := clampf(520.0 * scale_factor, 340.0, 860.0)
	var quit_height := clampf(90.0 * scale_factor, 64.0, 132.0)
	var vertical_gap := clampf(30.0 * scale_factor, 18.0, 56.0)

	start_game_button.position = Vector2(viewport_size.x * 0.5 - start_width * 0.5, viewport_size.y * 0.40)
	start_game_button.size = Vector2(start_width, start_height)
	start_game_button.add_theme_font_size_override("font_size", int(clampf(54.0 * scale_factor, 28.0, 84.0)))

	quit_game_button.position = Vector2(viewport_size.x * 0.5 - quit_width * 0.5, start_game_button.position.y + start_height + vertical_gap)
	quit_game_button.size = Vector2(quit_width, quit_height)
	quit_game_button.add_theme_font_size_override("font_size", int(clampf(42.0 * scale_factor, 22.0, 68.0)))

	footer.anchor_top = clampf(0.80, 0.72, 0.86)
	jam_label.add_theme_font_size_override("font_size", int(clampf(62.0 * scale_factor, 24.0, 96.0)))
	robert_name.add_theme_font_size_override("font_size", int(clampf(56.0 * scale_factor, 20.0, 84.0)))
	ashton_name.add_theme_font_size_override("font_size", int(clampf(56.0 * scale_factor, 20.0, 84.0)))

	var icon_size := int(clampf(56.0 * scale_factor, 30.0, 86.0))
	for button in [
		$Footer/FooterMargin/FooterVBox/CreditsRow/RobertRow/RobertLinkedInButton,
		$Footer/FooterMargin/FooterVBox/CreditsRow/RobertRow/RobertGithubButton,
		$Footer/FooterMargin/FooterVBox/CreditsRow/AshtonRow/AshtonLinkedInButton,
		$Footer/FooterMargin/FooterVBox/CreditsRow/AshtonRow/AshtonGithubButton
	]:
		button.custom_minimum_size = Vector2(icon_size, icon_size)


func _play_intro_animation() -> void:
	start_game_button.modulate.a = 0.0
	quit_game_button.modulate.a = 0.0
	footer.modulate.a = 0.0

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(start_game_button, "modulate:a", 1.0, 0.4)
	tween.tween_interval(0.04)
	tween.tween_property(quit_game_button, "modulate:a", 1.0, 0.34)
	tween.tween_interval(0.04)
	tween.tween_property(footer, "modulate:a", 1.0, 0.42)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_url(url: String) -> void:
	if url.strip_edges().is_empty():
		return
	OS.shell_open(url)
