extends CharacterBody2D
class_name SubmarinePlayer

signal battery_changed(current_battery: float, max_battery: float)
signal charge_changed(current_charge: float, max_charge: float)
signal cooldown_changed(current_cooldown: float, max_cooldown: float, is_stunned: bool)
signal died(reason: String)
signal stun_started(source: String, duration: float, message: String)

const MIN_LAUNCH_CHARGE_RATIO := 0.01
const DEFAULT_VISUAL_SCALE := Vector2.ONE
const LAUNCH_BUBBLE_SCRIPT := preload("res://scripts/effects/launch_bubble_burst.gd")

@export var min_launch_speed := 210.0
@export var max_launch_speed := 760.0
@export var max_charge_time := 1.0
@export var launch_curve_exponent := 2.35
@export var water_drag := 210.0
@export var bounce_restitution := 0.72
@export var bounce_min_speed := 80.0
@export var idle_drift := Vector2(0, 18)
@export var min_launch_cost := 8.0
@export var max_launch_cost := 34.0
@export var boost_cooldown := 1.5
@export var max_battery := 500.0
@export var stun_drift_drag_multiplier := 2.2
@export var implosion_duration := 0.5

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visuals: Node2D = $Visuals
@onready var aim_line: Line2D = $AimLine
@onready var arrow_head: Polygon2D = $ArrowHead
@onready var cooldown_meter: Node2D = $CooldownMeter
@onready var cooldown_fill: Polygon2D = $CooldownMeter/CooldownFill

var current_battery := 0.0
var spawn_point := Vector2.ZERO
var initial_spawn_point := Vector2.ZERO
var _respawning := false
var _charging := false
var _charge_time := 0.0
var _cooldown_time_left := 0.0
var _stun_time_left := 0.0
var _stun_duration_hint := 0.0
var _death_tween: Tween = null

const COOLDOWN_METER_WIDTH := 42.0
const COOLDOWN_METER_HEIGHT := 7.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	initial_spawn_point = global_position
	spawn_point = global_position
	current_battery = max_battery
	_emit_battery_changed()
	_emit_charge_changed()
	_emit_cooldown_changed()
	_update_aim_line()


func _unhandled_input(event: InputEvent) -> void:
	if _respawning or _is_stunned():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_charge()
		else:
			_release_charge()


func _physics_process(delta: float) -> void:
	if _respawning:
		return

	if _is_stunned() and _charging:
		_charging = false
		_charge_time = 0.0
		_emit_charge_changed()

	if _charging:
		_charge_time = minf(_charge_time + delta, max_charge_time)
		_emit_charge_changed()

	_cooldown_time_left = maxf(_cooldown_time_left - delta, 0.0)
	_stun_time_left = maxf(_stun_time_left - delta, 0.0)
	_emit_cooldown_changed()

	var incoming_velocity := velocity
	var drag_multiplier := stun_drift_drag_multiplier if _is_stunned() else 1.0
	velocity = velocity.move_toward(idle_drift, water_drag * drag_multiplier * delta)
	move_and_slide()
	_apply_collision_bounce(incoming_velocity)

	_update_visuals()
	_update_aim_line()


func refill_battery() -> bool:
	return _set_current_battery(max_battery)


func change_battery(amount: float) -> bool:
	if _respawning or is_zero_approx(amount):
		return false

	return _set_current_battery(current_battery + amount)


func set_spawn_point(new_spawn_point: Vector2) -> void:
	spawn_point = new_spawn_point


func die(reason: String, restart_from_beginning := false) -> void:
	if _respawning:
		return

	_respawning = true
	died.emit(reason)
	_cancel_active_state()
	_set_collision_enabled(false)
	await _play_implosion_animation()
	_respawn(restart_from_beginning)


func _start_charge() -> void:
	if current_battery < _get_min_launch_cost() or _cooldown_time_left > 0.0 or _is_stunned():
		return

	_charging = true
	_charge_time = 0.0
	_emit_charge_changed()
	_emit_cooldown_changed()


func _release_charge() -> void:
	if not _charging:
		return

	_charging = false

	var raw_charge_ratio := _get_charge_ratio()
	_charge_time = 0.0
	_emit_charge_changed()

	if raw_charge_ratio < MIN_LAUNCH_CHARGE_RATIO:
		return

	var desired_charge_ratio := _get_charge_progress(raw_charge_ratio)
	var charge_ratio := desired_charge_ratio
	var desired_curved_ratio := pow(desired_charge_ratio, launch_curve_exponent)
	var desired_battery_cost := _get_launch_cost_for_curved_ratio(desired_curved_ratio)
	if desired_battery_cost > current_battery:
		charge_ratio = _get_affordable_charge_progress()

	if charge_ratio <= 0.0:
		return

	var curved_charge_ratio := pow(charge_ratio, launch_curve_exponent)

	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT.rotated(visuals.rotation)
	direction = direction.normalized()

	var launch_speed := lerpf(min_launch_speed, max_launch_speed, curved_charge_ratio)
	var launch_cost := _get_launch_cost_for_curved_ratio(curved_charge_ratio)
	if not change_battery(-launch_cost):
		return
	velocity = direction * launch_speed
	_cooldown_time_left = boost_cooldown
	_spawn_launch_bubbles(direction, curved_charge_ratio)
	if _respawning:
		return
	_emit_cooldown_changed()


