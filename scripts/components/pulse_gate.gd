@tool
extends Node2D
class_name PulseGate

@export var size := Vector2(280.0, 28.0):
	set(value):
		size = Vector2(maxf(value.x, 64.0), maxf(value.y, 16.0))
		_sync_geometry()
@export var starts_open := false
@export var open_duration := 1.0
@export var closed_duration := 1.2
@export var phase_offset := 0.0
@export var closed_color := Color("ff6b6b"):
	set(value):
		closed_color = value
		queue_redraw()
@export var open_color := Color("7ef0ba"):
	set(value):
		open_color = value
		queue_redraw()
@export var hazard_message := "The surge gate snapped shut."

@onready var barrier_collision: CollisionShape2D = $Barrier/CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D

var _is_open := false
var _time_left := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	_sync_geometry()
	_is_open = starts_open
	_apply_state()
	_time_left = phase_offset if phase_offset > 0.0 else _get_state_duration()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_time_left -= delta
	if _time_left > 0.0:
		return

	_is_open = not _is_open
	_apply_state()
	_time_left += _get_state_duration()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var frame_color := open_color if _is_open else closed_color
	draw_rect(rect.grow(6.0), Color(0.039216, 0.121569, 0.160784, 0.85), true)
	draw_rect(rect, frame_color, false, 4.0)

	if _is_open:
		var ghost := open_color
		ghost.a = 0.18
		draw_rect(rect, ghost, true)
		for i in range(4):
			var offset := lerpf(-0.36, 0.36, float(i) / 3.0)
			draw_line(
				Vector2(rect.position.x + rect.size.x * 0.12, rect.position.y + rect.size.y * (0.5 + offset * 0.18)),
				Vector2(rect.position.x + rect.size.x * 0.88, rect.position.y + rect.size.y * (0.5 + offset * 0.18)),
				Color(open_color.r, open_color.g, open_color.b, 0.45),
				2.0,
				true
			)
		return

	var core_color := closed_color
	core_color.a = 0.82
	draw_rect(rect, core_color, true)
	for i in range(6):
		var ratio := float(i + 1) / 7.0
		var x := lerpf(rect.position.x + 18.0, rect.end.x - 18.0, ratio)
		draw_line(
			Vector2(x, rect.position.y + 3.0),
			Vector2(x, rect.end.y - 3.0),
			Color(1.0, 0.941176, 0.721569, 0.55),
			2.0,
			true
		)


func _on_hitbox_body_entered(body: Node) -> void:
	_try_destroy(body)


func _try_destroy(body: Node) -> void:
	if body is SubmarinePlayer:
		(body as SubmarinePlayer).die(hazard_message)


func _apply_state() -> void:
	barrier_collision.set_deferred("disabled", _is_open)
	hitbox.set_deferred("monitoring", not _is_open)
	queue_redraw()

	if not _is_open and not Engine.is_editor_hint():
		call_deferred("_destroy_overlaps")


func _destroy_overlaps() -> void:
	for body in hitbox.get_overlapping_bodies():
		_try_destroy(body)


func _get_state_duration() -> float:
	return maxf(open_duration if _is_open else closed_duration, 0.1)


func _sync_geometry() -> void:
	queue_redraw()
	if not is_node_ready():
		return

	var barrier_rectangle := barrier_collision.shape as RectangleShape2D
	if barrier_rectangle == null:
		barrier_rectangle = RectangleShape2D.new()
		barrier_collision.shape = barrier_rectangle
	barrier_rectangle.size = size

	var hitbox_rectangle := hitbox_collision.shape as RectangleShape2D
	if hitbox_rectangle == null:
		hitbox_rectangle = RectangleShape2D.new()
		hitbox_collision.shape = hitbox_rectangle
	hitbox_rectangle.size = size
