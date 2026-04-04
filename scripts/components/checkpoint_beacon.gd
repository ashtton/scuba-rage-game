@tool
extends Area2D
class_name CheckpointBeacon

signal reached(checkpoint: CheckpointBeacon)

@export var checkpoint_name := "Checkpoint"
@export var size := Vector2(104.0, 160.0):
	set(value):
		size = Vector2(maxf(value.x, 48.0), maxf(value.y, 64.0))
		_sync_geometry()
@export var spawn_offset := Vector2(0.0, 84.0)
@export var inactive_color := Color("52b4d6"):
	set(value):
		inactive_color = value
		queue_redraw()
@export var active_color := Color("ffe082"):
	set(value):
		active_color = value
		queue_redraw()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _active := false


func _ready() -> void:
	add_to_group("level_checkpoint")
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
	_sync_geometry()


func _draw() -> void:
	var beam_color := active_color if _active else inactive_color
	beam_color.a = 0.24
	var core_color := active_color if _active else inactive_color
	var rect := Rect2(Vector2(-size.x * 0.18, -size.y * 0.58), Vector2(size.x * 0.36, size.y * 0.78))
	draw_rect(rect, beam_color, true)
	draw_circle(Vector2.ZERO, size.x * 0.3, Color(beam_color.r, beam_color.g, beam_color.b, 0.32))
	draw_circle(Vector2.ZERO, size.x * 0.2, core_color)
	draw_circle(Vector2.ZERO, size.x * 0.08, Color("f5fcff"))

	var stem_half_width := size.x * 0.08
	draw_rect(
		Rect2(Vector2(-stem_half_width, 12.0), Vector2(stem_half_width * 2.0, size.y * 0.36)),
		Color("143749"),
		true
	)
	draw_rect(
		Rect2(Vector2(-size.x * 0.22, size.y * 0.36), Vector2(size.x * 0.44, size.y * 0.1)),
		Color("1f5268"),
		true
	)


func get_spawn_point() -> Vector2:
	return global_position + spawn_offset


func set_active(is_active: bool) -> void:
	if _active == is_active:
		return

	_active = is_active
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is SubmarinePlayer and not _active:
		reached.emit(self)


func _sync_geometry() -> void:
	queue_redraw()
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size
