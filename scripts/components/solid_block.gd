@tool
extends StaticBody2D
class_name SolidBlock

@export var size := Vector2(240.0, 120.0):
	set(value):
		size = Vector2(maxf(value.x, 24.0), maxf(value.y, 24.0))
		_sync_geometry()
@export var fill_color := Color("35566a"):
	set(value):
		fill_color = value
		queue_redraw()
@export var border_color := Color("6fd6ef"):
	set(value):
		border_color = value
		queue_redraw()
@export var border_width := 4.0:
	set(value):
		border_width = maxf(value, 1.0)
		queue_redraw()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sync_geometry()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, border_color, false, border_width)


func _sync_geometry() -> void:
	queue_redraw()
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size