func _update_visuals() -> void:
	if _charging:
		var aim_vector := get_global_mouse_position() - global_position
		if aim_vector.length() > 1.0:
			visuals.rotation = aim_vector.angle()
		return

	var look_vector := velocity - idle_drift
	look_vector.y = minf(look_vector.y, 0.0)

	if look_vector.length() > 1.0:
		visuals.rotation = look_vector.angle()
	else:
		visuals.rotation = lerp_angle(visuals.rotation, 0.0, 0.14)


func _update_aim_line() -> void:
	var should_show := _charging and not _is_stunned() and not _respawning
	aim_line.visible = should_show
	arrow_head.visible = should_show
	if not should_show:
		return

	var local_mouse := to_local(get_global_mouse_position())
	if local_mouse.length_squared() < 0.001:
		local_mouse = Vector2.RIGHT

	var direction := local_mouse.normalized()
	var charge_ratio := _get_charge_progress(_get_charge_ratio())
	var curved_charge_ratio := pow(charge_ratio, launch_curve_exponent)
	var tail_length := lerpf(34.0, 120.0, curved_charge_ratio)
	var head_length := lerpf(12.0, 28.0, curved_charge_ratio)
	var head_width := lerpf(7.0, 18.0, curved_charge_ratio)
	var tip := direction * (tail_length + head_length)
	var body_end := direction * tail_length

	aim_line.points = PackedVector2Array([Vector2.ZERO, body_end])
	aim_line.width = lerpf(3.0, 7.0, curved_charge_ratio)

	var normal := direction.orthogonal()
	arrow_head.polygon = PackedVector2Array([
		tip,
		body_end + normal * head_width,
		body_end - normal * head_width,
	])
	arrow_head.position = Vector2.ZERO

	if charge_ratio > 0.75:
		aim_line.default_color = Color("ffb36b")
		arrow_head.color = Color("ffb36b")
	elif charge_ratio > 0.35:
		aim_line.default_color = Color("ffe082")
		arrow_head.color = Color("ffe082")
	else:
		aim_line.default_color = Color("6bd6ff")
		arrow_head.color = Color("6bd6ff")


func _apply_collision_bounce(incoming_velocity: Vector2) -> void:
	if get_slide_collision_count() == 0 or incoming_velocity.length() < bounce_min_speed:
		return

	var collision := get_slide_collision(get_slide_collision_count() - 1)
	if collision == null:
		return

	var collider := collision.get_collider()
	if collider != null and bool(collider.get("disable_submarine_bounce")):
		return

	var normal := collision.get_normal()
	if incoming_velocity.dot(normal) >= 0.0:
		return

	velocity = incoming_velocity.bounce(normal) * bounce_restitution


func _get_charge_ratio() -> float:
	return clampf(_charge_time / maxf(max_charge_time, 0.001), 0.0, 1.0)


func _get_charge_progress(raw_charge_ratio: float) -> float:
	return clampf(
		inverse_lerp(MIN_LAUNCH_CHARGE_RATIO, 1.0, raw_charge_ratio),
		0.0,
		1.0
	)


func _get_affordable_charge_progress() -> float:
	var min_cost := _get_min_launch_cost()
	var max_cost := _get_max_launch_cost(min_cost)
	var affordable_curved_ratio := clampf(
		inverse_lerp(min_cost, max_cost, current_battery),
		0.0,
		1.0
	)
	if affordable_curved_ratio <= 0.0:
		return 0.0
	return pow(affordable_curved_ratio, 1.0 / maxf(launch_curve_exponent, 0.001))


func _get_min_launch_cost() -> float:
	return maxf(min_launch_cost, 0.0)


func _get_max_launch_cost(min_cost: float) -> float:
	return maxf(max_launch_cost, min_cost)


func _get_launch_cost_for_curved_ratio(curved_ratio: float) -> float:
	var min_cost := _get_min_launch_cost()
	var max_cost := _get_max_launch_cost(min_cost)
	return lerpf(min_cost, max_cost, clampf(curved_ratio, 0.0, 1.0))


func _set_current_battery(next_battery: float) -> bool:
	var clamped_battery := clampf(next_battery, 0.0, max_battery)
	if is_equal_approx(clamped_battery, current_battery):
		return false

	current_battery = clamped_battery
	_emit_battery_changed()
	if current_battery <= 0.0 and not _respawning:
		die("Battery depleted.", true)
	return true


