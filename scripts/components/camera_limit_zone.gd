@tool
extends Area2D
class_name CameraLimitZone

signal player_entered_zone(zone: CameraLimitZone)
signal player_exited_zone(zone: CameraLimitZone)

@export var size := Vector2(360.0, 280.0):
	set(value):
		size = Vector2(maxf(value.x, 32.0), maxf(value.y, 32.0))
		_sync_geometry()
@export var limit_left := 0
@export var limit_top := 0
@export var limit_right := 1920
@export var limit_bottom := 1080
@export var camera_priority := 0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("camera_limit_zone")
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	_sync_geometry()


func contains_global_point(global_point: Vector2) -> bool:
	var rect_size := size
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		rect_size = (collision_shape.shape as RectangleShape2D).size

	var local_point := to_local(global_point)
	var half := rect_size * 0.5
	return Rect2(-half, rect_size).has_point(local_point)


func get_area_score() -> float:
	return size.x * size.y


func _sync_geometry() -> void:
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size


func _on_body_entered(body: Node) -> void:
	if body is SubmarinePlayer:
		player_entered_zone.emit(self)


func _on_body_exited(body: Node) -> void:
	if body is SubmarinePlayer:
		player_exited_zone.emit(self)
