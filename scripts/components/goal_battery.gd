@tool
extends Area2D
class_name GoalBattery

@export var size := Vector2(72.0, 72.0):
	set(value):
		size = Vector2(maxf(value.x, 32.0), maxf(value.y, 32.0))
		_sync_geometry()
@export var shell_color := Color("f6cf57"):
	set(value):
		shell_color = value
		queue_redraw()
@export var bolt_color := Color("f6fff3"):
	set(value):
		bolt_color = value
		queue_redraw()
@export_file("*.tscn") var next_scene_path := ""

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _triggered := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
	_sync_geometry()


func _draw() -> void:
	var half_size := size * 0.5
	var body_rect := Rect2(Vector2(-half_size.x * 0.62, -half_size.y * 0.4), Vector2(half_size.x * 1.24, half_size.y * 0.92))
	draw_rect(body_rect, shell_color, true)

	var top_points := PackedVector2Array([
		Vector2(-half_size.x * 0.62, -half_size.y * 0.4),
		Vector2(-half_size.x * 0.42, -half_size.y * 0.75),
		Vector2(half_size.x * 0.42, -half_size.y * 0.75),
		Vector2(half_size.x * 0.62, -half_size.y * 0.4),
	])
	var bottom_points := PackedVector2Array([
		Vector2(-half_size.x * 0.62, half_size.y * 0.52),
		Vector2(-half_size.x * 0.42, half_size.y * 0.84),
		Vector2(half_size.x * 0.42, half_size.y * 0.84),
		Vector2(half_size.x * 0.62, half_size.y * 0.52),
	])
	var bolt_points := PackedVector2Array([
		Vector2(-half_size.x * 0.12, -half_size.y * 0.2),
		Vector2(half_size.x * 0.2, -half_size.y * 0.2),
		Vector2(0.0, half_size.y * 0.02),
		Vector2(half_size.x * 0.18, half_size.y * 0.02),
		Vector2(-half_size.x * 0.22, half_size.y * 0.42),
		Vector2(-half_size.x * 0.02, half_size.y * 0.08),
		Vector2(-half_size.x * 0.2, half_size.y * 0.08),
	])
	draw_colored_polygon(top_points, shell_color)
	draw_colored_polygon(bottom_points, shell_color)
	draw_colored_polygon(bolt_points, bolt_color)
	draw_rect(body_rect, Color("fff5bf"), false, 3.0)


func _on_body_entered(body: Node) -> void:
	if _triggered or not (body is SubmarinePlayer):
		return

	_triggered = true
	if next_scene_path.is_empty():
		return
	if ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)


func _sync_geometry() -> void:
	queue_redraw()
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size
