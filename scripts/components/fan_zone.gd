@tool
extends SlipStreamZone
class_name FanZone

enum FlowMode {
	BLOW,
	SUCK,
}

enum PivotOrigin {
	CENTER,
	LEFT_EDGE,
	RIGHT_EDGE,
	TOP_EDGE,
	BOTTOM_EDGE,
}

@export var flow_mode: FlowMode = FlowMode.BLOW:
	set(value):
		flow_mode = value
		_sync_visuals()
@export var edge_aligned_flow := true:
	set(value):
		edge_aligned_flow = value
		_sync_visuals()
@export var pivot_origin: PivotOrigin = PivotOrigin.CENTER:
	set(value):
		pivot_origin = value
		_apply_pivot_origin()
		_sync_visuals()

@export_group("Pivot Rotation")
@export var pivot_enabled := true:
	set(value):
		pivot_enabled = value
		if not _has_initialized_base:
			return
		if not pivot_enabled:
			rotation = _pivot_base_rotation
		else:
			_update_pivot_rotation()
@export var pivot_sweep_degrees := 45.0:
	set(value):
		pivot_sweep_degrees = maxf(value, 0.0)
		if _has_initialized_base:
			_update_pivot_rotation()
@export var pivot_cycles_per_second := 0.0:
	set(value):
		pivot_cycles_per_second = maxf(value, 0.0)

@export_group("Movement")
@export var movement_enabled := false:
	set(value):
		movement_enabled = value
		if not _has_initialized_base:
			return
		if not movement_enabled:
			position = _movement_base_position
		else:
			_reset_movement_phase()
			_update_movement_offset()
@export var movement_offset := Vector2(140.0, 0.0):
	set(value):
		movement_offset = value
		if _has_initialized_base:
			_update_movement_offset()
@export var movement_cycles_per_second := 0.3:
	set(value):
		movement_cycles_per_second = maxf(value, 0.0)
@export_range(0.0, 1.0, 0.01) var movement_start_phase := 0.0:
	set(value):
		movement_start_phase = clampf(value, 0.0, 1.0)
		if _has_initialized_base and not randomize_movement_start:
			_set_movement_phase_from_start()
			_update_movement_offset()
@export var randomize_movement_start := false:
	set(value):
		randomize_movement_start = value
		if _has_initialized_base:
			_reset_movement_phase()
@export var randomize_movement_each_cycle := false
@export var show_movement_path := true:
	set(value):
		show_movement_path = value
		queue_redraw()
@export var movement_path_color := Color(0.760784, 0.92549, 1.0, 0.75):
	set(value):
		movement_path_color = value
		queue_redraw()
@export var movement_path_width := 3.0:
	set(value):
		movement_path_width = maxf(value, 1.0)
		queue_redraw()
@export var movement_endpoint_radius := 6.0:
	set(value):
		movement_endpoint_radius = maxf(value, 2.0)
		queue_redraw()

@export_group("Prototype Visual")
@export var show_prototype := true:
	set(value):
		show_prototype = value
		queue_redraw()
@export var blade_count := 4:
	set(value):
		blade_count = clampi(value, 3, 8)
		queue_redraw()
@export var blade_length := 46.0:
	set(value):
		blade_length = maxf(value, 18.0)
		queue_redraw()
@export var blade_width := 14.0:
	set(value):
		blade_width = maxf(value, 6.0)
		queue_redraw()
@export var hub_radius := 11.0:
	set(value):
		hub_radius = maxf(value, 6.0)
		queue_redraw()
@export var housing_color := Color(0.152941, 0.227451, 0.270588, 0.85):
	set(value):
		housing_color = value
		queue_redraw()
@export var blade_color := Color(0.572549, 0.827451, 0.905882, 0.92):
	set(value):
		blade_color = value
		queue_redraw()
@export var hub_color := Color(0.960784, 0.980392, 1.0, 0.95):
	set(value):
		hub_color = value
		queue_redraw()

var _pivot_base_rotation := 0.0
var _movement_base_position := Vector2.ZERO
var _pivot_time := 0.0
var _movement_phase := 0.0
var _has_initialized_base := false
var _movement_rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_apply_pivot_origin()
	_pivot_base_rotation = rotation
	_movement_base_position = position
	_movement_rng.seed = int(get_instance_id()) * 97 + 11
	_has_initialized_base = true
	_reset_movement_phase()
	_update_pivot_rotation()
	_update_movement_offset()


func _process(delta: float) -> void:
	_update_motion(delta)
	super._process(delta)


