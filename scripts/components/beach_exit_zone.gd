@tool
extends Area2D
class_name BeachExitZone

@export var size := Vector2(900.0, 260.0):
	set(value):
		size = Vector2(maxf(value.x, 64.0), maxf(value.y, 64.0))
		_sync_geometry()
@export var water_color := Color("2f9fd8"):
	set(value):
		water_color = value
		queue_redraw()
@export var beach_color := Color("f2d389"):
	set(value):
		beach_color = value
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
	var rect := Rect2(-half_size, size)
	var beach_height := size.y * 0.42
	var beach_rect := Rect2(rect.position.x, rect.position.y, rect.size.x, beach_height)
	var water_rect := Rect2(rect.position.x, rect.position.y + beach_height, rect.size.x, rect.size.y - beach_height)

	draw_rect(water_rect, water_color, true)
	draw_rect(beach_rect, beach_color, true)
	draw_line(
		Vector2(rect.position.x, rect.position.y + beach_height),
		Vector2(rect.end.x, rect.position.y + beach_height),
		Color("fff4cf"),
		4.0
	)


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
