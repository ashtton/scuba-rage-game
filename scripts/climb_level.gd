extends Node2D

@export_file("*.tscn") var next_scene_path := ""
@export var level_title := "Level 01"
@export var mechanic_name := "Vent Ladder"
@export_multiline var intro_message := "Hold left click to charge. Release to launch at the cursor."
@export var intro_duration := 4.0
@export var checkpoint_duration := 2.2
@export var death_depth := 2400.0
@export var camera_left := 0
@export var camera_top := -1200
@export var camera_right := 1920
@export var camera_bottom := 2400
@export var camera_limit_transition_duration := 0.35

const BATTERY_FILL_MAX_HEIGHT := 104.0

@onready var player: SubmarinePlayer = $World/Player
@onready var battery_fill: ColorRect = $HUD/BatteryHUD/BatteryShell/BatteryClip/BatteryFill
@onready var battery_value: Label = $HUD/BatteryHUD/BatteryValue
@onready var battery_status: Label = $HUD/BatteryHUD/BatteryStatus
@onready var cooldown_value: Label = $HUD/BatteryHUD/CooldownValue
@onready var message_label: Label = $HUD/MessagePlate/MessageLabel
@onready var level_value: Label = $HUD/LevelPlate/LevelValue
@onready var mechanic_value: Label = $HUD/LevelPlate/MechanicValue

var _message_time_left := 0.0
var _battery_current := 0.0
var _battery_max := 1.0
var _transitioning := false
var _active_checkpoint = null
var _camera: Camera2D = null
var _camera_zones: Array[CameraLimitZone] = []
var _camera_zones_with_player: Array[CameraLimitZone] = []
var _active_camera_zone: CameraLimitZone = null
var _camera_limits_initialized := false
var _camera_limit_transition_elapsed := 0.0
var _camera_limits_start := Vector4.ZERO
var _camera_limits_current := Vector4.ZERO
var _camera_limits_target := Vector4.ZERO


func _ready() -> void:
	player.set_spawn_point(player.global_position)
	player.death_depth = death_depth
	_configure_camera()
	_collect_camera_zones()
	_refresh_camera_limits_for_player(true)

	level_value.text = level_title
	mechanic_value.text = mechanic_name

	player.battery_changed.connect(_on_player_battery_changed)
	player.cooldown_changed.connect(_on_player_cooldown_changed)
	player.died.connect(_on_player_died)

	for checkpoint in get_tree().get_nodes_in_group("level_checkpoint"):
		if checkpoint is Area2D and is_ancestor_of(checkpoint) and checkpoint.has_signal("reached"):
			checkpoint.connect("reached", _on_checkpoint_reached)

	_on_player_battery_changed(player.current_battery, player.max_battery)
	_on_player_cooldown_changed(0.0, player.boost_cooldown, false)
	_show_message(intro_message, intro_duration)


func _process(delta: float) -> void:
	_refresh_camera_limits_for_player()
	_update_camera_limit_transition(delta)

	if _message_time_left <= 0.0:
		return

	_message_time_left = maxf(_message_time_left - delta, 0.0)
	if _message_time_left == 0.0:
		message_label.text = ""


func _on_player_battery_changed(current_battery: float, max_battery: float) -> void:
	_battery_current = current_battery
	_battery_max = max_battery
	battery_value.text = "%04d" % int(round(current_battery))
	_refresh_battery_ui()


func _on_player_cooldown_changed(current_cooldown: float, max_cooldown: float, is_stunned: bool) -> void:
	if is_stunned:
		var stun_seconds := snappedf(current_cooldown, 0.1)
		cooldown_value.text = "STUNNED %.1fs" % maxf(stun_seconds, 0.1)
		cooldown_value.modulate = Color("ff8f88")
		return

	if current_cooldown <= 0.0:
		cooldown_value.text = "READY"
		cooldown_value.modulate = Color("98f5c3")
		return

	var seconds_left := snappedf(current_cooldown, 0.1)
	cooldown_value.text = "COOLDOWN %.1fs" % minf(seconds_left, max_cooldown)
	cooldown_value.modulate = Color("ffd59e")


func _on_player_died(reason: String) -> void:
	_show_message(reason, 1.8)


func _on_checkpoint_reached(checkpoint: Node) -> void:
	if checkpoint == _active_checkpoint:
		return

	if _active_checkpoint != null and _active_checkpoint.has_method("set_active"):
		_active_checkpoint.set_active(false)

	_active_checkpoint = checkpoint
	if _active_checkpoint.has_method("set_active"):
		_active_checkpoint.set_active(true)
	if checkpoint.has_method("get_spawn_point"):
		player.set_spawn_point(checkpoint.get_spawn_point())
	player.refill_battery()
	var checkpoint_name := str(checkpoint.get("checkpoint_name"))
	_show_message("%s stabilized. Battery restored." % checkpoint_name, checkpoint_duration)