func _cancel_active_state() -> void:
	_charging = false
	_charge_time = 0.0
	_cooldown_time_left = 0.0
	_stun_time_left = 0.0
	_stun_duration_hint = 0.0
	_emit_charge_changed()
	_emit_cooldown_changed()
	_update_aim_line()


func _play_implosion_animation() -> Signal:
	if _death_tween != null:
		_death_tween.kill()

	visuals.scale = DEFAULT_VISUAL_SCALE
	visuals.modulate = Color.WHITE
	var start_rotation := visuals.rotation
	_death_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(visuals, "scale", Vector2(1.28, 0.42), implosion_duration * 0.32)
	_death_tween.parallel().tween_property(visuals, "rotation", start_rotation + 0.45, implosion_duration * 0.32)
	_death_tween.chain().tween_property(visuals, "scale", Vector2.ZERO, implosion_duration * 0.68)
	_death_tween.parallel().tween_property(visuals, "modulate:a", 0.0, implosion_duration * 0.68)
	_death_tween.parallel().tween_property(visuals, "rotation", start_rotation + TAU * 0.8, implosion_duration * 0.68)
	return _death_tween.finished


func _respawn(restart_from_beginning: bool) -> void:
	var respawn_target := initial_spawn_point if restart_from_beginning else spawn_point
	global_position = respawn_target
	velocity = Vector2.ZERO
	current_battery = max_battery
	visuals.scale = DEFAULT_VISUAL_SCALE
	visuals.modulate = Color.WHITE
	visuals.rotation = 0.0
	_charging = false
	_charge_time = 0.0
	_cooldown_time_left = 0.0
	_stun_time_left = 0.0
	_stun_duration_hint = 0.0
	_respawning = false
	_set_collision_enabled(true)
	_emit_battery_changed()
	_emit_charge_changed()
	_emit_cooldown_changed()
	_update_aim_line()


func _set_collision_enabled(is_enabled: bool) -> void:
	collision_shape.set_deferred("disabled", not is_enabled)


func _spawn_launch_bubbles(direction: Vector2, intensity: float) -> void:
	var bubble_burst := LAUNCH_BUBBLE_SCRIPT.new()
	var parent_node := get_parent()
	if parent_node == null:
		return

	parent_node.add_child(bubble_burst)
	var spawn_offset := direction.normalized() * -24.0
	bubble_burst.burst(global_position + spawn_offset, direction, intensity)


func _emit_battery_changed() -> void:
	battery_changed.emit(current_battery, max_battery)


func _emit_charge_changed() -> void:
	charge_changed.emit(_charge_time, max_charge_time)


func _emit_cooldown_changed() -> void:
	_update_cooldown_meter()
	var display_time := _stun_time_left if _is_stunned() else _cooldown_time_left
	var display_max := _stun_duration_hint if _is_stunned() else boost_cooldown
	cooldown_changed.emit(display_time, display_max, _is_stunned())


func _update_cooldown_meter() -> void:
	var display_time := _stun_time_left if _is_stunned() else _cooldown_time_left
	var display_max := _stun_duration_hint if _is_stunned() else boost_cooldown
	var cooldown_ratio := clampf(display_time / maxf(display_max, 0.001), 0.0, 1.0)
	cooldown_meter.visible = cooldown_ratio > 0.0 and not _respawning
	if not cooldown_meter.visible:
		return

	var fill_color := Color("ff7f66") if _is_stunned() else Color("ffb36b")
	cooldown_fill.color = fill_color

	var left_x := -COOLDOWN_METER_WIDTH * 0.5
	var right_x := left_x + COOLDOWN_METER_WIDTH * cooldown_ratio
	var half_height := COOLDOWN_METER_HEIGHT * 0.5
	cooldown_fill.polygon = PackedVector2Array([
		Vector2(left_x, -half_height),
		Vector2(right_x, -half_height),
		Vector2(right_x, half_height),
		Vector2(left_x, half_height),
	])


func stun_for(duration: float, source := "", message := "") -> void:
	if _respawning:
		return

	var clamped_duration := maxf(duration, 0.0)
	if clamped_duration <= 0.0:
		return

	_stun_time_left = maxf(_stun_time_left, clamped_duration)
	_stun_duration_hint = maxf(_stun_duration_hint, clamped_duration)
	if _charging:
		_charging = false
		_charge_time = 0.0
		_emit_charge_changed()
	stun_started.emit(source, clamped_duration, message)
	_emit_cooldown_changed()


func apply_hazard_bounce(direction: Vector2, speed: float) -> void:
	if _respawning:
		return

	var safe_direction := direction
	if safe_direction.length_squared() < 0.001:
		safe_direction = Vector2.UP
	safe_direction = safe_direction.normalized()
	velocity = safe_direction * maxf(speed, bounce_min_speed)


func _is_stunned() -> bool:
	return _stun_time_left > 0.0
