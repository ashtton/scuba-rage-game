@tool
extends Area2D
class_name SpikeStrip

enum ContactMode {
	DESTROY,
	JELLYFISH
}

@export var size := Vector2(260.0, 28.0):
	set(value):
		size = Vector2(maxf(value.x, 32.0), maxf(value.y, 16.0))
		_sync_geometry()
@export var fill_color := Color("ef6666"):
	set(value):
		fill_color = value
		queue_redraw()
@export var base_color := Color("7a2b33"):
	set(value):
		base_color = value
		queue_redraw()
@export var hazard_message := "Hull breach."
@export var contact_mode: ContactMode = ContactMode.DESTROY:
	set(value):
		contact_mode = value
		queue_redraw()
@export var jellyfish_bounce_speed := 980.0:
	set(value):
		jellyfish_bounce_speed = maxf(value, 60.0)
@export var jellyfish_stun_duration := 2.4:
	set(value):
		jellyfish_stun_duration = maxf(value, 0.0)
@export var jellyfish_battery_damage := 40.0:
	set(value):
		jellyfish_battery_damage = maxf(value, 0.0)
@export var tooth_spacing := 24.0:
	set(value):
		tooth_spacing = maxf(value, 8.0)
		queue_redraw()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
	_sync_geometry()


func _draw() -> void:
	var half_width := size.x * 0.5
	var half_height := size.y * 0.5
	var base_y := half_height * 0.25
	var tip_y := -half_height
	var tooth_color := fill_color
	var strip_color := base_color
	if contact_mode == ContactMode.JELLYFISH:
		tip_y = -half_height * 1.15
		tooth_color = Color("ff73cf")
		strip_color = Color("6e2f6f")

	var points := PackedVector2Array([
		Vector2(-half_width, half_height),
		Vector2(-half_width, base_y),
	])
	var tooth_count := maxi(4, int(ceil(size.x / tooth_spacing)))
	var step := size.x / float(tooth_count)

	for i in range(tooth_count):
		var start_x := -half_width + step * float(i)
		points.append(Vector2(start_x + step * 0.5, tip_y))
		points.append(Vector2(start_x + step, base_y))

	points.append(Vector2(half_width, half_height))
	draw_colored_polygon(points, tooth_color)
	draw_rect(Rect2(Vector2(-half_width, base_y), Vector2(size.x, half_height - base_y)), strip_color, true)

	if contact_mode == ContactMode.JELLYFISH:
		var jelly_count := maxi(3, int(ceil(size.x / 92.0)))
		for i in range(jelly_count):
			var ratio := (float(i) + 0.5) / float(jelly_count)
			var x := lerpf(-half_width, half_width, ratio)
			var center := Vector2(x, base_y - half_height * 0.72)
			draw_circle(center, half_height * 0.56, Color("ffb5ef"))
			draw_arc(center, half_height * 0.56, PI, TAU, 9, Color("ff5ec8"), 2.0)


func _on_body_entered(body: Node) -> void:
	if not (body is SubmarinePlayer):
		return

	var player := body as SubmarinePlayer
	if contact_mode == ContactMode.DESTROY:
		player.die(hazard_message)
		return

	var spike_normal := (-global_transform.y).normalized()
	var away_from_strip := (player.global_position - global_position).normalized()
	var bounce_direction := (spike_normal * 0.7 + away_from_strip * 0.3).normalized()
	if bounce_direction.length_squared() < 0.001:
		bounce_direction = spike_normal

	player.apply_hazard_bounce(bounce_direction, jellyfish_bounce_speed)
	player.stun_for(jellyfish_stun_duration)
	player.change_battery(-jellyfish_battery_damage)


func _sync_geometry() -> void:
	queue_redraw()
	if not is_node_ready():
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = size
