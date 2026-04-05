@tool
extends Area2D
class_name RechargeCell

@export var size := Vector2(72.0, 88.0):
	set(value):
		size = Vector2(maxf(value.x, 32.0), maxf(value.y, 32.0))
		_sync_geometry()
@export var recharge_amount := -1.0
@export var cooldown := 30.0
@export var shell_color := Color("ffd95b"):
	set(value):
		shell_color = value
		queue_redraw()
@export var core_color := Color("fff9c8"):
	set(value):
		core_color = value
		queue_redraw()
@export var inactive_tint := Color(0.4, 0.4, 0.4, 0.75)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _cooldown_left := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
	_sync_geometry()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var was_on_cooldown := _cooldown_left > 0.0
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if was_on_cooldown and _cooldown_left == 0.0:
		set_deferred("monitoring", true)
		queue_redraw()
	elif _cooldown_left > 0.0:
		queue_redraw()


func _draw() -> void:
	var half := size * 0.5
	var tint := Color.WHITE if _cooldown_left <= 0.0 else inactive_tint
	var body_rect := Rect2(Vector2(-half.x * 0.56, -half.y * 0.4), Vector2(half.x * 1.12, half.y * 0.95))
	var top_points := PackedVector2Array([
		Vector2(-half.x * 0.56, -half.y * 0.4),
		Vector2(-half.x * 0.38, -half.y * 0.78),
		Vector2(half.x * 0.38, -half.y * 0.78),
		Vector2(half.x * 0.56, -half.y * 0.4),
	])
	var core_rect := Rect2(Vector2(-half.x * 0.2, -half.y * 0.2), Vector2(half.x * 0.4, half.y * 0.54))

	draw_colored_polygon(top_points, shell_color * tint)
	draw_rect(body_rect, shell_color * tint, true)
	draw_rect(core_rect, core_color * tint, true)
	draw_rect(body_rect, Color("fff6bf") * tint, false, 3.0)

	for i in range(4):
		var ratio := float(i + 1) / 5.0
		var x := lerpf(body_rect.position.x + 6.0, body_rect.end.x - 6.0, ratio)
		draw_line(
			Vector2(x, body_rect.position.y + body_rect.size.y * 0.22),
			Vector2(x, body_rect.end.y - 6.0),
			Color("ffe987") * tint,
			1.5,
			true
		)

	if _cooldown_left > 0.0:
		var seconds_left := int(ceili(_cooldown_left))
		var label := str(seconds_left)
		var font := ThemeDB.fallback_font
		var font_size := ThemeDB.fallback_font_size + 6
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos := Vector2(-text_size.x * 0.5, text_size.y * 0.4)
		draw_string(font, text_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff7cc"))


func _on_body_entered(body: Node) -> void:
	if Engine.is_editor_hint() or _cooldown_left > 0.0:
		return
	if not (body is SubmarinePlayer):
		return

	var player := body as SubmarinePlayer
	var collected := false
	if recharge_amount <= 0.0:
		collected = player.refill_battery()
	else:
		collected = player.change_battery(recharge_amount)
	if not collected:
		return

	_cooldown_left = cooldown
	set_deferred("monitoring", false)
	queue_redraw()


func _sync_geometry() -> void:
	queue_redraw()
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size
