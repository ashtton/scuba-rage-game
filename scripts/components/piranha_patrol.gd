@tool
extends Area2D
class_name PiranhaPatrol

var patrol_points := PackedVector2Array([
	Vector2(-180, 0),
	Vector2(180, 0),
]):
	set(value):
		patrol_points = value
		if not _is_syncing_from_path:
			_rebuild_path_from_patrol_points()
		_clamp_patrol_state()
		queue_redraw()
@export var patrol_speed := 180.0
@export var wait_time_at_point := 0.15
@export var bite_message := "A piranha pack tore through the hull."
@export var bite_knockback_speed := 920.0
@export var bite_stun_duration := 5.0
@export var body_color := Color("e99245"):
	set(value):
		body_color = value
		queue_redraw()
@export var fin_color := Color("4f2d1b"):
	set(value):
		fin_color = value
		queue_redraw()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var patrol_path: Path2D = $PatrolPath

var _current_index := 0
var _direction := 1
var _wait_time_left := 0.0
var _facing_sign := 1.0
var _is_syncing_from_path := false
var _last_path_signature := ""


func _ready() -> void:
	_sync_collision_shape()
	_ensure_path_setup()
	if _has_valid_path_points():
		_sync_patrol_points_from_path(true)
	elif patrol_points.size() >= 2:
		_rebuild_path_from_patrol_points()
	_clamp_patrol_state()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_patrol_points_from_path()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or patrol_points.size() < 2:
		return

	if _wait_time_left > 0.0:
		_wait_time_left = maxf(_wait_time_left - delta, 0.0)
		_apply_facing()
		return

	var target_index := _get_target_index()
	var target_position := patrol_points[target_index]
	var movement_direction := target_position - position
	_update_facing_from_vector(movement_direction)
	position = position.move_toward(target_position, patrol_speed * delta)
	_apply_facing()

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
			var start := _patrol_point_to_local(patrol_points[i])
			var finish := _patrol_point_to_local(patrol_points[i + 1])
			draw_line(start, finish, Color("7ac8ff", 0.75), 2.0, true)
		for point in patrol_points:
			draw_circle(_patrol_point_to_local(point), 4.0, Color("9fe3ff", 0.9))


func _on_body_entered(body: Node) -> void:
	if body is SubmarinePlayer:
		var player := body as SubmarinePlayer
		player.apply_hazard_bounce(Vector2.DOWN, bite_knockback_speed)
		player.stun_for(bite_stun_duration, "piranha", bite_message)


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
		if patrol_points.size() > 1:
			_update_facing_from_vector(patrol_points[1] - patrol_points[0])
		_apply_facing()
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


func _update_facing_from_vector(direction: Vector2) -> void:
	if absf(direction.x) < 0.01:
		return
	_facing_sign = 1.0 if direction.x >= 0.0 else -1.0


func _apply_facing() -> void:
	scale.x = _facing_sign


func _patrol_point_to_local(point: Vector2) -> Vector2:
	var parent_node := get_parent() as Node2D
	if parent_node == null:
		return point
	return to_local(parent_node.to_global(point))


func _ensure_path_setup() -> void:
	if patrol_path == null:
		return
	patrol_path.top_level = true
	if patrol_path.curve == null:
		patrol_path.curve = Curve2D.new()


func _has_valid_path_points() -> bool:
	return patrol_path != null and patrol_path.curve != null and patrol_path.curve.get_point_count() >= 2


func _sync_patrol_points_from_path(force := false) -> void:
	if not _has_valid_path_points():
		return
	var path_points := _get_path_points_world()
	if path_points.size() < 2:
		return

	var signature := _build_path_signature(path_points)
	if not force and signature == _last_path_signature:
		return

	_is_syncing_from_path = true
	patrol_points = path_points
	_is_syncing_from_path = false
	_last_path_signature = signature


func _rebuild_path_from_patrol_points() -> void:
	_ensure_path_setup()
	if patrol_path == null or patrol_path.curve == null or patrol_points.is_empty():
		return

	patrol_path.curve.clear_points()
	for point in patrol_points:
		patrol_path.curve.add_point(patrol_path.to_local(point))
	_last_path_signature = _build_path_signature(patrol_points)


func _get_path_points_world() -> PackedVector2Array:
	var points := PackedVector2Array()
	if patrol_path == null or patrol_path.curve == null:
		return points

	for i in range(patrol_path.curve.get_point_count()):
		var local_point := patrol_path.curve.get_point_position(i)
		points.append(patrol_path.to_global(local_point))
	return points


func _build_path_signature(points: PackedVector2Array) -> String:
	var parts := PackedStringArray()
	for point in points:
		parts.append("%.2f,%.2f" % [point.x, point.y])
	return "|".join(parts)
