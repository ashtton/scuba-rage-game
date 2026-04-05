extends Node2D

@export_file("*.tscn") var next_scene_path := ""
@export var level_title := "Level 01"
@export var mechanic_name := "Vent Ladder"
@export_multiline var intro_message := "Hold left click to charge. Release to launch at the cursor."
@export var intro_duration := 4.0
@export var checkpoint_duration := 2.2
@export var camera_left := 0
@export var camera_top := -1200
@export var camera_right := 1920
@export var camera_bottom := 2400
@export var camera_limit_transition_duration := 0.35
@export var controller_enabled := true

const BATTERY_BAR_MAX_WIDTH := 296.0
const PIRANHA_GRAY_STRENGTH := 0.82
const CAMERA_CONTROLLER_SCRIPT := "res://scripts/game_camera_controller.gd"

var player: SubmarinePlayer = null
@onready var battery_bar_fill: ColorRect = $HUD/BatteryCard/Margin/VBox/BatteryBarTrack/BatteryBarClip/BatteryBarFill
@onready var battery_value: Label = $HUD/BatteryCard/Margin/VBox/BatteryAmount
@onready var battery_status: Label = $HUD/BatteryCard/Margin/VBox/BatteryStatus
@onready var cooldown_value: Label = $HUD/BatteryCard/Margin/VBox/CooldownValue
@onready var alert_panel: PanelContainer = $HUD/CenterAlert/AlertPanel
@onready var alert_title: Label = $HUD/CenterAlert/AlertPanel/Margin/VBox/AlertTitle
@onready var alert_body: Label = $HUD/CenterAlert/AlertPanel/Margin/VBox/AlertBody
@onready var flash_overlay: ColorRect = $HUD/FlashOverlay
@onready var gray_overlay: ColorRect = $HUD/GrayOverlay

var _alert_time_left := 0.0
var _battery_current := 0.0
var _battery_max := 1.0
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
var _manage_camera := true
var _alert_tween: Tween = null
var _flash_tween: Tween = null
var _gray_tween: Tween = null


func _ready() -> void:
	if not controller_enabled:
		if has_node("HUD"):
			get_node("HUD").visible = false
		set_process(false)
		return

	player = _find_player()
	if player == null:
		push_warning("No SubmarinePlayer found for %s; skipping level initialization." % name)
		set_process(false)
		return

	_manage_camera = not _has_external_camera_controller()
	player.set_spawn_point(player.global_position)
	if _manage_camera:
		_configure_camera()
		_collect_camera_zones()
		_refresh_camera_limits_for_player(true)

	_reset_hud_effects()
	player.battery_changed.connect(_on_player_battery_changed)
	player.cooldown_changed.connect(_on_player_cooldown_changed)
	player.died.connect(_on_player_died)
	player.stun_started.connect(_on_player_stun_started)

	for checkpoint in get_tree().get_nodes_in_group("level_checkpoint"):
		if checkpoint is Area2D and is_ancestor_of(checkpoint) and checkpoint.has_signal("reached"):
			checkpoint.connect("reached", _on_checkpoint_reached)

	_on_player_battery_changed(player.current_battery, player.max_battery)
	_on_player_cooldown_changed(0.0, player.boost_cooldown, false)
	_show_center_alert(
		mechanic_name if not mechanic_name.strip_edges().is_empty() else "Dive Brief",
		intro_message,
		intro_duration
	)


func _find_player() -> SubmarinePlayer:
	var local_player := get_node_or_null("World/Player") as SubmarinePlayer
	if local_player != null:
		return local_player

	var matches := get_tree().root.find_children("*", "SubmarinePlayer", true, false)
	if matches.is_empty():
		return null

	return matches[0] as SubmarinePlayer


func _process(delta: float) -> void:
	if _manage_camera:
		_refresh_camera_limits_for_player()
		_update_camera_limit_transition(delta)

	if _alert_time_left <= 0.0:
		return

	_alert_time_left = maxf(_alert_time_left - delta, 0.0)
	if is_zero_approx(_alert_time_left):
		_hide_center_alert()


func _on_player_battery_changed(current_battery: float, max_battery: float) -> void:
	_battery_current = current_battery
	_battery_max = max_battery
	battery_value.text = "%03d / %03d" % [int(round(current_battery)), int(round(max_battery))]
	_refresh_battery_ui()


