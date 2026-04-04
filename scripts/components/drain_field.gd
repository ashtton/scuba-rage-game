@tool
extends Area2D
class_name DrainField

@export var size := Vector2(280.0, 280.0):
	set(value):
		size = Vector2(maxf(value.x, 48.0), maxf(value.y, 48.0))
		_sync_geometry()
@export var drain_per_second := 100.0
@export var fill_color := Color(0.941176, 0.309804, 0.384314, 0.18):
	set(value):
		fill_color = value
		queue_redraw()
@export var edge_color := Color("ffc16a"):
	set(value):
		edge_color = value
		queue_redraw()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sync_geometry()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	for body in get_overlapping_bodies():
		if body is SubmarinePlayer:
			(body as SubmarinePlayer).change_battery(-drain_per_second * delta)


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, edge_color, false, 3.0)

	var stripe_count := maxi(3, int(ceil((size.x + size.y) / 170.0)))
	for i in range(stripe_count):
		var ratio := float(i + 1) / float(stripe_count + 1)
		var start := Vector2(-size.x * 0.42, lerpf(-size.y * 0.42, size.y * 0.2, ratio))
		var mid := start + Vector2(size.x * 0.22, -size.y * 0.14)
		var finish := mid + Vector2(size.x * 0.22, size.y * 0.16)
		draw_polyline(PackedVector2Array([start, mid, finish]), edge_color, 3.0, true)


func _sync_geometry() -> void:
	queue_redraw()
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size
