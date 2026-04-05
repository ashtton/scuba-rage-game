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
		_sync_visuals()
@export var speed_scale := 1.0:
	set(value):
		speed_scale = maxf(value, 0.0)
		_sync_visuals()
@export var fill_color := Color(0.172549, 0.772549, 0.87451, 0.2):
	set(value):
		fill_color = value
		_sync_visuals()
@export var edge_color := Color("89ebff"):
	set(value):
		edge_color = value
		_sync_visuals()
@export var visual_density := 1.0:
	set(value):
		visual_density = clampf(value, 0.2, 2.0)
		_rebuild_visual_particles()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _rng := RandomNumberGenerator.new()
var _visual_particles: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = int(get_instance_id())
	_sync_geometry()
	_rebuild_visual_particles()
	set_process(true)


func _process(delta: float) -> void:
	_advance_visual_particles(delta)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var effective_flow := flow_vector * speed_scale
	for body in get_overlapping_bodies():
		if body is SubmarinePlayer:
			(body as SubmarinePlayer).velocity += effective_flow * delta


func _draw() -> void:
	var direction := flow_vector.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT

	for particle in _visual_particles:
		var progress := particle["progress"] as float
		var lane := particle["lane"] as float
		var radius := particle["radius"] as float
		var alpha := particle["alpha"] as float
		var pos := _particle_position(progress, lane, direction)
		var tint := edge_color.lerp(fill_color, 0.25)
		tint.a = clampf(alpha * 0.8, 0.0, 1.0)

		draw_circle(pos, radius, tint)
		var tail := pos - direction * (radius * 4.2)
		draw_line(tail, pos, tint, maxf(radius * 0.9, 1.0), true)


func _sync_geometry() -> void:
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size
	_rebuild_visual_particles()
	queue_redraw()


func _sync_visuals() -> void:
	if not is_node_ready():
		return

	queue_redraw()


func _rebuild_visual_particles() -> void:
	if not is_node_ready():
		return

	_visual_particles.clear()
	var area := size.x * size.y
	var target_count := int(round(area / 32000.0 * 22.0 * visual_density))
	target_count = clampi(target_count, 10, 46)

	for _i in range(target_count):
		_visual_particles.append({
			"progress": _rng.randf(),
			"lane": _rng.randf(),
			"speed": lerpf(0.55, 1.35, _rng.randf()),
			"radius": lerpf(1.1, 2.4, _rng.randf()),
			"alpha": lerpf(0.35, 0.85, _rng.randf())
		})


func _advance_visual_particles(delta: float) -> void:
	if _visual_particles.is_empty():
		return

	var direction := flow_vector.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT

	var horizontal_flow := absf(direction.x) >= absf(direction.y)
	var flow_span := size.x if horizontal_flow else size.y
	var speed := maxf(flow_vector.length() * speed_scale, 120.0)
	var normalized_step := speed * delta / maxf(flow_span, 1.0)

	for particle in _visual_particles:
		var signed_step := normalized_step * (particle["speed"] as float)
		if horizontal_flow:
			signed_step *= 1.0 if direction.x >= 0.0 else -1.0
		else:
			signed_step *= 1.0 if direction.y >= 0.0 else -1.0

		particle["progress"] = wrapf((particle["progress"] as float) + signed_step, 0.0, 1.0)


func _particle_position(progress: float, lane: float, direction: Vector2) -> Vector2:
	var half := size * 0.5
	var margin := 8.0
	var horizontal_flow := absf(direction.x) >= absf(direction.y)

	if horizontal_flow:
		var x := lerpf(-half.x + margin, half.x - margin, progress)
		var y := lerpf(-half.y + margin, half.y - margin, lane)
		return Vector2(x, y)

	var px := lerpf(-half.x + margin, half.x - margin, lane)
	var py := lerpf(-half.y + margin, half.y - margin, progress)
	return Vector2(px, py)