func _on_player_cooldown_changed(current_cooldown: float, max_cooldown: float, is_stunned: bool) -> void:
	if is_stunned:
		var stun_seconds := snappedf(current_cooldown, 0.1)
		cooldown_value.text = "SYSTEMS JAMMED %.1fs" % maxf(stun_seconds, 0.1)
		cooldown_value.modulate = Color("ff9a90")
		return

	if current_cooldown <= 0.0:
		cooldown_value.text = "THRUSTERS READY"
		cooldown_value.modulate = Color("8ff4c2")
		return

	var seconds_left := snappedf(current_cooldown, 0.1)
	cooldown_value.text = "THRUSTERS CYCLING %.1fs" % minf(seconds_left, max_cooldown)
	cooldown_value.modulate = Color("ffd59e")


func _on_player_died(reason: String) -> void:
	if reason == "Battery depleted.":
		_show_center_alert("Battery Depleted", "Power flatlined. Rebooting from the start.", 1.5)
		return

	_show_center_alert("Hull Breach", reason, 1.4)


func _on_player_stun_started(source: String, duration: float, message: String) -> void:
	if source == "piranha":
		_play_piranha_stun_effect(duration)
		if not message.strip_edges().is_empty():
			_show_center_alert("Piranha Swarm", message, minf(maxf(duration * 0.45, 0.95), 1.6))


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

	var checkpoint_name := str(checkpoint.get("checkpoint_name"))
	_show_center_alert(checkpoint_name, "Spawn point updated.", checkpoint_duration)


func _show_center_alert(title: String, body: String, duration: float) -> void:
	alert_title.text = title.strip_edges()
	alert_body.text = body.strip_edges()
	alert_title.visible = not alert_title.text.is_empty()
	alert_body.visible = not alert_body.text.is_empty()
	alert_panel.visible = true
	alert_panel.modulate.a = 0.0
	alert_panel.scale = Vector2(0.92, 0.92)
	_alert_time_left = duration

	_kill_tween(_alert_tween)
	_alert_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_alert_tween.tween_property(alert_panel, "modulate:a", 1.0, 0.16)
	_alert_tween.parallel().tween_property(alert_panel, "scale", Vector2.ONE, 0.18)


func _hide_center_alert(immediate := false) -> void:
	_alert_time_left = 0.0
	_kill_tween(_alert_tween)
	if immediate:
		alert_panel.visible = false
		alert_panel.modulate.a = 0.0
		alert_panel.scale = Vector2.ONE
		return

	_alert_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_alert_tween.tween_property(alert_panel, "modulate:a", 0.0, 0.16)
	_alert_tween.parallel().tween_property(alert_panel, "scale", Vector2(0.98, 0.98), 0.16)
	_alert_tween.tween_callback(func() -> void:
		alert_panel.visible = false
	)


func _refresh_battery_ui() -> void:
	var display_ratio := clampf(_battery_current / maxf(_battery_max, 0.001), 0.0, 1.0)
	var fill_color := Color("6cf0c2")
	if display_ratio > 0.55:
		battery_status.text = "POWER STABLE"
		battery_status.modulate = Color("d4fff3")
		fill_color = Color("56e1b0")
	elif display_ratio > 0.25:
		battery_status.text = "POWER LOW"
		battery_status.modulate = Color("fff2b3")
		fill_color = Color("ffcf66")
	else:
		battery_status.text = "EMERGENCY POWER"
		battery_status.modulate = Color("ffd0cb")
		fill_color = Color("ff7368")

	battery_bar_fill.color = fill_color
	battery_bar_fill.size.x = BATTERY_BAR_MAX_WIDTH * display_ratio


func _reset_hud_effects() -> void:
	alert_panel.visible = false
	alert_panel.modulate.a = 0.0
	alert_panel.scale = Vector2.ONE
	flash_overlay.visible = false
	flash_overlay.modulate.a = 0.0
	_set_gray_strength(0.0)
	gray_overlay.visible = false


