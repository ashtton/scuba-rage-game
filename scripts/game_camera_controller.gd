extends Node2D

@export_node_path("CharacterBody2D") var player_path: NodePath = ^"Level 1 Redone/World/Player"
@export_node_path("Node") var camera_zones_root_path: NodePath = ^"CameraZones"
@export var camera_left := -5755
@export var camera_top := -901
@export var camera_right := 12250
@export var camera_bottom := 5600
@export var camera_limit_transition_duration := 0.35

var _player: SubmarinePlayer = null
var _camera: Camera2D = null
var _camera_zones_root: Node = null
var _camera_zones: Array[CameraLimitZone] = []
var _active_camera_zone: CameraLimitZone = null
var _camera_limits_initialized := false
var _camera_limit_transition_elapsed := 0.0
var _camera_limits_start := Vector4.ZERO
var _camera_limits_current := Vector4.ZERO
var _camera_limits_target := Vector4.ZERO


func _ready() -> void:
	_player = get_node_or_null(player_path) as SubmarinePlayer
	if _player == null:
		push_warning("No SubmarinePlayer found at %s; game camera controller disabled." % player_path)
		set_process(false)
		return

	_camera_zones_root = get_node_or_null(camera_zones_root_path)
	if _camera_zones_root == null:
		push_warning("No camera zone root found at %s; game camera controller disabled." % camera_zones_root_path)
		set_process(false)
		return

	_configure_camera()
	_collect_camera_zones()
	_refresh_camera_limits_for_player(true)


func _process(delta: float) -> void:
	_refresh_camera_limits_for_player()
	_update_camera_limit_transition(delta)


func _configure_camera() -> void:
	var viewport_camera := get_viewport().get_camera_2d()

	var player_cameras := _player.find_children("*", "Camera2D", true, false)
	if not player_cameras.is_empty():
		for i in range(player_cameras.size() - 1, -1, -1):
			var preferred_camera := player_cameras[i] as Camera2D
			if preferred_camera == null:
				continue
			for camera_node in player_cameras:
				var player_camera := camera_node as Camera2D
				if player_camera != null:
					player_camera.enabled = player_camera == preferred_camera
			_camera = preferred_camera
			break

	if _camera == null and viewport_camera != null and _player.is_ancestor_of(viewport_camera):
		_camera = viewport_camera

	if _camera == null:
		_camera = _player.get_node_or_null("Camera2D") as Camera2D
		if _camera != null:
			_camera.enabled = true

	if _camera == null:
		push_warning("No Camera2D found for %s; game camera controller disabled." % _player.name)
		set_process(false)
		return

	_set_camera_limit_target(camera_left, camera_top, camera_right, camera_bottom, true)


func _collect_camera_zones() -> void:
	_camera_zones.clear()
	var zone_nodes := _camera_zones_root.find_children("*", "", true, false)
	for zone_node in zone_nodes:
		var zone := zone_node as CameraLimitZone
		if zone != null:
			_camera_zones.append(zone)


func _refresh_camera_limits_for_player(force_update: bool = false) -> void:
	if _camera == null or _player == null:
		return

	var next_zone := _find_best_camera_zone()
	if not force_update and next_zone == _active_camera_zone:
		return

	_active_camera_zone = next_zone
	if _active_camera_zone == null:
		_apply_camera_limits(camera_left, camera_top, camera_right, camera_bottom)
		return

	var limits := _active_camera_zone.get_resolved_limits()
	_apply_camera_limits(
		int(round(limits.x)),
		int(round(limits.y)),
		int(round(limits.z)),
		int(round(limits.w))
	)


func _find_best_camera_zone() -> CameraLimitZone:
	if _camera_zones.is_empty():
		return null

	var point := _player.global_position
	var best_zone: CameraLimitZone = null
	for zone in _camera_zones:
		if not is_instance_valid(zone):
			continue
		if not zone.contains_global_point(point):
			continue
		if best_zone == null:
			best_zone = zone
			continue
		if zone.camera_priority > best_zone.camera_priority:
			best_zone = zone
			continue
		if zone.camera_priority == best_zone.camera_priority and zone.get_area_score() < best_zone.get_area_score():
			best_zone = zone

	return best_zone


func _apply_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	if _camera == null:
		return
	_set_camera_limit_target(left, top, right, bottom)


func _set_camera_limit_target(
	left: int,
	top: int,
	right: int,
	bottom: int,
	immediate: bool = false
) -> void:
	if _camera == null:
		return

	var next_target := Vector4(float(left), float(top), float(right), float(bottom))
	if not _camera_limits_initialized or immediate:
		_camera_limits_initialized = true
		_camera_limits_start = next_target
		_camera_limits_current = next_target
		_camera_limits_target = next_target
		_camera_limit_transition_elapsed = camera_limit_transition_duration
		_apply_limits_to_camera(next_target)
		return

	if _camera_limits_target.is_equal_approx(next_target):
		return

	_camera_limits_start = _camera_limits_current
	_camera_limits_target = next_target
	_camera_limit_transition_elapsed = 0.0


func _update_camera_limit_transition(delta: float) -> void:
	if _camera == null or not _camera_limits_initialized:
		return
	if _camera_limits_current.is_equal_approx(_camera_limits_target):
		return

	var duration := maxf(camera_limit_transition_duration, 0.001)
	_camera_limit_transition_elapsed = minf(_camera_limit_transition_elapsed + delta, duration)
	var t := _camera_limit_transition_elapsed / duration
	var eased := t * t * (3.0 - 2.0 * t)

	_camera_limits_current = _camera_limits_start.lerp(_camera_limits_target, eased)
	_apply_limits_to_camera(_camera_limits_current)


func _apply_limits_to_camera(limits: Vector4) -> void:
	if _camera == null:
		return

	_camera.limit_left = int(round(limits.x))
	_camera.limit_top = int(round(limits.y))
	_camera.limit_right = int(round(limits.z))
	_camera.limit_bottom = int(round(limits.w))
