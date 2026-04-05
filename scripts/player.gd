extends CharacterBody2D
class_name SubmarinePlayer

signal battery_changed(current_battery: float, max_battery: float)
signal charge_changed(current_charge: float, max_charge: float)
signal cooldown_changed(current_cooldown: float, max_cooldown: float, is_stunned: bool)
signal died(reason: String)

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
@export var max_battery := 1000.0
@export var stun_drift_drag_multiplier := 2.2

const MIN_LAUNCH_CHARGE_RATIO := 0.01
const DEPLETED_BATTERY_RATIO := 0.01

@onready var visuals: Node2D = $Visuals
@onready var aim_line: Line2D = $AimLine
@onready var arrow_head: Polygon2D = $ArrowHead
@onready var cooldown_meter: Node2D = $CooldownMeter
@onready var cooldown_fill: Polygon2D = $CooldownMeter/CooldownFill

var current_battery := 0.0
var spawn_point := Vector2.ZERO
var _respawning := false
var _charging := false
var _charge_time := 0.0
var _cooldown_time_left := 0.0
var _powerless_time := 0.0
var _stun_time_left := 0.0
var _stun_duration_hint := 0.0

const COOLDOWN_METER_WIDTH := 42.0
const COOLDOWN_METER_HEIGHT := 7.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	_check_powerless_state(delta)


func refill_battery() -> void:
	current_battery = max_battery
	_powerless_time = 0.0
	_stun_time_left = 0.0
	_stun_duration_hint = 0.0
	_emit_battery_changed()
	_emit_cooldown_changed()


func change_battery(amount: float) -> void:
	var new_battery := clampf(current_battery + amount, 0.0, max_battery)
	if is_equal_approx(new_battery, current_battery):
		return

	current_battery = new_battery
	if amount > 0.0:
		_powerless_time = 0.0
	_emit_battery_changed()


func set_spawn_point(new_spawn_point: Vector2) -> void:
	spawn_point = new_spawn_point


func die(reason: String) -> void:
	if _respawning:
		return

	_respawning = true
	died.emit(reason)
	global_position = spawn_point
	velocity = Vector2.ZERO
	_charging = false
	_charge_time = 0.0
	_cooldown_time_left = 0.0
	_stun_time_left = 0.0
	_stun_duration_hint = 0.0
	_powerless_time = 0.0
	refill_battery()
	_emit_charge_changed()
	_emit_cooldown_changed()
	call_deferred("_finish_respawn")


func _finish_respawn() -> void:
	_respawning = false
	_update_aim_line()


func _start_charge() -> void:
	if current_battery < min_launch_cost or _cooldown_time_left > 0.0 or _is_stunned():
		return

	_charging = true
	_charge_time = 0.0
	_powerless_time = 0.0
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
	var desired_battery_cost := lerpf(min_launch_cost, max_launch_cost, desired_curved_ratio)
	if desired_battery_cost > current_battery:
		charge_ratio = _get_affordable_charge_progress()

	var curved_charge_ratio := pow(charge_ratio, launch_curve_exponent)

	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT.rotated(visuals.rotation)
	direction = direction.normalized()

	var launch_speed := lerpf(min_launch_speed, max_launch_speed, curved_charge_ratio)
	velocity = direction * launch_speed

	var battery_cost := lerpf(min_launch_cost, max_launch_cost, curved_charge_ratio)
	current_battery = maxf(current_battery - battery_cost, 0.0)
	_cooldown_time_left = boost_cooldown
	_emit_battery_changed()
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
	var should_show := _charging and not _is_stunned()
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


func _check_powerless_state(delta: float) -> void:
	if current_battery > max_battery * DEPLETED_BATTERY_RATIO or _charging or velocity.length() > 24.0:
		_powerless_time = 0.0
		return

	_powerless_time += delta
	if _powerless_time >= 0.75:
		die("Battery depleted.")


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
	var usable_battery := current_battery - max_battery * DEPLETED_BATTERY_RATIO
	if usable_battery <= 0.0:
		return 0.0

	return clampf(
		usable_battery / maxf(max_battery * (1.0 - DEPLETED_BATTERY_RATIO), 0.001),
		0.0,
		1.0
	)


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
	cooldown_meter.visible = cooldown_ratio > 0.0
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


func stun_for(duration: float) -> void:
	var clamped_duration := maxf(duration, 0.0)
	if clamped_duration <= 0.0:
		return

	_stun_time_left = maxf(_stun_time_left, clamped_duration)
	_stun_duration_hint = maxf(_stun_duration_hint, clamped_duration)
	if _charging:
		_charging = false
		_charge_time = 0.0
		_emit_charge_changed()
	_emit_cooldown_changed()


func apply_hazard_bounce(direction: Vector2, speed: float) -> void:
	var safe_direction := direction
	if safe_direction.length_squared() < 0.001:
		safe_direction = Vector2.UP
	safe_direction = safe_direction.normalized()
	velocity = safe_direction * maxf(speed, bounce_min_speed)


func _is_stunned() -> bool:
	return _stun_time_left > 0.0
