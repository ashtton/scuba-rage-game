@tool
extends Area2D
class_name PiranhaPatrol

@export var patrol_points := PackedVector2Array([
	Vector2(-180, 0),
	Vector2(180, 0),
]):
	set(value):
		patrol_points = value
		_clamp_patrol_state()
		queue_redraw()
@export var patrol_speed := 180.0
@export var wait_time_at_point := 0.15
@export var bite_message := "A piranha pack tore through the hull."
@export var body_color := Color("e99245"):
	set(value):
		body_color = value
		queue_redraw()
@export var fin_color := Color("4f2d1b"):
	set(value):
		fin_color = value
		queue_redraw()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _current_index := 0
var _direction := 1
var _wait_time_left := 0.0


func _ready() -> void:
	_sync_collision_shape()
	_clamp_patrol_state()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or patrol_points.size() < 2:
		return

	if _wait_time_left > 0.0:
		_wait_time_left = maxf(_wait_time_left - delta, 0.0)
		return

	var target_index := _get_target_index()
	var target_position := patrol_points[target_index]
	position = position.move_toward(target_position, patrol_speed * delta)

	if position.distance_to(target_position) <= 0.5:
		position = target_position
		_current_index = target_index
		if _current_index == patrol_points.size() - 1:
			_direction = -1
		elif _current_index == 0:
			_direction = 1
		_wait_time_left = wait_time_at_point


func _draw() -> void:
	var body_points := PackedVector2Array([
		Vector2(-34, -20),
		Vector2(24, -18),
		Vector2(38, -2),
		Vector2(24, 18),
		Vector2(-34, 20),
		Vector2(-44, 0),
	])
	draw_colored_polygon(body_points, body_color)

	var tail_points := PackedVector2Array([
		Vector2(-44, 0),
		Vector2(-64, -18),
		Vector2(-68, 0),
		Vector2(-64, 18),
	])
	draw_colored_polygon(tail_points, fin_color)

	var top_fin := PackedVector2Array([
		Vector2(-10, -18),
		Vector2(2, -36),
		Vector2(14, -18),
	])
	draw_colored_polygon(top_fin, fin_color)

	var eye_position := Vector2(20, -6)
	draw_circle(eye_position, 4.4, Color("fff4d6"))
	draw_circle(eye_position + Vector2(1.5, 0), 1.9, Color("20170f"))

	var teeth := PackedVector2Array([
		Vector2(28, 6),
		Vector2(34, 2),
		Vector2(39, 7),
		Vector2(35, 13),
	])
	draw_colored_polygon(teeth, Color("fff2cd"))

	if Engine.is_editor_hint() and patrol_points.size() >= 2:
		for i in range(patrol_points.size() - 1):
			draw_line(patrol_points[i], patrol_points[i + 1], Color("7ac8ff", 0.75), 2.0, true)
		for point in patrol_points:
			draw_circle(point, 4.0, Color("9fe3ff", 0.9))


func _on_body_entered(body: Node) -> void:
	if body is SubmarinePlayer:
		(body as SubmarinePlayer).die(bite_message)


func _get_target_index() -> int:
	return clampi(_current_index + _direction, 0, patrol_points.size() - 1)


func _clamp_patrol_state() -> void:
	if patrol_points.is_empty():
		patrol_points = PackedVector2Array([Vector2.ZERO])

	if _current_index >= patrol_points.size():
		_current_index = patrol_points.size() - 1
	if _current_index < 0:
		_current_index = 0

	if patrol_points.size() > 0:
		position = patrol_points[_current_index]
		queue_redraw()


func _sync_collision_shape() -> void:
	if not is_node_ready():
		return

	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule == null:
		capsule = CapsuleShape2D.new()
		collision_shape.shape = capsule

	capsule.radius = 18.0
	capsule.height = 58.0
	collision_shape.rotation_degrees = 90.0
