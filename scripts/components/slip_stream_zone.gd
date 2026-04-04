@tool
extends Area2D
class_name SlipStreamZone

@export var size := Vector2(180.0, 360.0):
	set(value):
		size = Vector2(maxf(value.x, 48.0), maxf(value.y, 48.0))
		_sync_geometry()
@export var flow_vector := Vector2(0.0, -960.0):
	set(value):
		flow_vector = value
		queue_redraw()
@export var speed_scale := 1.0:
	set(value):
		speed_scale = maxf(value, 0.0)
		queue_redraw()
@export var fill_color := Color(0.172549, 0.772549, 0.87451, 0.2):
	set(value):
		fill_color = value
		queue_redraw()
@export var edge_color := Color("89ebff"):
	set(value):
		edge_color = value
		queue_redraw()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sync_geometry()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var effective_flow := flow_vector * speed_scale
	for body in get_overlapping_bodies():
		if body is SubmarinePlayer:
			(body as SubmarinePlayer).velocity += effective_flow * delta


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, edge_color, false, 3.0)

	var direction := flow_vector.normalized()
	if direction.length_squared() < 0.01:
		return

	var is_vertical := absf(direction.y) >= absf(direction.x)
	var arrow_length := (size.y if is_vertical else size.x) * 0.22
	var arrow_width := minf(size.x, size.y) * 0.12

	for i in range(3):
		var offset := lerpf(-0.28, 0.28, float(i) / 2.0)
		var center := Vector2.ZERO
		if is_vertical:
			center.x = size.x * offset
		else:
			center.y = size.y * offset
		_draw_arrow(center, direction, arrow_length, arrow_width)


func _draw_arrow(center: Vector2, direction: Vector2, length: float, width: float) -> void:
	var tail := center - direction * length * 0.5
	var tip := center + direction * length * 0.5
	var normal := direction.orthogonal()
	draw_line(tail, tip, edge_color, 4.0, true)
	draw_line(tip, tip - direction * length * 0.28 + normal * width * 0.5, edge_color, 4.0, true)
	draw_line(tip, tip - direction * length * 0.28 - normal * width * 0.5, edge_color, 4.0, true)


func _sync_geometry() -> void:
	queue_redraw()
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size