func _draw() -> void:
	super._draw()
	_draw_movement_path()
	if not show_prototype:
		return

	var housing_radius := maxf(blade_length + 12.0, hub_radius + 16.0)
	draw_circle(Vector2.ZERO, housing_radius, housing_color)
	draw_arc(Vector2.ZERO, housing_radius, 0.0, TAU, 32, edge_color, 3.0, true)

	for i in range(blade_count):
		var angle := TAU * float(i) / float(blade_count)
		var direction := Vector2.RIGHT.rotated(angle)
		var normal := direction.orthogonal()
		var root := direction * (hub_radius + 2.0)
		var tip := direction * blade_length
		var blade := PackedVector2Array([
			root - normal * blade_width * 0.5,
			tip,
			root + normal * blade_width * 0.5,
		])
		draw_colored_polygon(blade, blade_color)

	draw_circle(Vector2.ZERO, hub_radius, hub_color)
	draw_circle(Vector2.ZERO, hub_radius * 0.45, Color(0.117647, 0.168627, 0.211765, 0.95))


func _get_effective_flow_vector() -> Vector2:
	if edge_aligned_flow and pivot_origin != PivotOrigin.CENTER:
		var local_direction := _get_local_edge_flow_direction()
		if flow_mode == FlowMode.SUCK:
			local_direction *= -1.0
		var flow_magnitude := maxf(flow_vector.length(), 1.0)
		return local_direction.rotated(global_rotation) * flow_magnitude

	var local_flow := flow_vector if flow_mode == FlowMode.BLOW else -flow_vector
	return local_flow.rotated(global_rotation)


func _sync_geometry() -> void:
	super._sync_geometry()
	_apply_pivot_origin()


func _particle_position(progress: float, lane: float, direction: Vector2) -> Vector2:
	return super._particle_position(progress, lane, direction) + _get_zone_center_offset()


func _update_motion(delta: float) -> void:
	if Engine.is_editor_hint():
		_pivot_base_rotation = rotation
		_movement_base_position = position
		return

	if pivot_enabled and pivot_cycles_per_second > 0.0 and pivot_sweep_degrees > 0.0:
		_pivot_time += delta
		_update_pivot_rotation()
	elif not pivot_enabled:
		rotation = _pivot_base_rotation

	if movement_enabled and movement_cycles_per_second > 0.0 and movement_offset.length_squared() > 0.001:
		_movement_phase += delta * TAU * movement_cycles_per_second
		if randomize_movement_each_cycle:
			while _movement_phase >= TAU:
				_movement_phase = _movement_rng.randf() * TAU
		else:
			_movement_phase = wrapf(_movement_phase, 0.0, TAU)
		_update_movement_offset()
	elif not movement_enabled:
		position = _movement_base_position


func _update_pivot_rotation() -> void:
	if not _has_initialized_base:
		return

	var sweep_radians := deg_to_rad(pivot_sweep_degrees)
	var phase := _pivot_time * TAU * pivot_cycles_per_second
	rotation = _pivot_base_rotation + sin(phase) * sweep_radians


func _update_movement_offset() -> void:
	if not _has_initialized_base:
		return

	position = _movement_base_position + movement_offset * sin(_movement_phase)


func _apply_pivot_origin() -> void:
	if not is_node_ready():
		return

	collision_shape.position = _get_zone_center_offset()
	queue_redraw()


func _get_zone_center_offset() -> Vector2:
	var half := size * 0.5
	match pivot_origin:
		PivotOrigin.LEFT_EDGE:
			return Vector2(half.x, 0.0)
		PivotOrigin.RIGHT_EDGE:
			return Vector2(-half.x, 0.0)
		PivotOrigin.TOP_EDGE:
			return Vector2(0.0, half.y)
		PivotOrigin.BOTTOM_EDGE:
			return Vector2(0.0, -half.y)
		_:
			return Vector2.ZERO


func _get_local_edge_flow_direction() -> Vector2:
	match pivot_origin:
		PivotOrigin.LEFT_EDGE:
			return Vector2.RIGHT
		PivotOrigin.RIGHT_EDGE:
			return Vector2.LEFT
		PivotOrigin.TOP_EDGE:
			return Vector2.DOWN
		PivotOrigin.BOTTOM_EDGE:
			return Vector2.UP
		_:
			return flow_vector.normalized() if flow_vector.length_squared() > 0.001 else Vector2.RIGHT


func _draw_movement_path() -> void:
	if not show_movement_path or not movement_enabled:
		return
	if movement_offset.length_squared() <= 0.001:
		return

	var base_local_world := Vector2.ZERO
	if not Engine.is_editor_hint():
		base_local_world = _movement_base_position - position

	var inv_rotation := -rotation
	var base_local := base_local_world.rotated(inv_rotation)
	var offset_local := movement_offset.rotated(inv_rotation)
	var start := base_local - offset_local
	var finish := base_local + offset_local

	draw_line(start, finish, movement_path_color, movement_path_width, true)
	draw_circle(start, movement_endpoint_radius, movement_path_color)
	draw_circle(finish, movement_endpoint_radius, movement_path_color)

	var marker_color := Color(1.0, 1.0, 1.0, 0.9)
	draw_circle(base_local, movement_endpoint_radius * 0.55, marker_color)


func _reset_movement_phase() -> void:
	if randomize_movement_start:
		_movement_phase = _movement_rng.randf() * TAU
	else:
		_set_movement_phase_from_start()


func _set_movement_phase_from_start() -> void:
	_movement_phase = movement_start_phase * TAU
