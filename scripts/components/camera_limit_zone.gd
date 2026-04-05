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
	var rect_size := _get_shape_size()

	var local_point := to_local(global_point)
	var half := rect_size * 0.5
	return Rect2(-half, rect_size).has_point(local_point)


func get_area_score() -> float:
	var rect_size := _get_shape_size()
	var scale_factors := global_transform.get_scale()
	return rect_size.x * rect_size.y * absf(scale_factors.x) * absf(scale_factors.y)


func get_resolved_limits() -> Vector4:
	var scene_offset := _get_scene_root_global_offset()
	return Vector4(
		float(limit_left) + scene_offset.x,
		float(limit_top) + scene_offset.y,
		float(limit_right) + scene_offset.x,
		float(limit_bottom) + scene_offset.y
	)


func _sync_geometry() -> void:
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size


func _get_shape_size() -> Vector2:
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		return (collision_shape.shape as RectangleShape2D).size
	return size


func _get_scene_root_global_offset() -> Vector2:
	var scene_root := _find_scene_root()
	if scene_root is Node2D:
		return (scene_root as Node2D).global_position
	return Vector2.ZERO


func _find_scene_root() -> Node:
	var current := get_parent()
	while current != null:
		if not current.scene_file_path.is_empty():
			return current
		current = current.get_parent()
	return null


func _on_body_entered(body: Node) -> void:
	if body is SubmarinePlayer:
		player_entered_zone.emit(self)


func _on_body_exited(body: Node) -> void:
	if body is SubmarinePlayer:
		player_exited_zone.emit(self)
