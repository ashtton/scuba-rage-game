extends Node2D

class BubbleParticle:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var radius := 6.0
	var growth := 0.0
	var age := 0.0
	var lifetime := 0.8
	var wobble := 0.0


const MIN_BUBBLES := 7
const MAX_BUBBLES := 13

var _bubbles: Array[BubbleParticle] = []


func _ready() -> void:
	top_level = true
	z_as_relative = false
	queue_redraw()


func burst(origin: Vector2, launch_direction: Vector2, intensity: float) -> void:
	global_position = origin
	_bubbles.clear()

	var safe_direction := launch_direction
	if safe_direction.length_squared() < 0.001:
		safe_direction = Vector2.RIGHT
	safe_direction = safe_direction.normalized()

	var reverse_direction := -safe_direction
	var clamped_intensity := clampf(intensity, 0.0, 1.0)
	var bubble_count := int(round(lerpf(float(MIN_BUBBLES), float(MAX_BUBBLES), clamped_intensity)))
	for _i in range(bubble_count):
		var bubble := BubbleParticle.new()
		var travel_direction := reverse_direction.rotated(randf_range(-0.95, 0.95)).normalized()
		bubble.position = travel_direction * randf_range(2.0, 14.0)
		bubble.velocity = travel_direction * randf_range(80.0, 210.0) + Vector2(0.0, -randf_range(12.0, 34.0))
		bubble.radius = randf_range(4.0, 8.5)
		bubble.growth = randf_range(0.35, 0.8)
		bubble.lifetime = randf_range(0.42, 0.86)
		bubble.wobble = randf_range(0.0, TAU)
		_bubbles.append(bubble)

	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _bubbles.is_empty():
		queue_free()
		return

	var next_bubbles: Array[BubbleParticle] = []
	for bubble in _bubbles:
		bubble.age += delta
		if bubble.age >= bubble.lifetime:
			continue

		bubble.velocity += Vector2(0.0, -48.0) * delta
		bubble.position += bubble.velocity * delta
		next_bubbles.append(bubble)

	_bubbles = next_bubbles
	queue_redraw()

	if _bubbles.is_empty():
		queue_free()


func _draw() -> void:
	for bubble in _bubbles:
		var progress := clampf(bubble.age / maxf(bubble.lifetime, 0.001), 0.0, 1.0)
		var alpha := 1.0 - progress
		var display_radius := bubble.radius * (1.0 + bubble.growth * progress)
		var wobble_offset := Vector2(
			sin(progress * 7.0 + bubble.wobble),
			cos(progress * 5.0 + bubble.wobble)
		) * 1.6
		var center := bubble.position + wobble_offset
		var ring_color := Color(0.78, 0.95, 1.0, 0.7 * alpha)
		var fill_color := Color(0.76, 0.94, 1.0, 0.13 * alpha)
		draw_circle(center, display_radius, fill_color)
		draw_arc(center, display_radius, 0.0, TAU, 18, ring_color, 1.5, true)
		draw_circle(
			center + Vector2(-display_radius * 0.28, -display_radius * 0.34),
			maxf(display_radius * 0.16, 0.6),
			Color(0.95, 1.0, 1.0, 0.75 * alpha)
		)
