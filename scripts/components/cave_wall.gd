@tool
extends StaticBody2D
class_name CaveWall

@export var fill_color := Color("1a3b4d"):
	set(value):
		fill_color = value
		if is_instance_valid(_visual_fill):
			_visual_fill.color = fill_color
@export var border_color := Color("54bdd9"):
	set(value):
		border_color = value
		if is_instance_valid(_visual_border):
			_visual_border.default_color = border_color
@export var border_width := 5.0:
	set(value):
		border_width = maxf(value, 1.0)
		if is_instance_valid(_visual_border):
			_visual_border.width = border_width
@export var disable_submarine_bounce := false
@export var polygon_points := PackedVector2Array([
	Vector2(-120.0, -60.0),
	Vector2(120.0, -60.0),
	Vector2(120.0, 60.0),
	Vector2(-120.0, 60.0),
]):
	set(value):
		if value.size() < 3:
			return
		polygon_points = value
		_sync_geometry(false)

@onready var _collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var _visual_fill: Polygon2D = $VisualFill
@onready var _visual_border: Line2D = $VisualBorder

var _last_visual_polygon := PackedVector2Array()


func _ready() -> void:
	_sync_geometry(false)
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not is_instance_valid(_visual_fill):
		return

	if _visual_fill.polygon != _last_visual_polygon:
		polygon_points = _visual_fill.polygon
		_sync_geometry(true)


func _sync_geometry(from_visual: bool) -> void:
	if not is_node_ready() or polygon_points.size() < 3:
		return

	if not from_visual:
		_visual_fill.polygon = polygon_points

	_collision_polygon.polygon = polygon_points
	_visual_fill.color = fill_color

	_visual_border.points = PackedVector2Array(polygon_points)
	_visual_border.default_color = border_color
	_visual_border.width = border_width
	_last_visual_polygon = PackedVector2Array(_visual_fill.polygon)