func _play_piranha_stun_effect(duration: float) -> void:
	_kill_tween(_flash_tween)
	_kill_tween(_gray_tween)

	flash_overlay.visible = true
	flash_overlay.modulate.a = 0.0
	gray_overlay.visible = true
	_set_gray_strength(0.0)

	_flash_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(flash_overlay, "modulate:a", 0.86, 0.07)
	_flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.26)
	_flash_tween.tween_callback(func() -> void:
		flash_overlay.visible = false
	)

	_gray_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_gray_tween.tween_method(Callable(self, "_set_gray_strength"), 0.0, PIRANHA_GRAY_STRENGTH, 0.12)
	_gray_tween.tween_interval(maxf(duration - 0.22, 0.12))
	_gray_tween.tween_method(Callable(self, "_set_gray_strength"), PIRANHA_GRAY_STRENGTH, 0.0, 0.34)
	_gray_tween.tween_callback(func() -> void:
		gray_overlay.visible = false
	)


func _set_gray_strength(strength: float) -> void:
	var shader_material := gray_overlay.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("strength", clampf(strength, 0.0, 1.0))
	gray_overlay.visible = strength > 0.001


func _kill_tween(tween: Tween) -> void:
	if tween != null:
		tween.kill()


func _has_external_camera_controller() -> bool:
	for node in get_tree().root.find_children("*", "", true, false):
		if node == self:
			continue
		var script := node.get_script() as Script
		if script != null and script.resource_path == CAMERA_CONTROLLER_SCRIPT:
			return true
	return false


func _configure_camera() -> void:
	var viewport_camera := get_viewport().get_camera_2d()
	if viewport_camera != null and (viewport_camera == player or player.is_ancestor_of(viewport_camera)):
		_camera = viewport_camera
	else:
		_camera = player.get_node_or_null("Camera2D") as Camera2D
		if _camera == null:
			var player_cameras := player.find_children("*", "Camera2D", true, false)
			var enabled_player_camera: Camera2D = null
			for candidate in player_cameras:
				var player_camera := candidate as Camera2D
				if player_camera != null and player_camera.enabled:
					enabled_player_camera = player_camera
			if enabled_player_camera != null:
				_camera = enabled_player_camera
			elif not player_cameras.is_empty():
				_camera = player_cameras[player_cameras.size() - 1] as Camera2D
		if _camera == null:
			_camera = viewport_camera
	if _camera == null:
		push_warning("No Camera2D found for %s; camera limits disabled." % name)
		return

	_apply_default_camera_limits(true)


func _collect_camera_zones() -> void:
	_camera_zones.clear()
	_camera_zones_with_player.clear()
	for zone in get_tree().get_nodes_in_group("camera_limit_zone"):
		# In combined scenes (e.g. game.tscn), camera zones can live outside this node's subtree.
		if zone is CameraLimitZone:
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
		_apply_default_camera_limits()
		return

	_apply_zone_camera_limits(_active_camera_zone)


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


func _apply_default_camera_limits(immediate: bool = false) -> void:
	var limits := _get_default_camera_limits()
	_set_camera_limit_target(
		int(round(limits.x)),
		int(round(limits.y)),
		int(round(limits.z)),
		int(round(limits.w)),
		immediate
	)


func _apply_zone_camera_limits(zone: CameraLimitZone) -> void:
	var limits := zone.get_resolved_limits()
	_apply_camera_limits(
		int(round(limits.x)),
		int(round(limits.y)),
		int(round(limits.z)),
		int(round(limits.w))
	)


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


func _get_default_camera_limits() -> Vector4:
	var scene_offset := _get_scene_root_global_offset()
	return Vector4(
		float(camera_left) + scene_offset.x,
		float(camera_top) + scene_offset.y,
		float(camera_right) + scene_offset.x,
		float(camera_bottom) + scene_offset.y
	)


func _get_scene_root_global_offset() -> Vector2:
	var scene_root := _find_scene_root()
	if scene_root is Node2D:
		return (scene_root as Node2D).global_position
	return Vector2.ZERO


func _find_scene_root() -> Node:
	var current: Node = self
	while current != null:
		if not current.scene_file_path.is_empty():
			return current
		current = current.get_parent()
	return self


func _on_camera_zone_entered(zone: CameraLimitZone) -> void:
	if _camera_zones_with_player.has(zone):
		return

	_camera_zones_with_player.append(zone)
	_refresh_camera_limits_for_player(true)


func _on_camera_zone_exited(zone: CameraLimitZone) -> void:
	_camera_zones_with_player.erase(zone)
	_refresh_camera_limits_for_player(true)