func _show_message(text: String, duration: float) -> void:
	message_label.text = text
	_message_time_left = duration


func _refresh_battery_ui() -> void:
	var display_ratio := clampf(_battery_current / maxf(_battery_max, 0.001), 0.0, 1.0)
	if display_ratio > 0.55:
		battery_fill.color = Color("78f08a")
	elif display_ratio > 0.25:
		battery_fill.color = Color("ffd166")
	else:
		battery_fill.color = Color("ff6b6b")

	var fill_height := BATTERY_FILL_MAX_HEIGHT * display_ratio
	battery_fill.size.y = fill_height
	battery_fill.position.y = BATTERY_FILL_MAX_HEIGHT - fill_height

	if display_ratio > 0.55:
		battery_status.text = "HEALTHY"
		battery_status.modulate = Color("ddffe2")
	elif display_ratio > 0.25:
		battery_status.text = "LOW"
		battery_status.modulate = Color("fff0b0")
	else:
		battery_status.text = "CRITICAL"
		battery_status.modulate = Color("ffd1d1")


func _configure_camera() -> void:
	_camera = player.get_node("Camera2D") as Camera2D
	if _camera == null:
		return

	_set_camera_limit_target(camera_left, camera_top, camera_right, camera_bottom, true)


func _collect_camera_zones() -> void:
	_camera_zones.clear()
	_camera_zones_with_player.clear()
	for zone in get_tree().get_nodes_in_group("camera_limit_zone"):
		if zone is CameraLimitZone and is_ancestor_of(zone):
			_camera_zones.append(zone)
			if not zone.player_entered_zone.is_connected(_on_camera_zone_entered):
				zone.player_entered_zone.connect(_on_camera_zone_entered)
			if not zone.player_exited_zone.is_connected(_on_camera_zone_exited):
				zone.player_exited_zone.connect(_on_camera_zone_exited)


func _refresh_camera_limits_for_player(force_update: bool = false) -> void:
	if _camera == null:
		return

	var next_zone := _find_best_camera_zone()
	if not force_update and next_zone == _active_camera_zone:
		return

	_active_camera_zone = next_zone
	if _active_camera_zone == null:
		if not _camera_zones.is_empty():
			return
		_apply_camera_limits(camera_left, camera_top, camera_right, camera_bottom)
		return

	_apply_camera_limits(
		_active_camera_zone.limit_left,
		_active_camera_zone.limit_top,
		_active_camera_zone.limit_right,
		_active_camera_zone.limit_bottom
	)


func _find_best_camera_zone() -> CameraLimitZone:
	if _camera_zones.is_empty():
		return null

	var use_point_contains := _camera_zones_with_player.is_empty()
	var candidate_zones := _camera_zones_with_player if not use_point_contains else _camera_zones
	var point := player.global_position
	var best_zone: CameraLimitZone = null
	for zone in candidate_zones:
		if not is_instance_valid(zone):
			continue
		if use_point_contains and not zone.contains_global_point(point):
			continue

		if best_zone == null:
			best_zone = zone
			continue

		if zone.camera_priority > best_zone.camera_priority:
			best_zone = zone
			continue

		if zone.camera_priority == best_zone.camera_priority and zone.get_area_score() < best_zone.get_area_score():
			best_zone = zone

	if best_zone == null and _active_camera_zone != null and is_instance_valid(_active_camera_zone):
		return _active_camera_zone
	if best_zone == null:
		return _find_nearest_camera_zone(point)

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


func _find_nearest_camera_zone(point: Vector2) -> CameraLimitZone:
	var nearest: CameraLimitZone = null
	var nearest_distance_sq := INF
	for zone in _camera_zones:
		if not is_instance_valid(zone):
			continue

		var distance_sq := point.distance_squared_to(zone.global_position)
		if nearest == null or distance_sq < nearest_distance_sq:
			nearest = zone
			nearest_distance_sq = distance_sq

	return nearest


func _on_camera_zone_entered(zone: CameraLimitZone) -> void:
	if _camera_zones_with_player.has(zone):
		return

	_camera_zones_with_player.append(zone)
	_refresh_camera_limits_for_player(true)


func _on_camera_zone_exited(zone: CameraLimitZone) -> void:
	_camera_zones_with_player.erase(zone)
	_refresh_camera_limits_for_player(true)
